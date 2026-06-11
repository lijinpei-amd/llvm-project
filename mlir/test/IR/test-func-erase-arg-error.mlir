// RUN: mlir-opt %s -test-func-erase-arg -split-input-file -verify-diagnostics

// Erasing an argument that still has uses must be diagnosed gracefully instead
// of crashing (see https://github.com/llvm/llvm-project/issues/203218).

// expected-error @below {{cannot erase argument #0 because it still has uses}}
func.func @f(%arg0: f32 {test.erase_this_arg}) -> f32 {
  return %arg0 : f32
}

// -----

// An external function has no body, so there are no argument uses to check and
// erasure must succeed without crashing.
func.func private @ext(f32 {test.erase_this_arg})
