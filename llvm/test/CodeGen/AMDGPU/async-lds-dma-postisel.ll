; RUN: llc -global-isel=0 -mtriple=amdgcn -mcpu=gfx900  -stop-after=finalize-isel      < %s | FileCheck %s
; RUN: llc -global-isel=1 -mtriple=amdgcn -mcpu=gfx900  -stop-after=instruction-select < %s | FileCheck %s
; RUN: llc -global-isel=0 -mtriple=amdgcn -mcpu=gfx942  -stop-after=finalize-isel      < %s | FileCheck %s
; RUN: llc -global-isel=1 -mtriple=amdgcn -mcpu=gfx942  -stop-after=instruction-select < %s | FileCheck %s
; RUN: llc -global-isel=0 -mtriple=amdgcn -mcpu=gfx950  -stop-after=finalize-isel      < %s | FileCheck %s
; RUN: llc -global-isel=1 -mtriple=amdgcn -mcpu=gfx950  -stop-after=instruction-select < %s | FileCheck %s
; RUN: llc -global-isel=0 -mtriple=amdgcn -mcpu=gfx1010 -stop-after=finalize-isel      < %s | FileCheck %s
; RUN: llc -global-isel=1 -mtriple=amdgcn -mcpu=gfx1010 -stop-after=instruction-select < %s | FileCheck %s

