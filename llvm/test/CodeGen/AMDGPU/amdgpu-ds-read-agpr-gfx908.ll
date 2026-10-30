; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx908 -O2 -o - %s | FileCheck %s

; gfx908 has AGPRs, but its DS instructions cannot write them directly. Keep
; the load in a VGPR even when the opt-in attribute is present.

declare <4 x i32> @llvm.amdgcn.mfma.i32.4x4x4i8(i32, i32, <4 x i32>, i32 immarg, i32 immarg, i32 immarg)

define amdgpu_kernel void @lds_mfma(ptr addrspace(3) %p,
                                    ptr addrspace(1) %out) #0 {
; CHECK-LABEL: lds_mfma:
; CHECK: ds_read_b32 v{{[0-9]+}}, v{{[0-9]+}}
; CHECK-NOT: ds_read_b32 a
entry:
  %x = load i32, ptr addrspace(3) %p
  %r = call <4 x i32> @llvm.amdgcn.mfma.i32.4x4x4i8(i32 %x, i32 %x, <4 x i32> zeroinitializer, i32 0, i32 0, i32 0)
  store <4 x i32> %r, ptr addrspace(1) %out
  ret void
}

attributes #0 = { "amdgpu-ds-read-agpr" }
