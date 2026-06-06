target datalayout = "e-p:64:64:64-i64:64:64-ni:2"

@g_undef = constant { i128 } undef

define ptr @test_undef_aggregate() {
  %v = load ptr, ptr @g_undef, align 8
  ret ptr %v
}
