// RUN: mlir-opt -split-input-file -verify-diagnostics %s

// Verify that test.with_bounds with mismatched attribute width (e.g., i64
// bounds for an i8 result) is rejected as invalid IR.
// See: https://github.com/llvm/llvm-project/issues/120882
func.func @with_bounds_mismatched_width() -> i8 {
  // expected-error@+1 {{'test.with_bounds' op umin bound attribute width (64) does not match result type width (8)}}
  %0 = test.with_bounds { umin = 10 : i64, umax = 15 : i64,
                           smin = 10 : i64, smax = 15 : i64 } : i8
  %1 = test.reflect_bounds %0 : i8
  return %1 : i8
}

// Verify that all bound attributes are checked, not just umin.
// See: https://github.com/llvm/llvm-project/issues/203855
func.func @with_bounds_mismatched_umax_width() -> i32 {
  // expected-error@+1 {{'test.with_bounds' op umax bound attribute width (8) does not match result type width (32)}}
  %0 = test.with_bounds { umin = 0 : i32, umax = 127 : ui8,
                           smin = 0 : i8, smax = 127 : i8 } : i32
  %1 = test.reflect_bounds %0 : i32
  return %1 : i32
}

func.func @with_bounds_mismatched_smin_width() -> i32 {
  // expected-error@+1 {{'test.with_bounds' op smin bound attribute width (8) does not match result type width (32)}}
  %0 = test.with_bounds { umin = 0 : i32, umax = 127 : ui32,
                           smin = 0 : i8, smax = 127 : i32 } : i32
  %1 = test.reflect_bounds %0 : i32
  return %1 : i32
}

func.func @with_bounds_mismatched_smax_width() -> i32 {
  // expected-error@+1 {{'test.with_bounds' op smax bound attribute width (8) does not match result type width (32)}}
  %0 = test.with_bounds { umin = 0 : i32, umax = 127 : ui32,
                           smin = 0 : i32, smax = 127 : i8 } : i32
  %1 = test.reflect_bounds %0 : i32
  return %1 : i32
}
