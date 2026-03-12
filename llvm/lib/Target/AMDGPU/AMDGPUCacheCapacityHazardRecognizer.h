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
  /// All byte quantities below are in "scaled" units (real bytes *
  /// BytesScaleFactor) so that the per-cycle drain rate is an integer.
  unsigned ScaledCapacityBytes, ScaledUsedBytes;
  unsigned ScaledDrainPerCycle;
  unsigned BytesScaleFactor;
  unsigned Latency;
  unsigned CurrentCycle = 0;
  struct IssueEntry {
    unsigned ScaledBytes;
    unsigned Cycle;
  };

  std::vector<IssueEntry> IssueHistory;
  /// Valid entries: [IssueTail, IssueHead), with wrap-around.
  unsigned IssueHead = 0;
  unsigned IssueTail = 0;

  unsigned historySize() const {
    return IssueHead >= IssueTail ? IssueHead - IssueTail
                                  : IssueHead + IssueHistory.size() - IssueTail;
  }

  void simulateAdvanceCycles(int Stalls, unsigned &RemBytesScaled,
                             unsigned &RemInstrs) const;

  bool canIssueBytes(unsigned Bytes, int Stalls) const;

  bool canWaitLessThanInstr(unsigned InstrCount, int Stalls) const;

  void issueBytes(unsigned Bytes);

  void waitLessThanInstr(unsigned InstrCount);

  HazardType getHazardType(MachineInstr *MI, int Stalls);

public:
  CacheCapacityHazardRecognizer(unsigned CapacityBytes,
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
