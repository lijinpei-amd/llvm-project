//===-- AMDGPUCacheCapacityHazardRecognizer.cpp ----------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements a hazard recognizer for modeling L1 data cache capacity
// pressure during instruction scheduling on AMDGPU processors.
//
//===----------------------------------------------------------------------===//

#include "AMDGPUCacheCapacityHazardRecognizer.h"
#include "SIInstrInfo.h"

#include <algorithm>
#include <numeric>
#include <optional>

namespace llvm {
namespace AMDGPU {

namespace {
unsigned getEffectiveCacheBytes(MachineInstr *MI) {
  unsigned Res = 0;
  for (auto *MMO : MI->memoperands()) {
    auto AS = MMO->getAddrSpace();
    if (AS == AMDGPUAS::FLAT_ADDRESS || AS == AMDGPUAS::GLOBAL_ADDRESS ||
        AS == AMDGPUAS::BUFFER_RESOURCE) {
      auto MMOSize = MMO->getSize();
      if (MMOSize.hasValue() && MMOSize.isPrecise() && !MMOSize.isScalable())
        Res += (unsigned)MMOSize.getValue().getFixedValue();
    }
  }
  return Res;
}
std::optional<unsigned> getInstrVMCNT(MachineInstr *MI, AMDGPU::IsaVersion IV) {
  unsigned Opcode = SIInstrInfo::getNonSoftWaitcntOpcode(MI->getOpcode());
  if (Opcode == AMDGPU::S_WAITCNT) {
    unsigned IEnc = MI->getOperand(0).getImm();
    AMDGPU::Waitcnt Waitcnt = AMDGPU::decodeWaitcnt(IV, IEnc);
    return Waitcnt.get(InstCounterType::LOAD_CNT);
  }
  return std::nullopt;
}
} // namespace

CacheCapacityHazardRecognizer::CacheCapacityHazardRecognizer(
    unsigned CapacityBytes, unsigned BytesPerCycleDividend,
    unsigned BytesPerCycleDivisor, unsigned Latency, AMDGPU::IsaVersion IsaVer)
    : IsaVer(IsaVer), ScaledUsedBytes(0), Latency(Latency) {
  assert(BytesPerCycleDividend > 0 && BytesPerCycleDivisor > 0 &&
         "BytesPerCycle dividend and divisor must be positive");
  unsigned GCD = std::gcd(BytesPerCycleDividend, BytesPerCycleDivisor);
  ScaledDrainPerCycle = BytesPerCycleDividend / GCD;
  BytesScaleFactor = BytesPerCycleDivisor / GCD;
  ScaledCapacityBytes = CapacityBytes * BytesScaleFactor;
  unsigned MaxCycles =
      Latency +
      (ScaledCapacityBytes + ScaledDrainPerCycle - 1) / ScaledDrainPerCycle;
  IssueHistory.resize(MaxCycles + 1);
  MaxLookAhead = MaxCycles;
}

void CacheCapacityHazardRecognizer::Reset() {
  ScaledUsedBytes = 0;
  CurrentCycle = 0;
  IssueHead = IssueTail = 0;
}

void CacheCapacityHazardRecognizer::waitLessThanInstr(unsigned InstrCount) {
  while (historySize() > InstrCount) {
    AdvanceCycle();
  }
}

void CacheCapacityHazardRecognizer::issueBytes(unsigned Bytes) {
  if (Bytes == 0) {
    return;
  }
  unsigned ScaledBytes = Bytes * BytesScaleFactor;
  if (ScaledBytes > ScaledCapacityBytes)
    ScaledBytes = ScaledCapacityBytes;
  while (ScaledUsedBytes + ScaledBytes > ScaledCapacityBytes) {
    AdvanceCycle();
  }
  ScaledUsedBytes += ScaledBytes;
  IssueHistory[IssueHead] = {ScaledBytes, CurrentCycle};
  IssueHead += 1;
  if (IssueHead == IssueHistory.size())
    IssueHead = 0;
  assert(IssueHead != IssueTail && "Circular buffer overflow");
}

bool CacheCapacityHazardRecognizer::canWaitLessThanInstr(unsigned InstrCount,
                                                         int Stalls) const {
  unsigned RemBytesScaled, RemInstrs;
  simulateAdvanceCycles(Stalls, RemBytesScaled, RemInstrs);
  return RemInstrs <= InstrCount;
}

bool CacheCapacityHazardRecognizer::canIssueBytes(unsigned Bytes,
                                                  int Stalls) const {
  // Scale incoming bytes to match the internal scaled representation.
  unsigned ScaledBytes = Bytes * BytesScaleFactor;
  // Clamp to ScaledCapacityBytes. Without this, an instruction whose footprint
  // exceeds the cache would report a hazard that can never be resolved.
  if (ScaledBytes > ScaledCapacityBytes)
    ScaledBytes = ScaledCapacityBytes;
  unsigned RemBytesScaled, RemInstrs;
  simulateAdvanceCycles(Stalls, RemBytesScaled, RemInstrs);
  return RemBytesScaled + ScaledBytes <= ScaledCapacityBytes;
}

ScheduleHazardRecognizer::HazardType
CacheCapacityHazardRecognizer::getHazardType(MachineInstr *MI, int Stalls) {
  assert(Stalls >= 0 && "Only top-down is implemented");
  if (SIInstrInfo::isWaitcnt(MI->getOpcode())) {
    auto VMCNT = getInstrVMCNT(MI, IsaVer);
    return !VMCNT || canWaitLessThanInstr(*VMCNT, Stalls) ? NoHazard
                                                          : NoopHazard;
  }
  unsigned CacheBytes = getEffectiveCacheBytes(MI);
  return canIssueBytes(CacheBytes, Stalls) ? NoHazard : NoopHazard;
}

ScheduleHazardRecognizer::HazardType
CacheCapacityHazardRecognizer::getHazardType(SUnit *SU, int Stalls) {
  return getHazardType(SU->getInstr(), Stalls);
}

void CacheCapacityHazardRecognizer::EmitInstruction(SUnit *SU) {
  return EmitInstruction(SU->getInstr());
}

void CacheCapacityHazardRecognizer::EmitInstruction(MachineInstr *MI) {
  if (SIInstrInfo::isWaitcnt(MI->getOpcode())) {
    auto VMCNT = getInstrVMCNT(MI, IsaVer);
    if (VMCNT)
      waitLessThanInstr(*VMCNT);
    return;
  }
  return issueBytes(getEffectiveCacheBytes(MI));
}

void CacheCapacityHazardRecognizer::simulateAdvanceCycles(
    int Stalls, unsigned &RemBytesScaled, unsigned &RemInstrs) const {
  unsigned SimIssueHead = IssueHead, SimIssueTail = IssueTail;
  unsigned SimScaledUsedBytes = ScaledUsedBytes;
  if (SimIssueHead != SimIssueTail) {
    unsigned SimCurrentCycle = CurrentCycle;
    unsigned ScaledRemain = IssueHistory[SimIssueTail].ScaledBytes;
    while (Stalls > 0 && SimIssueHead != SimIssueTail) {
      unsigned ScaledBudget = ScaledDrainPerCycle;
      while (ScaledBudget && SimIssueTail != SimIssueHead) {
        if (SimCurrentCycle - IssueHistory[SimIssueTail].Cycle < Latency) {
          break;
        }
        unsigned ScaledFinished = std::min(ScaledBudget, ScaledRemain);
        ScaledBudget -= ScaledFinished;
        assert(SimScaledUsedBytes >= ScaledFinished &&
               "ScaledUsedBytes underflow");
        SimScaledUsedBytes -= ScaledFinished;
        if (ScaledFinished == ScaledRemain) {
          SimIssueTail += 1;
          if (SimIssueTail == IssueHistory.size())
            SimIssueTail = 0;
          ScaledRemain = SimIssueTail != SimIssueHead
                             ? IssueHistory[SimIssueTail].ScaledBytes
                             : 0;
        } else {
          ScaledRemain -= ScaledFinished;
          break;
        }
      }
      ++SimCurrentCycle;
      --Stalls;
    }
  }
  RemBytesScaled = SimScaledUsedBytes;
  RemInstrs = SimIssueHead >= SimIssueTail
                  ? SimIssueHead - SimIssueTail
                  : SimIssueHead + IssueHistory.size() - SimIssueTail;
}

void CacheCapacityHazardRecognizer::AdvanceCycle() {
  // Each cycle drains exactly ScaledDrainPerCycle scaled-units.
  // Unused drain capacity does not carry over to future cycles.
  unsigned ScaledBudget = ScaledDrainPerCycle;
  while (IssueHead != IssueTail) {
    // Only drain entries that have matured (age >= Latency).
    if (CurrentCycle - IssueHistory[IssueTail].Cycle < Latency)
      break;
    auto &ScaledRemain = IssueHistory[IssueTail].ScaledBytes;
    unsigned ScaledFinished = std::min(ScaledBudget, ScaledRemain);
    ScaledBudget -= ScaledFinished;
    assert(ScaledUsedBytes >= ScaledFinished && "ScaledUsedBytes underflow");
    ScaledUsedBytes -= ScaledFinished;
    if (ScaledFinished == ScaledRemain) {
      IssueTail += 1;
      if (IssueTail == IssueHistory.size())
        IssueTail = 0;
    } else {
      ScaledRemain -= ScaledFinished;
      break;
    }
  }
  ++CurrentCycle;
}

void CacheCapacityHazardRecognizer::RecedeCycle() {
  llvm_unreachable("Bottom-Up scheduling not implemented");
}

} // namespace AMDGPU
} // namespace llvm
