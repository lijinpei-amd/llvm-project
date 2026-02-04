//===--- AMDGPUBarrierLatency.cpp - AMDGPU Barrier Latency ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
/// \file This file contains a DAG scheduling mutation to add latency to
///       barrier edges between ATOMIC_FENCE instructions and preceding
///       memory accesses potentially affected by the fence.
///       This encourages the scheduling of more instructions before
///       ATOMIC_FENCE instructions.  ATOMIC_FENCE instructions may
///       introduce wait counting or indicate an impending S_BARRIER
///       wait.  Having more instructions in-flight across these
///       constructs improves latency hiding.
//
//===----------------------------------------------------------------------===//

#include "AMDGPUSWaitCntLatency.h"
#include "MCTargetDesc/AMDGPUMCTargetDesc.h"
#include "SIInstrInfo.h"
#include "llvm/CodeGen/ScheduleDAGInstrs.h"

using namespace llvm;

namespace {

class SWaitCntLatency : public ScheduleDAGMutation {

public:
  SWaitCntLatency() {}
  void apply(ScheduleDAGInstrs *DAG) override;
};

void SWaitCntLatency::apply(ScheduleDAGInstrs *DAG) {
  constexpr unsigned SyntheticLatency = 16;
  for (SUnit &SU : DAG->SUnits) {
    const MachineInstr *MI = SU.getInstr();
    if (!SIInstrInfo::isWaitcnt(MI->getOpcode())) {
      continue;
    }
    SDep EntryDep(&DAG->EntrySU, SDep::Barrier);
    EntryDep.setLatency(SyntheticLatency);
    SU.addPred(EntryDep);
    for (SDep &PredDep : SU.Preds) {
      if (!PredDep.isBarrier())
        continue;
      SUnit *PredSU = PredDep.getSUnit();
      if (PredSU == &DAG->EntrySU) {
        continue;
      }
      MachineInstr *MI = PredSU->getInstr();
      SDep NewDep(PredDep);
      NewDep.setLatency(SyntheticLatency);
      SU.addPred(NewDep);
    }
  }
}

} // end namespace

std::unique_ptr<ScheduleDAGMutation>
llvm::createAMDGPUSWaitCntLatencyDAGMutation() {
  return std::make_unique<SWaitCntLatency>();
}

