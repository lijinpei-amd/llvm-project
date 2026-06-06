define nofpclass(nan) float @f(float nofpclass(sub norm inf) %x) #2 {
  %canon = call float @llvm.canonicalize.f32(float %x)
  ret float %canon
}
declare float @llvm.canonicalize.f32(float)
attributes #2 = { denormal_fpenv(positivezero|positivezero) }
