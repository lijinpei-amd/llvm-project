; RUN: opt -S -passes=slp-vectorizer,dce \
; RUN:   -mtriple=amdgcn-amd-amdhsa -mcpu=gfx950 < %s | FileCheck %s

; A singleton i8 extract must not make it profitable to mix scale bytes with
; payload bytes. Keep the four payload bytes packed together for the MFMA.

; CHECK-LABEL: define amdgpu_kernel void @preserve_packed_i8_phi(
; CHECK: inner:
; CHECK-DAG: [[SCALE:%.*]] = phi <2 x i8> [ zeroinitializer, %entry ]
; CHECK-DAG: [[B:%.*]] = phi <4 x i8> [ zeroinitializer, %entry ]
; CHECK: then:
; CHECK: bitcast <2 x i8> [[SCALE]] to i16
; CHECK: merge:
; CHECK: [[B_MERGE:%.*]] = phi <4 x i8> [ [[B]], %then ], [ zeroinitializer, %inner ]
; CHECK: shufflevector <4 x i8> [[B_MERGE]], <4 x i8> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3,

target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @preserve_packed_i8_phi() {
entry:
  br label %inner

inner:
  %b0 = phi i8 [ 0, %entry ]
  %b1 = phi i8 [ 0, %entry ]
  %b2 = phi i8 [ 0, %entry ]
  %b3 = phi i8 [ 0, %entry ]
  %scale0 = phi i8 [ 0, %entry ]
  %scale1 = phi i8 [ 0, %entry ]
  br i1 false, label %then, label %merge

then:
  %scale.ins0 = insertelement <2 x i8> zeroinitializer, i8 %scale0, i64 0
  %scale.ins1 = insertelement <2 x i8> %scale.ins0, i8 %scale1, i64 1
  %scale.i16 = bitcast <2 x i8> %scale.ins1 to i16
  %scale.i32 = zext i16 %scale.i16 to i32
  %scale.acc = tail call <4 x float> @llvm.amdgcn.mfma.scale.f32.16x16x128.f8f6f4.v8i32.v8i32(<8 x i32> zeroinitializer, <8 x i32> zeroinitializer, <4 x float> zeroinitializer, i32 0, i32 0, i32 0, i32 %scale.i32, i32 0, i32 0)
  %scale.acc0 = extractelement <4 x float> %scale.acc, i64 0
  %scale0.next = extractelement <1 x i8> zeroinitializer, i64 0
  %scale1.next = extractelement <1 x i8> zeroinitializer, i64 0
  %b0.next = extractelement <16 x i8> zeroinitializer, i64 0
  br label %merge

merge:
  %b0.outer = phi i8 [ %b0.next, %then ], [ %b0, %inner ]
  %b1.outer = phi i8 [ 0, %then ], [ %b1, %inner ]
  %scale0.outer = phi i8 [ %scale0.next, %then ], [ %scale0, %inner ]
  %scale1.outer = phi i8 [ %scale1.next, %then ], [ %scale1, %inner ]
  %padding = phi float [ 0.0, %then ], [ 0.0, %inner ]
  %sum = phi float [ %scale.acc0, %then ], [ 0.0, %inner ]
  %b0.use = phi i8 [ %b0, %then ], [ 0, %inner ]
  %b1.use = phi i8 [ %b1, %then ], [ 0, %inner ]
  %b2.use = phi i8 [ %b2, %then ], [ 0, %inner ]
  %b3.use = phi i8 [ %b3, %then ], [ 0, %inner ]

  %b.ins0 = insertelement <32 x i8> zeroinitializer, i8 %b0.use, i64 0
  %b.ins1 = insertelement <32 x i8> %b.ins0, i8 %b1.use, i64 1
  %b.ins2 = insertelement <32 x i8> %b.ins1, i8 %b2.use, i64 2
  %b.ins3 = insertelement <32 x i8> %b.ins2, i8 %b3.use, i64 3
  %outer.b0.insert = insertelement <32 x i8> zeroinitializer, i8 %b0.outer, i64 0
  %outer.b1.insert = insertelement <32 x i8> zeroinitializer, i8 %b1.outer, i64 0
  %b.i32 = bitcast <32 x i8> %b.ins3 to <8 x i32>
  %sum.ins = insertelement <4 x float> zeroinitializer, float %sum, i64 0
  %result.v = tail call <4 x float> @llvm.amdgcn.mfma.scale.f32.16x16x128.f8f6f4.v8i32.v8i32(<8 x i32> %b.i32, <8 x i32> zeroinitializer, <4 x float> %sum.ins, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0)
  %result = extractelement <4 x float> %result.v, i64 0
  %result.ins = insertelement <2 x float> zeroinitializer, float %result, i64 0
  %result.trunc = fptrunc <2 x float> %result.ins to <2 x bfloat>
  %store.value = shufflevector <2 x bfloat> %result.trunc, <2 x bfloat> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  store <4 x bfloat> %store.value, ptr addrspace(3) null, align 8
  ret void
}

declare <4 x float> @llvm.amdgcn.mfma.scale.f32.16x16x128.f8f6f4.v8i32.v8i32(<8 x i32>, <8 x i32>, <4 x float>, i32 immarg, i32 immarg, i32 immarg, i32, i32 immarg, i32) #0

attributes #0 = { convergent nocallback nocreateundeforpoison nofree nosync nounwind willreturn memory(none) }
