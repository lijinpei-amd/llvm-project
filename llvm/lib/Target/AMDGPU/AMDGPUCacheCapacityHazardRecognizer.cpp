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
    unsigned EffBytes, unsigned BytesPerCycleDividend,
    unsigned BytesPerCycleDivisor, unsigned Latency, AMDGPU::IsaVersion IsaVer)
    : IsaVer(IsaVer), ScaledTotalBytes(0), ScaledUsedBytes(0),
      ScaledDrainPerCycle(BytesPerCycleDividend),
      BytesPerCycleDivisor(BytesPerCycleDivisor), Latency(Latency) {
  unsigned GCD = std::gcd(ScaledDrainPerCycle, BytesPerCycleDivisor);
  ScaledDrainPerCycle /= GCD;
  this->BytesPerCycleDivisor /= GCD;
  assert(ScaledDrainPerCycle > 0 && this->BytesPerCycleDivisor > 0 &&
         "BytesPerCycle dividend and divisor must be positive");
  // Scale TotalBytes by Divisor so all internal byte quantities are in
  // scaled units. Each cycle then drains exactly ScaledDrainPerCycle
  // scaled-units, avoiding fractional accumulation.
  ScaledTotalBytes = EffBytes * this->BytesPerCycleDivisor;
  // MaxCycles = Latency + ceil(EffBytes / (Dividend/Divisor))
  //           = Latency + ceil(ScaledTotalBytes / ScaledDrainPerCycle)
  unsigned MaxCycles =
      Latency +
      (ScaledTotalBytes + ScaledDrainPerCycle - 1) / ScaledDrainPerCycle;
  IssueHistory.resize(MaxCycles + 1);
  MaxLookAhead = MaxCycles;
}

std::pair<unsigned, unsigned>
CacheCapacityHazardRecognizer::countWaitBytes(unsigned InstrCount) const {
  if (InstrCount >= historySize()) {
    return {IssueTail, 0};
  }
  unsigned NewTail =
      IssueHead >= InstrCount
          ? IssueHead - InstrCount
          : IssueHead + IssueHistory.size() - InstrCount;
  auto AccumBytes = [](unsigned Acc, const IssueEntry &E) {
    return Acc + E.ScaledBytes;
  };
  auto BeginIter = IssueHistory.begin(), EndIter = IssueHistory.end();
  auto TailIter = std::next(BeginIter, IssueTail),
       NewTailIter = std::next(BeginIter, NewTail);
  unsigned ScaledWaitBytes =
      NewTail > IssueTail
          ? std::accumulate(TailIter, NewTailIter, 0u, AccumBytes)
          : std::accumulate(TailIter, EndIter, 0u, AccumBytes) +
                std::accumulate(BeginIter, NewTailIter, 0u, AccumBytes);
  return {NewTail, ScaledWaitBytes};
}

bool CacheCapacityHazardRecognizer::waitLessThanInstrNoBubble(
    unsigned InstrCount, int Stalls) const {
  auto [_, ScaledWaitBytes] = countWaitBytes(InstrCount);
  // ScaledWaitBytes is in scaled units; each stall cycle drains
  // ScaledDrainPerCycle scaled-units.
  return ScaledWaitBytes <=
         static_cast<unsigned>(Stalls) * ScaledDrainPerCycle;
}

ScheduleHazardRecognizer::HazardType
CacheCapacityHazardRecognizer::getHazardType(MachineInstr *MI, int Stalls) {
  if (SIInstrInfo::isWaitcnt(MI->getOpcode())) {
    auto VMCNT = getInstrVMCNT(MI, IsaVer);
    return !VMCNT || waitLessThanInstrNoBubble(*VMCNT, Stalls) ? NoHazard
                                                               : NoopHazard;
  }
  unsigned CacheBytes = getEffectiveCacheBytes(MI);
  return canIssueBytes(CacheBytes, Stalls) ? NoHazard : NoopHazard;
}

ScheduleHazardRecognizer::HazardType
CacheCapacityHazardRecognizer::getHazardType(SUnit *SU, int Stalls) {
  return getHazardType(SU->getInstr(), Stalls);
}

void CacheCapacityHazardRecognizer::waitLessThanInstr(unsigned InstrCount) {
  auto [NewTail, ScaledWaitBytes] = countWaitBytes(InstrCount);
  IssueTail = NewTail;
  ScaledUsedBytes -= ScaledWaitBytes;
}

void CacheCapacityHazardRecognizer::Reset() {
  ScaledUsedBytes = 0;
  CurrentCycle = 0;
  IssueHead = IssueTail = 0;
}

void CacheCapacityHazardRecognizer::issueBytes(unsigned Bytes) {
  if (Bytes == 0) {
    return;
  }
  // Scale to internal units.
  unsigned ScaledBytes = Bytes * BytesPerCycleDivisor;
  if (ScaledBytes > ScaledTotalBytes)
    ScaledBytes = ScaledTotalBytes;
  while (ScaledUsedBytes + ScaledBytes > ScaledTotalBytes) {
    ScaledUsedBytes -= IssueHistory[IssueTail].ScaledBytes;
    ++IssueTail;
    if (IssueTail == IssueHistory.size())
      IssueTail = 0;
  }
  ScaledUsedBytes += ScaledBytes;
  IssueHistory[IssueHead] = {ScaledBytes, CurrentCycle};
  IssueHead += 1;
  if (IssueHead == IssueHistory.size())
    IssueHead = 0;
  assert(IssueHead != IssueTail && "Circular buffer overflow");
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

void CacheCapacityHazardRecognizer::AdvanceCycle() {
  ++CurrentCycle;
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
}

void CacheCapacityHazardRecognizer::RecedeCycle() {
  llvm_unreachable("Bottom-Up scheduling not implemented");
}

} // namespace AMDGPU
} // namespace llvm
