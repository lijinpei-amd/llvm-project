//===-- AMDGPUPrepareAGPRAlloc.cpp ----------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Make simple transformations to relax register constraints for cases which can
// allocate to AGPRs or VGPRs. Replace materialize of inline immediates into
// AGPR or VGPR with a pseudo with an AV_* class register constraint. This
// allows later passes to inflate the register class if necessary. The register
// allocator does not know to replace instructions to relax constraints.
//
//===----------------------------------------------------------------------===//

#include "AMDGPUPrepareAGPRAlloc.h"
#include "AMDGPU.h"
#include "GCNSubtarget.h"
#include "SIMachineFunctionInfo.h"
#include "SIRegisterInfo.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "amdgpu-prepare-agpr-alloc"

// EXPERIMENT: use the tied (MAC) form for MFMAs without a dst/src2 overlap
// restriction, so vdst shares src2's register when src2 dies at the MFMA.
static cl::opt<bool>
    EnableSmallMFMAMac("amdgpu-mfma-small-mac", cl::Hidden,
                       cl::desc("Tie vdst to src2 of MFMAs with results of "
                                "at most 128 bits"),
                       cl::init(false));

namespace {

class AMDGPUPrepareAGPRAllocImpl {
private:
  const SIInstrInfo &TII;
  MachineRegisterInfo &MRI;

  bool isAV64Imm(const MachineOperand &MO) const;
  bool tieSmallMFMAs(MachineFunction &MF);

public:
  AMDGPUPrepareAGPRAllocImpl(const GCNSubtarget &ST, MachineRegisterInfo &MRI)
      : TII(*ST.getInstrInfo()), MRI(MRI) {}
  bool run(MachineFunction &MF);
};

class AMDGPUPrepareAGPRAllocLegacy : public MachineFunctionPass {
public:
  static char ID;

  AMDGPUPrepareAGPRAllocLegacy() : MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override;

  StringRef getPassName() const override { return "AMDGPU Prepare AGPR Alloc"; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesAll();
    MachineFunctionPass::getAnalysisUsage(AU);
  }
};
} // End anonymous namespace.

INITIALIZE_PASS(AMDGPUPrepareAGPRAllocLegacy, DEBUG_TYPE,
                "AMDGPU Prepare AGPR Alloc", false, false)

char AMDGPUPrepareAGPRAllocLegacy::ID = 0;

char &llvm::AMDGPUPrepareAGPRAllocLegacyID = AMDGPUPrepareAGPRAllocLegacy::ID;

bool AMDGPUPrepareAGPRAllocLegacy::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()))
    return false;

  const GCNSubtarget &ST = MF.getSubtarget<GCNSubtarget>();
  return AMDGPUPrepareAGPRAllocImpl(ST, MF.getRegInfo()).run(MF);
}

PreservedAnalyses
AMDGPUPrepareAGPRAllocPass::run(MachineFunction &MF,
                                MachineFunctionAnalysisManager &MFAM) {
  const GCNSubtarget &ST = MF.getSubtarget<GCNSubtarget>();
  AMDGPUPrepareAGPRAllocImpl(ST, MF.getRegInfo()).run(MF);
  return PreservedAnalyses::all();
}

bool AMDGPUPrepareAGPRAllocImpl::isAV64Imm(const MachineOperand &MO) const {
  return MO.isImm() && TII.isLegalAV64PseudoImm(MO.getImm());
}

// \returns true if \p Reg, directly or through up to \p Depth virtual
// register copies, is copied into a physical register.
static bool reachesPhysRegCopy(Register Reg, const MachineRegisterInfo &MRI,
                               unsigned Depth = 2) {
  for (const MachineInstr &UseMI : MRI.use_nodbg_instructions(Reg)) {
    if (!UseMI.isCopy())
      continue;
    Register DstReg = UseMI.getOperand(0).getReg();
    if (DstReg.isPhysical() ||
        (Depth && reachesPhysRegCopy(DstReg, MRI, Depth - 1)))
      return true;
  }
  return false;
}

// Switch untied MFMAs with a register src2 to the tied form. Two-address
// lowering converts them back when src2 is still live after the MFMA, as it
// already does for the MAC forms selected for larger results.
bool AMDGPUPrepareAGPRAllocImpl::tieSmallMFMAs(MachineFunction &MF) {
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      if (!SIInstrInfo::isMFMA(MI))
        continue;
      int MacOpc = AMDGPU::getMFMAMacOp(MI.getOpcode());
      if (MacOpc == -1)
        continue;
      int DstIdx =
          AMDGPU::getNamedOperandIdx(MI.getOpcode(), AMDGPU::OpName::vdst);
      int Src2Idx =
          AMDGPU::getNamedOperandIdx(MI.getOpcode(), AMDGPU::OpName::src2);
      const MachineOperand &Dst = MI.getOperand(DstIdx);
      const MachineOperand &Src2 = MI.getOperand(Src2Idx);
      // Wider results already select the MAC form unless src2 is an
      // immediate; their untied form is earlyclobber.
      if (Dst.isEarlyClobber() || !Src2.isReg() || !Src2.getReg().isVirtual() ||
          Src2.getSubReg() || Dst.getSubReg())
        continue;
      // If the result is copied to a physical register (e.g. a return
      // value), tying would force a copy that the untied form avoids.
      if (reachesPhysRegCopy(Dst.getReg(), MRI))
        continue;
      LLVM_DEBUG(dbgs() << "tie small MFMA: " << MI);
      MI.setDesc(TII.get(MacOpc));
      MI.tieOperands(DstIdx, Src2Idx);
      Changed = true;
    }
  }
  return Changed;
}

bool AMDGPUPrepareAGPRAllocImpl::run(MachineFunction &MF) {
  bool TiedMFMAs = EnableSmallMFMAMac && tieSmallMFMAs(MF);

  if (MRI.isReserved(AMDGPU::AGPR0))
    return TiedMFMAs;

  const MCInstrDesc &AVImmPseudo32 = TII.get(AMDGPU::AV_MOV_B32_IMM_PSEUDO);
  const MCInstrDesc &AVImmPseudo64 = TII.get(AMDGPU::AV_MOV_B64_IMM_PSEUDO);

  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      if ((MI.getOpcode() == AMDGPU::V_MOV_B32_e32 &&
           TII.isInlineConstant(MI, 1)) ||
          (MI.getOpcode() == AMDGPU::V_ACCVGPR_WRITE_B32_e64 &&
           MI.getOperand(1).isImm())) {
        MI.setDesc(AVImmPseudo32);
        Changed = true;
        continue;
      }

      // TODO: If only half of the value is rewritable, is it worth splitting it
      // up?
      if ((MI.getOpcode() == AMDGPU::V_MOV_B64_e64 ||
           MI.getOpcode() == AMDGPU::V_MOV_B64_PSEUDO) &&
          isAV64Imm(MI.getOperand(1))) {
        MI.setDesc(AVImmPseudo64);
        Changed = true;
        continue;
      }
    }
  }

  return Changed || TiedMFMAs;
}
