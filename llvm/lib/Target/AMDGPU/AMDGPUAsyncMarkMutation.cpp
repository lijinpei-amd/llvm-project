//===- AMDGPUAsyncMarkMutation.cpp - AMDGPU async-mark fence mutation -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
/// \file
/// Replaces the implicit "global memory object" barrier semantics of
/// ASYNCMARK / WAIT_ASYNCMARK with surgical release/acquire fence edges in
/// the schedule DAG.
///
///  - ASYNCMARK acts as a release fence: it depends on every memory access
///    that program-order-precedes it (so prior loads/stores cannot be sunk
///    past it). It does NOT block subsequent code.
///  - WAIT_ASYNCMARK X acts as an acquire fence with FIFO drain semantics:
///    it depends only on the (X+1)-th most recent prior ASYNCMARK in
///    program order, and every subsequent memory op depends on it.
///
/// The (X+1)-th-most-recent ASYNCMARK that the wait targeted is recorded in
/// SIMachineFunctionInfo via setAsyncWaitTarget so the post-scheduling
/// SIFixupAsyncMarkWaits pass can recompute the X immediate based on the
/// final, scheduled program order.
//
//===----------------------------------------------------------------------===//

#include "AMDGPUAsyncMarkMutation.h"
#include "MCTargetDesc/AMDGPUMCTargetDesc.h"
#include "SIInstrInfo.h"
#include "SIMachineFunctionInfo.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/ScheduleDAGInstrs.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "machine-scheduler"

namespace {

class AsyncMarkMutation : public ScheduleDAGMutation {
public:
  AsyncMarkMutation() = default;
  void apply(ScheduleDAGInstrs *DAG) override;
};

void AsyncMarkMutation::apply(ScheduleDAGInstrs *DAG) {
  if (DAG->SUnits.empty())
    return;

  MachineFunction &MF = DAG->MF;
  SIMachineFunctionInfo *MFI = MF.getInfo<SIMachineFunctionInfo>();

  // First pass: collect ASYNCMARK / WAIT_ASYNCMARK SUs in program (NodeNum)
  // order. ScheduleDAGInstrs constructs SUnits in source order, so NodeNum
  // matches program order at the time the mutation runs.
  SmallVector<SUnit *, 8> Marks;
  SmallVector<SUnit *, 8> Waits;
  bool HasAny = false;
  for (SUnit &SU : DAG->SUnits) {
    if (!SU.isInstr())
      continue;
    unsigned Op = SU.getInstr()->getOpcode();
    if (Op == AMDGPU::ASYNCMARK) {
      Marks.push_back(&SU);
      HasAny = true;
    } else if (Op == AMDGPU::WAIT_ASYNCMARK) {
      Waits.push_back(&SU);
      HasAny = true;
    }
  }

  if (!HasAny)
    return;

  LLVM_DEBUG(dbgs() << "AsyncMarkMutation: region has " << Marks.size()
                    << " ASYNCMARK and " << Waits.size()
                    << " WAIT_ASYNCMARK SUs\n");

  // Release fence on every ASYNCMARK: depend on every prior (NodeNum<) memory
  // op in the region.
  for (SUnit *M : Marks) {
    for (SUnit &P : DAG->SUnits) {
      if (P.NodeNum >= M->NodeNum)
        break;
      if (!P.isInstr())
        continue;
      const MachineInstr *PMI = P.getInstr();
      if (!(PMI->mayLoad() || PMI->mayStore()))
        continue;
      M->addPred(SDep(&P, SDep::Barrier));
    }
  }

  // Acquire fence on every WAIT_ASYNCMARK X:
  //   - Single targeted dep on the (X+1)-th most recent prior ASYNCMARK.
  //   - Every subsequent memory op depends on the wait.
  for (SUnit *W : Waits) {
    const MachineInstr *WMI = W->getInstr();
    unsigned N = WMI->getOperand(0).getImm();

    // Collect prior ASYNCMARKs in program order.
    SmallVector<SUnit *, 8> PriorMarks;
    for (SUnit *M : Marks) {
      if (M->NodeNum < W->NodeNum)
        PriorMarks.push_back(M);
      else
        break;
    }

    if (PriorMarks.size() > N) {
      SUnit *Target = PriorMarks[PriorMarks.size() - 1 - N];
      W->addPred(SDep(Target, SDep::Barrier));
      MFI->setAsyncWaitTarget(WMI, Target->getInstr());
      LLVM_DEBUG(dbgs() << "AsyncMarkMutation: WAIT_ASYNCMARK SU(" << W->NodeNum
                        << ") X=" << N << " -> ASYNCMARK SU(" << Target->NodeNum
                        << ")\n");
    } else {
      LLVM_DEBUG(dbgs() << "AsyncMarkMutation: WAIT_ASYNCMARK SU(" << W->NodeNum
                        << ") X=" << N
                        << " has no in-region target (cross-region drain)\n");
    }

    // Subsequent memory ops depend on the wait (acquire half).
    for (SUnit &Q : DAG->SUnits) {
      if (Q.NodeNum <= W->NodeNum)
        continue;
      if (!Q.isInstr())
        continue;
      const MachineInstr *QMI = Q.getInstr();
      if (!(QMI->mayLoad() || QMI->mayStore()))
        continue;
      Q.addPred(SDep(W, SDep::Barrier));
    }
  }
}

} // namespace

std::unique_ptr<ScheduleDAGMutation> llvm::createAsyncMarkMutation() {
  return std::make_unique<AsyncMarkMutation>();
}
