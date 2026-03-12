#pragma once

#include "llvm/CodeGen/ScheduleHazardRecognizer.h"
#include "llvm/TargetParser/TargetParser.h"

#include <utility>
#include <vector>

namespace llvm {
namespace AMDGPU {

class CacheCapacityHazardRecognizer : public ScheduleHazardRecognizer {
  AMDGPU::IsaVersion IsaVer;
  unsigned TotalBytes, UsedBytes;
  unsigned BytesPerCycle;
  std::vector<unsigned> IssueHistory;
  unsigned IssueHead = 0;
  unsigned IssueTail = 0;

  unsigned historySize() const {
    return IssueHead >= IssueTail ? IssueHead - IssueTail
                                  : IssueHead + IssueHistory.size() - IssueTail;
  }

  bool canIssueBytes(unsigned Bytes, int Stalls) const {
    return UsedBytes + Bytes <= TotalBytes + Stalls * BytesPerCycle;
  }

  void issueBytes(unsigned Bytes);

  std::pair<unsigned, unsigned> countWaitBytes(unsigned InstrCount) const;

  bool waitLessThanInstrNoBubble(unsigned InstrCount, int Stalls) const;

  void waitLessThanInstr(unsigned InstrCount);

  HazardType getHazardType(MachineInstr *MI, int Stalls);

public:
  CacheCapacityHazardRecognizer(unsigned EffBytes, unsigned BytesPerCycle,
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
