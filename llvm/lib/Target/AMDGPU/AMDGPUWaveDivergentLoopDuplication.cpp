//===- AMDGPUWaveDivergentLoopDuplication.cpp --------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass duplicates loops so that odd and even waves execute different copies
// of the same loop. Both copies share the same virtual registers, so they
// produce identical register allocation results. The intent is to reduce
// resource contention (e.g. cache bank conflicts) between neighboring waves.
//
// The transformation turns:
//
//   preheader -> header -> ... -> latch -> exit
//
// into:
//
//   preheader -> dispatch_block
//     dispatch_block: s_getreg(HW_ID) & 1 => branch even/odd
//       even: header -> ... -> latch -> exit
//       odd:  header' -> ... -> latch' -> exit
//
// Both the even and odd loop bodies use the same virtual register operands.
// Since exactly one path executes at runtime, there is no conflict at the
// register allocator level.
//
// --------------------------------------------------------------------------
// NOTE ON WAVE IDENTITY SOURCE (HW_ID)
// --------------------------------------------------------------------------
// Wave parity is determined by reading bit 0 of the wave_id field from the
// HW_ID hardware register via S_GETREG_B32:
//
//   - Pre-GFX10: HW_ID  (hwreg 4), wave_id at bits [3:0]
//   - GFX10+:    HW_ID1 (hwreg 23), wave_id at bits [3:0]
//
// The HW_ID register reflects the physical wave slot assigned by the SPI at
// wave launch. This value is read once in the dispatch block and the result
// is used to branch; it is never re-read.
//
// IMPORTANT: HW_ID is NOT architecturally guaranteed to be stable across the
// entire lifetime of a wave on all implementations. Future hardware or different
// execution scenarios (e.g. wave preemption, migration, context switching) may
// cause the physical wave slot assignment to change. The official
// amdgcn_wave_id intrinsic does NOT use HW_ID -- it reads TTMP8[29:25] on
// targets with architected SGPRs (GFX12+), which IS guaranteed stable.
//
// We use HW_ID here because:
//   1. TTMP8-based wave_id_in_group requires FeatureArchitectedSGPRs, which
//      is only available on GFX12+. The primary targets for this pass (e.g.
//      GFX94x / MI300-series) do not have this feature.
//   2. On current GFX9/GFX94x hardware, the physical wave slot IS stable for
//      the wave's lifetime -- a wave occupies its SIMD slot until completion.
//   3. The value is read once and cached in a virtual register; there is no
//      repeated polling of HW_ID.
//
// If a future target provides a better stable per-wave identifier that does
// not require FeatureArchitectedSGPRs, this pass should be updated to use it.
// --------------------------------------------------------------------------
//
// This pass runs after PHI elimination and register coalescing, but before
// the pre-RA machine scheduler.
//
//===----------------------------------------------------------------------===//

#include "AMDGPU.h"
#include "GCNSubtarget.h"
#include "SIDefines.h"
#include "SIInstrInfo.h"
#include "SIRegisterInfo.h"
#include "Utils/AMDGPUBaseInfo.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "amdgpu-wave-divergent-loop-dup"

static cl::opt<bool> EnableWaveDivergentLoopDup(
    "amdgpu-wave-divergent-loop-dup", cl::init(false), cl::Hidden,
    cl::desc("Enable wave-divergent loop duplication"));

namespace {

class AMDGPUWaveDivergentLoopDup {
public:
  bool run(MachineFunction &MF, MachineLoopInfo &MLI);

private:
  const GCNSubtarget *ST = nullptr;
  const SIInstrInfo *TII = nullptr;
  const SIRegisterInfo *TRI = nullptr;
  MachineRegisterInfo *MRI = nullptr;
  MachineFunction *MF = nullptr;

  bool processLoop(MachineLoop *L);

  MachineBasicBlock *cloneBlock(MachineBasicBlock *OrigMBB);

  void rewireBranches(
      MachineBasicBlock *MBB,
      const DenseMap<MachineBasicBlock *, MachineBasicBlock *> &BlockMap);

  void buildDispatchBlock(MachineBasicBlock *DispatchMBB,
                          MachineBasicBlock *EvenHeader,
                          MachineBasicBlock *OddHeader, const DebugLoc &DL);
};

class AMDGPUWaveDivergentLoopDuplicationLegacy : public MachineFunctionPass {
public:
  static char ID;
  AMDGPUWaveDivergentLoopDuplicationLegacy() : MachineFunctionPass(ID) {
    initializeAMDGPUWaveDivergentLoopDuplicationLegacyPass(
        *PassRegistry::getPassRegistry());
  }

  StringRef getPassName() const override {
    return "AMDGPU Wave Divergent Loop Duplication";
  }

