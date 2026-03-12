//===-- AMDGPUCacheCapacityHazardRecognizer.h --------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines a hazard recognizer for modeling L1 data cache capacity
// pressure during instruction scheduling on AMDGPU processors.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_AMDGPU_AMDGPUCACHECAPACITYHAZARDRECOGNIZER_H
#define LLVM_LIB_TARGET_AMDGPU_AMDGPUCACHECAPACITYHAZARDRECOGNIZER_H

#include "llvm/CodeGen/ScheduleHazardRecognizer.h"
#include "llvm/TargetParser/TargetParser.h"

#include <utility>
#include <vector>

namespace llvm {
namespace AMDGPU {

class CacheCapacityHazardRecognizer : public ScheduleHazardRecognizer {
  AMDGPU::IsaVersion IsaVer;
  unsigned TotalBytes, UsedBytes;
  unsigned BytesPerCycleDividend;
  unsigned BytesPerCycleDivisor;
  unsigned Latency;
  unsigned CurrentCycle = 0;
  unsigned RemainBytesNumerator = 0;
  std::vector<unsigned> IssueHistory;
  std::vector<unsigned> IssueCycleHistory;
  unsigned IssueHead = 0;
  unsigned IssueTail = 0;

  unsigned historySize() const {
    return IssueHead >= IssueTail ? IssueHead - IssueTail
                                  : IssueHead + IssueHistory.size() - IssueTail;
  }

  bool canIssueBytes(unsigned Bytes, int Stalls) const {
    // Clamp to TotalBytes to match issueBytes(), which also clamps.
    // Without this, an instruction whose footprint exceeds the cache
    // would report a hazard that can never be resolved.
    if (Bytes > TotalBytes)
      Bytes = TotalBytes;
    // Stalls is negative when the scheduler is probing future cycles.
    // Clamp to zero to avoid unsigned underflow in the arithmetic.
    // Multiply through by Divisor to avoid truncation:
    //   UsedBytes + Bytes <= TotalBytes + Stalls * Dividend / Divisor
    // becomes:
    //   (UsedBytes + Bytes) * Divisor <= TotalBytes * Divisor + Stalls * Dividend
    unsigned Extra =
        Stalls > 0 ? static_cast<unsigned>(Stalls) * BytesPerCycleDividend : 0;
    return (UsedBytes + Bytes) * BytesPerCycleDivisor <=
           TotalBytes * BytesPerCycleDivisor + Extra;
  }

  void issueBytes(unsigned Bytes);

  std::pair<unsigned, unsigned> countWaitBytes(unsigned InstrCount) const;

  bool waitLessThanInstrNoBubble(unsigned InstrCount, int Stalls) const;

  void waitLessThanInstr(unsigned InstrCount);

  HazardType getHazardType(MachineInstr *MI, int Stalls);

public:
  CacheCapacityHazardRecognizer(unsigned EffBytes,
                                unsigned BytesPerCycleDividend,
                                unsigned BytesPerCycleDivisor, unsigned Latency,
                                AMDGPU::IsaVersion IsaVer);

  void Reset() override;

  void EmitInstruction(SUnit *) override;

  void EmitInstruction(MachineInstr *) override;

  HazardType getHazardType(SUnit *SU, int Stalls) override;

  void AdvanceCycle() override;

  void RecedeCycle() override;
};

} // namespace AMDGPU
} // namespace llvm

#endif // LLVM_LIB_TARGET_AMDGPU_AMDGPUCACHECAPACITYHAZARDRECOGNIZER_H
