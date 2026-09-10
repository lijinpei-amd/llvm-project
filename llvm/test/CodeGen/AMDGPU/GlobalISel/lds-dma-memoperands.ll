; RUN: llc -global-isel -mtriple=amdgpu9.00 -stop-after=instruction-select \
; RUN:   -o - %s | FileCheck %s

declare void @llvm.amdgcn.raw.ptr.buffer.load.lds(
    ptr addrspace(8), ptr addrspace(3), i32, i32, i32, i32, i32)
declare void @llvm.amdgcn.global.load.lds(
    ptr addrspace(1), ptr addrspace(3), i32, i32, i32)

define amdgpu_ps void @buffer_load_lds(
  ; CHECK-LABEL: name: buffer_load_lds
  ; CHECK: bb.1 (%ir-block.0):
  ; CHECK:   BUFFER_LOAD_DWORD_LDS_OFFSET {{.*}} :: (dereferenceable load (i32) from %ir.src, align 1, addrspace 8), (dereferenceable store (s2048) into %ir.dst + 16, align 1, addrspace 3)
    ptr addrspace(8) inreg %src, ptr addrspace(3) inreg %dst) {
  call void @llvm.amdgcn.raw.ptr.buffer.load.lds(
      ptr addrspace(8) %src, ptr addrspace(3) %dst,
      i32 4, i32 0, i32 0, i32 16, i32 0)
  ret void
}

define amdgpu_ps void @global_load_lds(
  ; CHECK-LABEL: name: global_load_lds
  ; CHECK: bb.1 (%ir-block.0):
  ; CHECK:   GLOBAL_LOAD_LDS_DWORD {{.*}} :: (load (i32) from %ir.src + 16, align 1, addrspace 1), (store (s2048) into %ir.dst + 16, align 1, addrspace 3)
    ptr addrspace(1) %src, ptr addrspace(3) inreg %dst) {
  call void @llvm.amdgcn.global.load.lds(
      ptr addrspace(1) %src, ptr addrspace(3) %dst,
      i32 4, i32 16, i32 0)
  ret void
}
