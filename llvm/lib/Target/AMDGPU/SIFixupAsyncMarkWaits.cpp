//===-- SIFixupAsyncMarkWaits.cpp - Fix WAIT_ASYNCMARK X immediates ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
/// \file
/// Recomputes the X immediate of WAIT_ASYNCMARK instructions based on the
/// final, post-scheduling program order.
///
/// AsyncMarkMutation records the WAIT_ASYNCMARK -> ASYNCMARK target pair in
/// SIMachineFunctionInfo at scheduling time. The scheduler may move marks
/// and waits relative to one another, so the (X+1)-th most recent prior mark
/// at scheduling time may no longer be at distance X in the final order.
/// This pass walks each MBB and rewrites the X immediate so the wait still
/// drains the originally targeted ASYNCMARK in FIFO order.
///
/// Runs before SIInsertWaitcnts which lowers the wait to s_waitcnt cycles.
//
//===----------------------------------------------------------------------===//

#include "AMDGPU.h"
#include "MCTargetDesc/AMDGPUMCTargetDesc.h"
#include "SIMachineFunctionInfo.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "si-fixup-async-mark-waits"

namespace {

class SIFixupAsyncMarkWaits : public MachineFunctionPass {
public:
  static char ID;

  SIFixupAsyncMarkWaits() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "AMDGPU Fixup async-mark waits";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override {
    if (skipFunction(MF.getFunction()))
      return false;

    const SIMachineFunctionInfo *MFI = MF.getInfo<SIMachineFunctionInfo>();
    bool Changed = false;

    for (MachineBasicBlock &MBB : MF) {
      SmallVector<const MachineInstr *, 16> Marks;
      for (MachineInstr &MI : MBB) {
        unsigned Op = MI.getOpcode();
        if (Op == AMDGPU::ASYNCMARK) {
          Marks.push_back(&MI);
          continue;
        }
        if (Op != AMDGPU::WAIT_ASYNCMARK)
          continue;

        const MachineInstr *Tgt = MFI->getAsyncWaitTarget(&MI);
        if (!Tgt) {
          // Wait was not retargeted by the mutation (e.g. region had no in-
          // region target, or scheduling never ran for this region). Leave
          // the immediate alone.
          continue;
        }

        auto It = llvm::find(Marks, Tgt);
        if (It == Marks.end()) {
          // Cross-MBB target: bail conservatively to "wait for all".
          if (MI.getOperand(0).getImm() != 0) {
            LLVM_DEBUG(dbgs() << "[fixup] WAIT_ASYNCMARK "
                              << MI.getOperand(0).getImm()
                              << " -> 0 (cross-MBB target)\n");
            MI.getOperand(0).setImm(0);
            Changed = true;
          }
          continue;
        }

        unsigned NewX = (Marks.size() - 1) - std::distance(Marks.begin(), It);
        if ((unsigned)MI.getOperand(0).getImm() != NewX) {
          LLVM_DEBUG(dbgs() << "[fixup] WAIT_ASYNCMARK "
                            << MI.getOperand(0).getImm() << " -> " << NewX
                            << '\n');
          MI.getOperand(0).setImm(NewX);
          Changed = true;
        }
      }
    }

    return Changed;
  }
};

} // end anonymous namespace

char SIFixupAsyncMarkWaits::ID = 0;

INITIALIZE_PASS(SIFixupAsyncMarkWaits, DEBUG_TYPE,
                "AMDGPU Fixup async-mark waits", false, false)

char &llvm::SIFixupAsyncMarkWaitsID = SIFixupAsyncMarkWaits::ID;

FunctionPass *llvm::createSIFixupAsyncMarkWaitsPass() {
  return new SIFixupAsyncMarkWaits();
}
