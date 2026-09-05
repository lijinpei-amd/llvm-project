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
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "amdgpu-prepare-agpr-alloc"

/// Force the destination of an LDS read into an AGPR, when every consumer of that
/// value is an MFMA A or B source. Normally these land in
/// VGPRs and the allocator never reconsiders. On gfx90a+ the DS load vdst operand
/// is an AV_LdSt_* class, so an AGPR destination is directly encodable and no
/// pseudo is needed -- only the virtual register's class has to be narrowed.
///
/// The point is register-pressure relief: on a kernel whose accumulators already
/// fill the VGPR budget, moving LDS results to the AGPR half of the unified file
/// frees VGPRs. It is a pessimisation whenever the consumer cannot read an AGPR,
/// because then the inserted COPY survives as a v_accvgpr_read, so this is opt-in.
///
/// Enable per function with the "amdgpu-ds-read-agpr" attribute, or globally with
/// this flag.
static cl::opt<bool> ForceDSReadAGPR(
    "amdgpu-ds-read-agpr", cl::Hidden, cl::init(false),
    cl::desc("Force MFMA-feeding LDS read destinations into AGPRs everywhere"));

/// Tie each MFMA's D operand to its C operand, so the accumulate chain is forced
/// to update one register in place instead of leaving the allocator free to pick a
/// separate destination. Saves a full accumulator's worth of registers per chain
/// where it applies.
///
/// The tie is added before TwoAddressInstructionPass, which is what makes it safe:
/// where C is still live afterwards that pass inserts the copy for us, rather than
/// the value being silently clobbered.
///
/// Enable per function with "amdgpu-mfma-tied-cd", or globally with this flag.
static cl::opt<bool> ForceMFMATiedCD(
    "amdgpu-mfma-tied-cd", cl::Hidden, cl::init(false),
    cl::desc("Tie MFMA D to C for every function"));

/// Honours the flag, then the per-function attribute. Any value other than
/// "false"/"0" counts as enabled, so a bare attribute works.
static bool wantsAttr(const Function &F, StringRef Name, bool Flag) {
  if (Flag)
    return true;
  Attribute A = F.getFnAttribute(Name);
  if (!A.isValid())
    return false;
  if (!A.isStringAttribute())
    return true;
  StringRef V = A.getValueAsString();
  return V != "false" && V != "0";
}

/// Honours the flag, then the per-function attribute. Any value other than
/// "false"/"0" counts as enabled, so a bare attribute works.
static bool wantsDSReadAGPR(const Function &F) {
  if (ForceDSReadAGPR)
    return true;
  Attribute A = F.getFnAttribute("amdgpu-ds-read-agpr");
  if (!A.isValid())
    return false;
  if (!A.isStringAttribute())
    return true;
  StringRef V = A.getValueAsString();
  return V != "false" && V != "0";
}

namespace {

class AMDGPUPrepareAGPRAllocImpl {
private:
  const SIInstrInfo &TII;
  MachineRegisterInfo &MRI;

  bool isAV64Imm(const MachineOperand &MO) const;
  bool onlyFeedsMFMASrcAB(Register Reg) const;
  bool forceDSReadsToAGPR(MachineFunction &MF);
  bool tieMFMADstToSrc2(MachineFunction &MF);

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
    // Only setPreservesCFG, not setPreservesAll: the DS-read-to-AGPR transform
    // inserts COPY instructions, which invalidates live intervals. It never
    // changes the CFG. (Before that transform existed this pass only rewrote
    // opcodes in place and could preserve everything.)
    AU.setPreservesCFG();
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
  if (!AMDGPUPrepareAGPRAllocImpl(ST, MF.getRegInfo()).run(MF))
    return PreservedAnalyses::all();
  PreservedAnalyses PA;
  PA.preserveSet<CFGAnalyses>();
  return PA;
}

bool AMDGPUPrepareAGPRAllocImpl::isAV64Imm(const MachineOperand &MO) const {
  return MO.isImm() && TII.isLegalAV64PseudoImm(MO.getImm());
}

/// True when every use of \p Reg is the A or B source of an MFMA.
///
/// Those are the only consumers for which an AGPR destination is free: MFMA reads
/// its A/B operands from either file, so the value never has to cross back. A use
/// anywhere else -- a VALU, a copy, a REG_SEQUENCE, or the MFMA accumulator
/// operand -- would force a v_accvgpr_read, trading the register-pressure win for
/// extra instructions in the loop. Anything unrecognised is rejected.
bool AMDGPUPrepareAGPRAllocImpl::onlyFeedsMFMASrcAB(Register Reg) const {
  if (MRI.use_nodbg_empty(Reg))
    return false;

  for (const MachineOperand &MO : MRI.use_nodbg_operands(Reg)) {
    const MachineInstr *UseMI = MO.getParent();
    if (!SIInstrInfo::isMAI(*UseMI))
      return false;

    unsigned OpIdx = UseMI->getOperandNo(&MO);
    int Src0 =
        AMDGPU::getNamedOperandIdx(UseMI->getOpcode(), AMDGPU::OpName::src0);
    int Src1 =
        AMDGPU::getNamedOperandIdx(UseMI->getOpcode(), AMDGPU::OpName::src1);
    if (static_cast<int>(OpIdx) != Src0 && static_cast<int>(OpIdx) != Src1)
      return false;
  }

  return true;
}

/// Retarget each LDS read to a fresh AGPR and copy back to the original register.
/// Going through a COPY rather than just renaming the class keeps every consumer
/// legal: the coalescer folds the copy away wherever the use can take an AGPR
/// (an MFMA source, say), and leaves a v_accvgpr_read where it cannot.
bool AMDGPUPrepareAGPRAllocImpl::forceDSReadsToAGPR(MachineFunction &MF) {
  const SIRegisterInfo &TRI = *MF.getSubtarget<GCNSubtarget>().getRegisterInfo();
  bool Changed = false;

  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      if (!SIInstrInfo::isDS(MI) || !MI.mayLoad())
        continue;

      MachineOperand *Dst = TII.getNamedOperand(MI, AMDGPU::OpName::vdst);
      if (!Dst || !Dst->isReg() || !Dst->getReg().isVirtual() || Dst->getSubReg())
        continue;

      // A tied vdst_in (the read-modify-write DS forms) would need the input in
      // an AGPR too; not worth the extra copy, so leave those alone.
      if (MI.isRegTiedToUseOperand(MI.getOperandNo(Dst)))
        continue;

      Register Old = Dst->getReg();
      if (!onlyFeedsMFMASrcAB(Old))
        continue;

      const TargetRegisterClass *RC = MRI.getRegClass(Old);
      if (!TRI.hasVGPRs(RC))
        continue;
      const TargetRegisterClass *ARC = TRI.getEquivalentAGPRClass(RC);
      if (!ARC || ARC == RC)
        continue;

      // The common case: the DS vdst operand is an AV_LdSt_* class, so the
      // virtual register starts out as AV (either file) and every consumer has
      // already accepted that. Narrowing it to the AGPR subclass is then just a
      // constraint -- no copy, nothing for a later pass to fold back.
      if (TRI.hasAGPRs(RC)) {
        MRI.setRegClass(Old, ARC);
        Changed = true;
        continue;
      }

      // Pure VGPR destination: some consumer demanded a VGPR, so the value has
      // to come back across the file boundary explicitly.
      Register New = MRI.createVirtualRegister(ARC);
      Dst->setReg(New);
      BuildMI(MBB, std::next(MI.getIterator()), MI.getDebugLoc(),
              TII.get(AMDGPU::COPY), Old)
          .addReg(New);
      Changed = true;
    }
  }

  return Changed;
}