  bool runOnMachineFunction(MachineFunction &MF) override {
    if (skipFunction(MF.getFunction()))
      return false;
    if (!EnableWaveDivergentLoopDup)
      return false;

    MachineLoopInfo &MLI =
        getAnalysis<MachineLoopInfoWrapperPass>().getLI();
    return AMDGPUWaveDivergentLoopDup().run(MF, MLI);
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineLoopInfoWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }
};

} // end anonymous namespace

INITIALIZE_PASS_BEGIN(AMDGPUWaveDivergentLoopDuplicationLegacy, DEBUG_TYPE,
                      "AMDGPU Wave Divergent Loop Duplication", false, false)
INITIALIZE_PASS_DEPENDENCY(MachineLoopInfoWrapperPass)
INITIALIZE_PASS_END(AMDGPUWaveDivergentLoopDuplicationLegacy, DEBUG_TYPE,
                    "AMDGPU Wave Divergent Loop Duplication", false, false)

char AMDGPUWaveDivergentLoopDuplicationLegacy::ID = 0;

char &llvm::AMDGPUWaveDivergentLoopDuplicationLegacyID =
    AMDGPUWaveDivergentLoopDuplicationLegacy::ID;

FunctionPass *llvm::createAMDGPUWaveDivergentLoopDuplicationPass() {
  return new AMDGPUWaveDivergentLoopDuplicationLegacy();
}

// ---------------------------------------------------------------------------
// Core implementation
// ---------------------------------------------------------------------------

bool AMDGPUWaveDivergentLoopDup::run(MachineFunction &MF_,
                                     MachineLoopInfo &MLI) {
  MF = &MF_;
  ST = &MF->getSubtarget<GCNSubtarget>();
  TII = ST->getInstrInfo();
  TRI = &TII->getRegisterInfo();
  MRI = &MF->getRegInfo();

  bool Changed = false;

  // Process outermost loops. Collect first to avoid iterator invalidation.
  SmallVector<MachineLoop *, 4> TopLoops(MLI.begin(), MLI.end());
  for (MachineLoop *L : TopLoops)
    Changed |= processLoop(L);

  return Changed;
}

bool AMDGPUWaveDivergentLoopDup::processLoop(MachineLoop *L) {
  MachineBasicBlock *Header = L->getHeader();
  MachineBasicBlock *Latch = L->getLoopLatch();
  MachineBasicBlock *ExitBlock = L->getExitBlock();
  MachineBasicBlock *Preheader = L->getLoopPreheader();

  if (!Header || !Latch || !ExitBlock || !Preheader) {
    LLVM_DEBUG(dbgs() << "Skipping loop: need single preheader, latch, "
                         "and exit block\n");
    return false;
  }

  LLVM_DEBUG(dbgs() << "Processing loop with header BB#"
                    << Header->getNumber() << "\n");

  // Collect all blocks in the loop.
  SmallVector<MachineBasicBlock *, 8> LoopBlocks(L->getBlocks());

  // Create a mapping from original blocks to cloned blocks.
  DenseMap<MachineBasicBlock *, MachineBasicBlock *> BlockMap;

  // Phase 1: Clone all loop blocks (instructions are cloned with the same
  // virtual register operands -- no vreg remapping).
  for (MachineBasicBlock *MBB : LoopBlocks) {
    MachineBasicBlock *ClonedMBB = cloneBlock(MBB);
    BlockMap[MBB] = ClonedMBB;
  }

  // Phase 2: Rewire branch targets inside cloned blocks so intra-loop edges
  // point to cloned blocks instead of originals.
  for (MachineBasicBlock *MBB : LoopBlocks) {
    MachineBasicBlock *ClonedMBB = BlockMap[MBB];
    rewireBranches(ClonedMBB, BlockMap);
  }

  // Phase 3: Set up successor edges for cloned blocks.
  for (MachineBasicBlock *MBB : LoopBlocks) {
    MachineBasicBlock *ClonedMBB = BlockMap[MBB];
    for (MachineBasicBlock *Succ : MBB->successors()) {
      auto It = BlockMap.find(Succ);
      if (It != BlockMap.end())
        ClonedMBB->addSuccessor(It->second);
      else
        ClonedMBB->addSuccessor(Succ);
    }
  }

  // Phase 4: Create the dispatch block that reads wave parity and branches.
  MachineBasicBlock *DispatchMBB = MF->CreateMachineBasicBlock();
  MF->insert(MachineFunction::iterator(Header), DispatchMBB);

  MachineBasicBlock *OddHeader = BlockMap[Header];

  DebugLoc DL;
  if (!Header->empty())
    DL = Header->front().getDebugLoc();

  buildDispatchBlock(DispatchMBB, Header, OddHeader, DL);

  // Phase 5: Rewire the preheader to branch to the dispatch block instead
  // of directly to the loop header.
  TII->removeBranch(*Preheader);
  TII->insertBranch(*Preheader, DispatchMBB, nullptr, {}, DL);
  Preheader->replaceSuccessor(Header, DispatchMBB);

  // Set dispatch block successors.
  DispatchMBB->addSuccessor(Header);    // even waves -> original loop
  DispatchMBB->addSuccessor(OddHeader); // odd waves  -> cloned loop

  LLVM_DEBUG(dbgs() << "Successfully duplicated loop with header BB#"
                    << Header->getNumber() << "\n"
                    << "  Dispatch: BB#" << DispatchMBB->getNumber() << "\n"
                    << "  Even header: BB#" << Header->getNumber() << "\n"
                    << "  Odd header:  BB#" << OddHeader->getNumber() << "\n");

  return true;
}

