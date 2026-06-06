define float @f() #2 {
  %call = call float @llvm.canonicalize.f32(float -0.0)
  ret float %call
}
declare float @llvm.canonicalize.f32(float)
attributes #2 = { denormal_fpenv(positivezero|positivezero) }
