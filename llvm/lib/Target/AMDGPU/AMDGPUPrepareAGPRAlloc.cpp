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
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/CommandLine.h"
#include <utility>

using namespace llvm;

#define DEBUG_TYPE "amdgpu-prepare-agpr-alloc"

/// Force the destination of an LDS read or buffer load into an AGPR, when the
/// loaded value only feeds MFMA A or B sources. Normally these land in VGPRs
/// and the allocator never reconsiders. On gfx90a+ eligible load destinations
/// can use AGPRs directly, so only their virtual register classes have to be
/// narrowed.
///
/// The point is register-pressure relief: on a kernel whose accumulators
/// already fill the VGPR budget, moving load results to the AGPR half of the
/// unified file frees VGPRs. Shifting pressure and materializing propagation
/// values in AGPRs can also be a pessimisation, so this is opt-in.
///
/// Enable per function with the "amdgpu-ds-read-agpr" attribute, or globally
/// with this flag.
static cl::opt<bool> ForceDSReadAGPR(
    "amdgpu-ds-read-agpr", cl::Hidden, cl::init(false),
    cl::desc("Force MFMA-feeding LDS read and buffer load destinations into "
             "AGPRs everywhere"));

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

namespace {

class AMDGPUPrepareAGPRAllocImpl {
private:
  const SIInstrInfo &TII;
  MachineRegisterInfo &MRI;