/// Add a "$vdst = $src2" tie to every MFMA that does not already have one.
bool AMDGPUPrepareAGPRAllocImpl::tieMFMADstToSrc2(MachineFunction &MF) {
  bool Changed = false;

  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      if (!SIInstrInfo::isMAI(MI))
        continue;

      int DstIdx =
          AMDGPU::getNamedOperandIdx(MI.getOpcode(), AMDGPU::OpName::vdst);
      int Src2Idx =
          AMDGPU::getNamedOperandIdx(MI.getOpcode(), AMDGPU::OpName::src2);
      if (DstIdx < 0 || Src2Idx < 0)
        continue;

      MachineOperand &Dst = MI.getOperand(DstIdx);
      MachineOperand &Src2 = MI.getOperand(Src2Idx);

      // src2 is an immediate for the first MFMA of a chain (the zero seed); there
      // is nothing to tie to, and the allocator is already free to reuse.
      if (!Dst.isReg() || !Src2.isReg())
        continue;
      if (!Dst.getReg().isVirtual() || !Src2.getReg().isVirtual())
        continue;
      if (Dst.getSubReg() || Src2.getSubReg())
        continue;

      // The wide-accumulator forms declare "@earlyclobber $vdst" precisely
      // because D must not overlap the sources; those already have a separate
      // _mac_e64 opcode when a tie is wanted.
      if (Dst.isEarlyClobber() || MI.isRegTiedToUseOperand(DstIdx))
        continue;

      if (MRI.getRegClass(Dst.getReg()) != MRI.getRegClass(Src2.getReg()))
        continue;

      MI.tieOperands(DstIdx, Src2Idx);
      Changed = true;
    }
  }

  return Changed;
}

bool AMDGPUPrepareAGPRAllocImpl::run(MachineFunction &MF) {
  if (ForceMFMATiedCD && !MF.getFunction().hasFnAttribute("amdgpu-mfma-tied-cd"))
    MF.getFunction().addFnAttr("amdgpu-mfma-tied-cd");

  // Deliberately ahead of the AGPR bail-out below: tying D to C needs no AGPRs,
  // so it still applies to functions compiled with amdgpu-agpr-alloc=0.
  bool ChangedTie =
      wantsAttr(MF.getFunction(), "amdgpu-mfma-tied-cd", ForceMFMATiedCD) &&
      tieMFMADstToSrc2(MF);

  if (MRI.isReserved(AMDGPU::AGPR0))
    return ChangedTie;

  // Record the command-line override as a real attribute. Everything downstream
  // (SIRegisterInfo::getLargestLegalSuperClass) then has a single thing to test.
  if (ForceDSReadAGPR && !MF.getFunction().hasFnAttribute("amdgpu-ds-read-agpr"))
    MF.getFunction().addFnAttr("amdgpu-ds-read-agpr");

  bool ChangedDS = wantsDSReadAGPR(MF.getFunction()) && forceDSReadsToAGPR(MF);

  const MCInstrDesc &AVImmPseudo32 = TII.get(AMDGPU::AV_MOV_B32_IMM_PSEUDO);
  const MCInstrDesc &AVImmPseudo64 = TII.get(AMDGPU::AV_MOV_B64_IMM_PSEUDO);

  bool Changed = ChangedDS || ChangedTie;
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

  return Changed;
}