; Post-ISel verification for the gfx9 fake-async LDS-DMA refactor: each
; async LDS-DMA intrinsic selects to its *_ASYNC_* opcode with an implicit
; Use of $gfx9_asynccnt (the new dep-modeling mechanism that replaced the
; legacy $IsAsync immediate operand). The non-async sibling intrinsic does
; not pick the async opcode and does not carry the register.
;
; CHECKs use a single prefix and minimal anchors. The selected opcode and
; its implicit $gfx9_asynccnt operand are identical across all 4 subtargets
; (gfx900 / gfx942 / gfx950 / gfx1010) and both ISel modes (SDAG and GISel)
; even though the surrounding vreg numbering, register-class names, and
; helper-instruction structure diverge (which is what blocks
; update_mir_test_checks from producing a single shared autogen body).
;
; gfx1100+ (gfx11 / gfx12 / gfx1250) cannot select these intrinsics
; (they don't support the underlying VMemToLDSLoad path); they're omitted.

; CHECK-LABEL: name: raw_buffer_load_async
; CHECK: BUFFER_LOAD_DWORD_LDS_OFFSET_ASYNC{{.*}}implicit $gfx9_asynccnt
define amdgpu_ps void @raw_buffer_load_async(<4 x i32> inreg %rsrc, ptr addrspace(3) inreg %lds) {
  call void @llvm.amdgcn.raw.buffer.load.async.lds(<4 x i32> %rsrc, ptr addrspace(3) %lds, i32 4, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: raw_buffer_load_sync
; CHECK: BUFFER_LOAD_DWORD_LDS_OFFSET{{[^_]}}
; CHECK-NOT: $gfx9_asynccnt
define amdgpu_ps void @raw_buffer_load_sync(<4 x i32> inreg %rsrc, ptr addrspace(3) inreg %lds) {
  call void @llvm.amdgcn.raw.buffer.load.lds(<4 x i32> %rsrc, ptr addrspace(3) %lds, i32 4, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: raw_ptr_buffer_load_async
; CHECK: BUFFER_LOAD_DWORD_LDS_OFFSET_ASYNC{{.*}}implicit $gfx9_asynccnt
define amdgpu_ps void @raw_ptr_buffer_load_async(ptr addrspace(8) inreg %rsrc, ptr addrspace(3) inreg %lds) {
  call void @llvm.amdgcn.raw.ptr.buffer.load.async.lds(ptr addrspace(8) %rsrc, ptr addrspace(3) %lds, i32 4, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: raw_ptr_buffer_load_sync
; CHECK: BUFFER_LOAD_DWORD_LDS_OFFSET{{[^_]}}
; CHECK-NOT: $gfx9_asynccnt
define amdgpu_ps void @raw_ptr_buffer_load_sync(ptr addrspace(8) inreg %rsrc, ptr addrspace(3) inreg %lds) {
  call void @llvm.amdgcn.raw.ptr.buffer.load.lds(ptr addrspace(8) %rsrc, ptr addrspace(3) %lds, i32 4, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: struct_buffer_load_async
; CHECK: BUFFER_LOAD_DWORD_LDS_IDXEN_ASYNC{{.*}}implicit $gfx9_asynccnt
define amdgpu_ps void @struct_buffer_load_async(<4 x i32> inreg %rsrc, ptr addrspace(3) inreg %lds, i32 %vindex) {
  call void @llvm.amdgcn.struct.buffer.load.async.lds(<4 x i32> %rsrc, ptr addrspace(3) %lds, i32 4, i32 %vindex, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: struct_buffer_load_sync
; CHECK: BUFFER_LOAD_DWORD_LDS_IDXEN{{[^_]}}
; CHECK-NOT: $gfx9_asynccnt
define amdgpu_ps void @struct_buffer_load_sync(<4 x i32> inreg %rsrc, ptr addrspace(3) inreg %lds, i32 %vindex) {
  call void @llvm.amdgcn.struct.buffer.load.lds(<4 x i32> %rsrc, ptr addrspace(3) %lds, i32 4, i32 %vindex, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: struct_ptr_buffer_load_async
; CHECK: BUFFER_LOAD_DWORD_LDS_IDXEN_ASYNC{{.*}}implicit $gfx9_asynccnt
define amdgpu_ps void @struct_ptr_buffer_load_async(ptr addrspace(8) inreg %rsrc, ptr addrspace(3) inreg %lds, i32 %vindex) {
  call void @llvm.amdgcn.struct.ptr.buffer.load.async.lds(ptr addrspace(8) %rsrc, ptr addrspace(3) %lds, i32 4, i32 %vindex, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: struct_ptr_buffer_load_sync
; CHECK: BUFFER_LOAD_DWORD_LDS_IDXEN{{[^_]}}
; CHECK-NOT: $gfx9_asynccnt
define amdgpu_ps void @struct_ptr_buffer_load_sync(ptr addrspace(8) inreg %rsrc, ptr addrspace(3) inreg %lds, i32 %vindex) {
  call void @llvm.amdgcn.struct.ptr.buffer.load.lds(ptr addrspace(8) %rsrc, ptr addrspace(3) %lds, i32 4, i32 %vindex, i32 0, i32 0, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: global_load_async
; CHECK: GLOBAL_LOAD_LDS_DWORD_ASYNC{{.*}}implicit $gfx9_asynccnt
define amdgpu_ps void @global_load_async(ptr addrspace(1) %ptr, ptr addrspace(3) inreg %lds) {
  call void @llvm.amdgcn.global.load.async.lds(ptr addrspace(1) %ptr, ptr addrspace(3) %lds, i32 4, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: name: global_load_sync
; CHECK: GLOBAL_LOAD_LDS_DWORD{{[^_]}}
; CHECK-NOT: $gfx9_asynccnt
define amdgpu_ps void @global_load_sync(ptr addrspace(1) %ptr, ptr addrspace(3) inreg %lds) {
  call void @llvm.amdgcn.global.load.lds(ptr addrspace(1) %ptr, ptr addrspace(3) %lds, i32 4, i32 0, i32 0)
  ret void
}

; The generic int_amdgcn_load_to_lds / int_amdgcn_load_async_to_lds lower
; to the same GLOBAL_LOAD_LDS_DWORD / _ASYNC opcodes already exercised by
; @global_load_{sync,async} above; their wrapper-specific SDAG/GISel paths
; diverge enough in their post-isel surrounding ops to defeat a shared
; prefix here, so they are intentionally omitted (opcode identity is
; preserved by the global_load_{sync,async} cases).