  bool isAV64Imm(const MachineOperand &MO) const;
  bool isAGPRPropagation(const MachineInstr &MI) const;
  bool
  collectAGPRPropagationComponent(Register Root,
                                  SmallVectorImpl<Register> &Component,
                                  SmallDenseSet<Register, 32> &Members) const;
  bool onlyFeedsMFMASrcAB(ArrayRef<Register> Component) const;
  bool forceLoadResultsToAGPR(MachineFunction &MF);
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
    // The pass changes instructions and virtual-register classes, but never
    // changes the CFG.
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

/// Return true for target-independent instructions that only transport or
/// assemble register values. A load result commonly travels through several of
/// these before it reaches an MFMA, especially across a software-pipelined
/// loop. Every virtual register in such a connected component must be moved to
/// the same register file.
bool AMDGPUPrepareAGPRAllocImpl::isAGPRPropagation(
    const MachineInstr &MI) const {
  switch (MI.getOpcode()) {
  case TargetOpcode::COPY:
  case TargetOpcode::PHI:
  case TargetOpcode::REG_SEQUENCE:
  case TargetOpcode::INSERT_SUBREG:
  case TargetOpcode::EXTRACT_SUBREG:
  case TargetOpcode::SUBREG_TO_REG:
    return true;
  default:
    return false;
  }
}

/// Find the complete component connected to \p Root through register-only
/// propagation instructions. Return false for a component that crosses a
/// physical-register boundary; retargeting only the virtual side of such an
/// instruction would silently introduce a register-file transfer.
bool AMDGPUPrepareAGPRAllocImpl::collectAGPRPropagationComponent(
    Register Root, SmallVectorImpl<Register> &Component,
    SmallDenseSet<Register, 32> &Members) const {
  SmallVector<Register, 32> Worklist;
  Members.insert(Root);
  Worklist.push_back(Root);

  auto AddPropagationOperands = [&](const MachineInstr &MI) {
    for (const MachineOperand &MO : MI.operands()) {
      if (!MO.isReg() || MO.isImplicit() || !MO.getReg())
        continue;
      Register Reg = MO.getReg();
      if (!Reg.isVirtual())
        return false;
      if (Members.insert(Reg).second)
        Worklist.push_back(Reg);
    }
    return true;
  };

  while (!Worklist.empty()) {
    Register Reg = Worklist.pop_back_val();
    Component.push_back(Reg);

    for (const MachineInstr &DefMI : MRI.def_instructions(Reg)) {
      if (isAGPRPropagation(DefMI) && !AddPropagationOperands(DefMI))
        return false;
    }

    for (const MachineOperand &UseMO : MRI.use_nodbg_operands(Reg)) {
      const MachineInstr &UseMI = *UseMO.getParent();
      if (isAGPRPropagation(UseMI) && !AddPropagationOperands(UseMI))
        return false;
    }
  }

  return true;
}

/// True when every use leaving \p Component is the A or B source of an MFMA.
/// Uses by the propagation instructions are internal edges and are ignored.
bool AMDGPUPrepareAGPRAllocImpl::onlyFeedsMFMASrcAB(
    ArrayRef<Register> Component) const {
  bool HasMFMASrcABUse = false;

  for (Register Reg : Component) {
    for (const MachineOperand &MO : MRI.use_nodbg_operands(Reg)) {
      const MachineInstr *UseMI = MO.getParent();
      if (isAGPRPropagation(*UseMI))
        continue;
      if (!SIInstrInfo::isMFMA(*UseMI))
        return false;

      unsigned OpIdx = UseMI->getOperandNo(&MO);
      int Src0 =
          AMDGPU::getNamedOperandIdx(UseMI->getOpcode(), AMDGPU::OpName::src0);
      int Src1 =
          AMDGPU::getNamedOperandIdx(UseMI->getOpcode(), AMDGPU::OpName::src1);
      if (static_cast<int>(OpIdx) != Src0 && static_cast<int>(OpIdx) != Src1)
        return false;
      HasMFMASrcABUse = true;
    }
  }

  return HasMFMASrcABUse;
}

/// Retarget eligible LDS and MUBUF load results and their complete
/// register-only propagation components to AGPRs. A component is changed only
/// when every value can stay in AGPRs until it reaches an MFMA A/B operand.
bool AMDGPUPrepareAGPRAllocImpl::forceLoadResultsToAGPR(MachineFunction &MF) {
  const GCNSubtarget &ST = MF.getSubtarget<GCNSubtarget>();
  if (!ST.hasGFX90AInsts())
    return false;

  const SIRegisterInfo &TRI = *ST.getRegisterInfo();
  SmallDenseSet<Register, 64> Processed;
  bool Changed = false;

  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      MachineOperand *Dst = nullptr;
      if (SIInstrInfo::isDS(MI) && MI.mayLoad()) {
        Dst = TII.getNamedOperand(MI, AMDGPU::OpName::vdst);
      } else if (SIInstrInfo::isMUBUF(MI) && MI.mayLoad() && !MI.mayStore()) {
        // Exclude stores, atomics/RMWs, and MUBUF-to-LDS forms.
        Dst = TII.getNamedOperand(MI, AMDGPU::OpName::vdata);
      } else {
        continue;
      }

      if (!Dst || !Dst->isReg() || !Dst->isDef() ||
          !Dst->getReg().isVirtual() || Dst->getSubReg())
        continue;

      // A tied destination on a read-modify-write form would require moving
      // the input into the same component as well.
      if (MI.isRegTiedToUseOperand(MI.getOperandNo(Dst)))
        continue;

      Register Root = Dst->getReg();
      if (Processed.contains(Root))
        continue;

      SmallVector<Register, 32> Component;
      SmallDenseSet<Register, 32> Members;
      if (!collectAGPRPropagationComponent(Root, Component, Members)) {
        Processed.insert(Members.begin(), Members.end());
        continue;
      }
      Processed.insert(Members.begin(), Members.end());

      if (!onlyFeedsMFMASrcAB(Component))
        continue;

      SmallVector<std::pair<Register, const TargetRegisterClass *>, 32>
          NewClasses;
      bool CanRetarget = true;
      for (Register Reg : Component) {
        const TargetRegisterClass *RC = MRI.getRegClass(Reg);
        if (!TRI.hasVGPRs(RC) && !TRI.hasAGPRs(RC)) {
          CanRetarget = false;
          break;
        }

        const TargetRegisterClass *ARC =
            TRI.hasVGPRs(RC) ? TRI.getEquivalentAGPRClass(RC) : RC;
        if (!ARC || !TRI.hasAGPRs(ARC) || TRI.hasVGPRs(ARC)) {
          CanRetarget = false;
          break;
        }

        // Check the proposed class against every exact def/use operand. This
        // matters for pure-VGPR values and for MFMA variants whose src0 or src1
        // operand does not actually admit an AGPR.
        for (const MachineOperand &MO : MRI.reg_nodbg_operands(Reg)) {
          const MachineInstr &RegMI = *MO.getParent();
          ARC = RegMI.getRegClassConstraintEffectForVReg(Reg, ARC, &TII, &TRI);
          if (!ARC || !TRI.hasAGPRs(ARC) || TRI.hasVGPRs(ARC)) {
            CanRetarget = false;
            break;
          }

          if (!MO.isTied())
            continue;
          const MachineOperand &Other =
              RegMI.getOperand(RegMI.findTiedOperandIdx(MO.getOperandNo()));
          if (!Other.isReg() || !Other.getReg().isVirtual() ||
              !Members.contains(Other.getReg())) {
            CanRetarget = false;
            break;
          }
        }

        if (!CanRetarget)
          break;
        NewClasses.emplace_back(Reg, ARC);
      }

      if (!CanRetarget)
        continue;

      for (auto [Reg, RC] : NewClasses) {
        if (MRI.getRegClass(Reg) == RC)
          continue;
        MRI.setRegClass(Reg, RC);
        Changed = true;
      }
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

  const MCInstrDesc &AVImmPseudo32 = TII.get(AMDGPU::AV_MOV_B32_IMM_PSEUDO);
  const MCInstrDesc &AVImmPseudo64 = TII.get(AMDGPU::AV_MOV_B64_IMM_PSEUDO);

  bool Changed = ChangedTie;
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

  // Do this after creating the AV immediate pseudos above. They can be members
  // of a load propagation component, and the component should reach its final
  // register classes in one pass invocation.
  if (wantsAttr(MF.getFunction(), "amdgpu-ds-read-agpr", ForceDSReadAGPR))
    Changed |= forceLoadResultsToAGPR(MF);

  return Changed;
}
