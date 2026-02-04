#ifndef LLVM_LIB_TARGET_AMDGPU_AMDGPUSWAITCNTLATENCY_H
#define LLVM_LIB_TARGET_AMDGPU_AMDGPUSWAITCNTLATENCY_H

#include "llvm/CodeGen/ScheduleDAGMutation.h"
#include <memory>

namespace llvm {

std::unique_ptr<ScheduleDAGMutation>
createAMDGPUSWaitCntLatencyDAGMutation();

} // namespace llvm

#endif // LLVM_LIB_TARGET_AMDGPU_AMDGPUSWAITCNTLATENCY_H
