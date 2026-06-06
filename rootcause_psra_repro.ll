target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
declare <8 x i16> @llvm.x86.sse2.psra.w(<8 x i16>, <8 x i16>)
define <8 x i16> @f(<8 x i16> %v, <8 x i16> %a) {
  %1 = and <8 x i16> %a, <i16 15, i16 0, i16 0, i16 0, i16 undef, i16 undef, i16 undef, i16 undef>
  %2 = tail call <8 x i16> @llvm.x86.sse2.psra.w(<8 x i16> %v, <8 x i16> %1)
  ret <8 x i16> %2
}