MachineBasicBlock *
AMDGPUWaveDivergentLoopDup::cloneBlock(MachineBasicBlock *OrigMBB) {
  MachineBasicBlock *NewMBB = MF->CreateMachineBasicBlock();
  MF->push_back(NewMBB);

  // Clone every instruction, keeping the same virtual register operands.
  // We intentionally do NOT remap virtual registers. Both loop copies
  // define/use the same vregs. Since the dispatch block guarantees mutual
  // exclusion (only one path executes per wave), this is safe.
  for (const MachineInstr &MI : *OrigMBB) {
    MachineInstr *ClonedMI = MF->CloneMachineInstr(&MI);
    NewMBB->push_back(ClonedMI);
  }

  return NewMBB;
}

void AMDGPUWaveDivergentLoopDup::rewireBranches(
    MachineBasicBlock *MBB,
    const DenseMap<MachineBasicBlock *, MachineBasicBlock *> &BlockMap) {
  for (MachineInstr &MI : *MBB) {
    for (MachineOperand &MO : MI.operands()) {
      if (!MO.isMBB())
        continue;
      auto It = BlockMap.find(MO.getMBB());
      if (It != BlockMap.end())
        MO.setMBB(It->second);
    }
  }
}

void AMDGPUWaveDivergentLoopDup::buildDispatchBlock(
    MachineBasicBlock *DispatchMBB, MachineBasicBlock *EvenHeader,
    MachineBasicBlock *OddHeader, const DebugLoc &DL) {
  // Read wave parity from HW_ID via S_GETREG_B32.
  //
  // WARNING: HW_ID is NOT architecturally guaranteed to remain stable across
  // the full lifetime of a wave. On current GFX9/GFX94x hardware, the physical
  // wave slot assignment does not change (a wave occupies its SIMD slot until
  // completion), so the value read here is effectively stable. However, future
  // hardware with wave preemption, migration, or context switching may
  // invalidate this assumption.
  //
  // The preferred source (TTMP8[29:25], used by the amdgcn_wave_id intrinsic)
  // requires FeatureArchitectedSGPRs, which is only available on GFX12+.
  // For GFX9/GFX94x targets, HW_ID is the only available wave-level
  // identifier. See the file-level comment block for full rationale.
  //
  // We read the value exactly once here and branch on it. The value is never
  // re-read during the loop execution.

  // Select the correct hardware register for the target generation:
  //   Pre-GFX10: HW_ID  (register 4), wave_id at bits [3:0]
  //   GFX10+:    HW_ID1 (register 23), wave_id at bits [3:0]
  // We extract only bit 0 (offset=0, width=1) for odd/even parity.
  unsigned HwRegId =
      ST->getGeneration() >= AMDGPUSubtarget::GFX10
          ? AMDGPU::Hwreg::ID_HW_ID1
          : AMDGPU::Hwreg::ID_HW_ID;
  unsigned EncodedHwreg =
      AMDGPU::Hwreg::HwregEncoding::encode(HwRegId, 0, 1);

  // %wave_parity:sreg_32 = S_GETREG_B32 hwreg(HW_ID, 0, 1)
  // Read bit 0 of wave_id: 0 = even wave, 1 = odd wave.
  Register WaveParityReg =
      MRI->createVirtualRegister(&AMDGPU::SReg_32RegClass);
  BuildMI(*DispatchMBB, DispatchMBB->end(), DL,
          TII->get(AMDGPU::S_GETREG_B32), WaveParityReg)
      .addImm(EncodedHwreg);

  // S_CMP_EQ_U32 %wave_parity, 0   ; sets SCC=1 if even wave
  BuildMI(*DispatchMBB, DispatchMBB->end(), DL,
          TII->get(AMDGPU::S_CMP_EQ_U32))
      .addReg(WaveParityReg)
      .addImm(0);

  // S_CBRANCH_SCC0 OddHeader   ; if SCC==0 (odd wave), branch to odd copy
  // fall-through to EvenHeader ; if SCC==1 (even wave), continue to even copy
  BuildMI(*DispatchMBB, DispatchMBB->end(), DL,
          TII->get(AMDGPU::S_CBRANCH_SCC0))
      .addMBB(OddHeader);
}
