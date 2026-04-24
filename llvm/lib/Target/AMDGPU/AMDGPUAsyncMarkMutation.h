//===- AMDGPUAsyncMarkMutation.h - AMDGPU async-mark fence mutation -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_AMDGPU_AMDGPUASYNCMARKMUTATION_H
#define LLVM_LIB_TARGET_AMDGPU_AMDGPUASYNCMARKMUTATION_H

#include "llvm/CodeGen/ScheduleDAGMutation.h"
#include <memory>

namespace llvm {

/// Schedule DAG mutation that turns AMDGPU::ASYNCMARK into a release fence
/// and AMDGPU::WAIT_ASYNCMARK into an acquire fence with a single targeted
/// dependency on the (X+1)-th most recent prior ASYNCMARK (FIFO drain
/// semantics matching the wait immediate).
std::unique_ptr<ScheduleDAGMutation> createAsyncMarkMutation();

} // namespace llvm

#endif // LLVM_LIB_TARGET_AMDGPU_AMDGPUASYNCMARKMUTATION_H
