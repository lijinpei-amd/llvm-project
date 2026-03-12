#include "AMDGPUCacheCapacityHazardRecognizer.h"
#include "SIInstrInfo.h"

#include <algorithm>
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
    unsigned EffBytes, unsigned BytesPerCycle, AMDGPU::IsaVersion IsaVer)
    : IsaVer(IsaVer), TotalBytes(EffBytes), UsedBytes(0),
      BytesPerCycle(BytesPerCycle) {
  unsigned MaxCycles = (EffBytes + BytesPerCycle - 1) / BytesPerCycle;
  IssueHistory.resize(MaxCycles + 1);
  MaxLookAhead = MaxCycles;
}

std::pair<unsigned, unsigned>
CacheCapacityHazardRecognizer::countWaitBytes(unsigned InstrCount) const {
  if (InstrCount >= historySize()) {
    return {IssueTail, 0};
  }
  unsigned NewTail = IssueHead >= InstrCount
                         ? IssueHead - InstrCount
                         : IssueHead + IssueHistory.size() - InstrCount;
  auto BeginIter = IssueHistory.begin(), EndIter = IssueHistory.end();
  auto TailIter = std::next(BeginIter, IssueTail),
       NewTailIter = std::next(BeginIter, NewTail);
  unsigned WaitBytes = NewTail > IssueTail
                           ? std::accumulate(TailIter, NewTailIter, 0)
                           : std::accumulate(TailIter, EndIter, 0) +
                                 std::accumulate(BeginIter, NewTailIter, 0);
  return {NewTail, WaitBytes};
}

bool CacheCapacityHazardRecognizer::waitLessThanInstrNoBubble(
    unsigned InstrCount, int Stalls) const {
  auto [_, WaitBytes] = countWaitBytes(InstrCount);
  return WaitBytes <= Stalls * BytesPerCycle;
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
  auto [NewTail, WaitBytes] = countWaitBytes(InstrCount);
  IssueTail = NewTail;
  UsedBytes -= WaitBytes;
}

void CacheCapacityHazardRecognizer::Reset() {
  UsedBytes = 0;
  IssueHead = IssueTail = 0;
}

void CacheCapacityHazardRecognizer::issueBytes(unsigned Bytes) {
  if (Bytes == 0) {
    return;
  }
  if (Bytes > TotalBytes)
    Bytes = TotalBytes;
  while (UsedBytes + Bytes > TotalBytes) {
    UsedBytes -= IssueHistory[IssueTail];
    ++IssueTail;
    if (IssueTail == IssueHistory.size())
      IssueTail = 1;
  }
  UsedBytes += Bytes;
  IssueHistory[IssueHead] = Bytes;
  IssueHead += 1;
  if (IssueHead == IssueHistory.size())
    IssueHead = 0;
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
  unsigned RemainBytes = BytesPerCycle;
  while (IssueHead != IssueTail) {
    auto &InstrRemainBytes = IssueHistory[IssueTail];
    unsigned BytesFinished = std::min(RemainBytes, InstrRemainBytes);
    RemainBytes -= BytesFinished;
    UsedBytes -= BytesFinished;
    if (BytesFinished == InstrRemainBytes) {
      IssueTail += 1;
      if (IssueTail == IssueHistory.size())
        IssueTail = 0;
    } else {
      InstrRemainBytes -= BytesFinished;
      break;
    }
  }
}

void CacheCapacityHazardRecognizer::RecedeCycle() {
  // Bottom-Up not implemented
  assert(false);
}

} // namespace AMDGPU
} // namespace llvm
