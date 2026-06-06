target datalayout = "e-p:64:64:64-p1:16:16:16-p2:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-ni:2"

@g_undef = constant { i128 } undef

define ptr @test_undef_aggregate() {
  store { i128 } undef, ptr @g_undef, align 8
  br label %bb
bb:
  ret ptr undef
}
