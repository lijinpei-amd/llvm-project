//===- AMDGPUAsyncVMemOrder.cpp - Keep VMEM loads behind async LDS DMA ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
/// \file Prototype DAG mutation: an ordinary global/buffer load may not be
/// scheduled above an LDS DMA that precedes it in program order.
///
/// Both kinds of instruction are counted by the in-order vmcnt counter, so a
/// wait for a DMA also waits for every load issued before it. Hoisting a load
/// above the DMAs of an async group makes the group's WAIT_ASYNCMARK drain it.
//
//===----------------------------------------------------------------------===//

#include "AMDGPUAsyncVMemOrder.h"
#include "SIInstrInfo.h"
#include "llvm/CodeGen/ScheduleDAGInstrs.h"
#include "llvm/Support/AMDGPUAddrSpace.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

static cl::opt<bool>
    EnableAsyncVMemOrder("amdgpu-async-vmem-order",
                         cl::desc("Keep VMEM loads behind preceding LDS DMA "
                                  "in the machine scheduler"),
                         cl::init(true), cl::Hidden);

namespace {

bool isOrdinaryVMemLoad(const MachineInstr &MI) {
  if (SIInstrInfo::isLDSDMA(MI) || !MI.mayLoad() || MI.mayStore())
    return false;
  if (!SIInstrInfo::isVMEM(MI) && !SIInstrInfo::isFLATGlobal(MI))
    return false;
  // Leave spill reloads and other private accesses alone.
  for (const MachineMemOperand *MMO : MI.memoperands())
    if (MMO->getAddrSpace() == AMDGPUAS::PRIVATE_ADDRESS)
      return false;
  return true;
}

class AsyncVMemOrder : public ScheduleDAGMutation {
public:
  void apply(ScheduleDAGInstrs *DAG) override {
    if (!EnableAsyncVMemOrder)
      return;
    SmallVector<SUnit *, 32> DMAs;
    for (SUnit &SU : DAG->SUnits) {
      const MachineInstr *MI = SU.getInstr();
      if (!MI)
        continue;
      if (SIInstrInfo::isLDSDMA(*MI)) {
        DMAs.push_back(&SU);
        continue;
      }
      if (!isOrdinaryVMemLoad(*MI))
        continue;
      for (SUnit *DMA : DMAs)
        DAG->addEdge(&SU, SDep(DMA, SDep::Artificial));
    }
  }
};

} // namespace

std::unique_ptr<ScheduleDAGMutation>
llvm::createAMDGPUAsyncVMemOrderDAGMutation() {
  return std::make_unique<AsyncVMemOrder>();
}
