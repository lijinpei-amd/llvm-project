//===- llvm/Analysis/ScalarEvolutionNormalization.h - See below -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines utilities for working with "normalized" ScalarEvolution
// expressions.
//
// The following example illustrates post-increment uses and how normalized
// expressions help.
//
//   for (i=0; i!=n; ++i) {
//     ...
//   }
//   use(i);
//
// While the expression for most uses of i inside the loop is {0,+,1}<%L>, the
// expression for the use of i outside the loop is {1,+,1}<%L>, since i is
// incremented at the end of the loop body. This is inconveient, since it
// suggests that we need two different induction variables, one that starts
// at 0 and one that starts at 1. We'd prefer to be able to think of these as
// the same induction variable, with uses inside the loop using the
// "pre-incremented" value, and uses after the loop using the
// "post-incremented" value.
//
// Expressions for post-incremented uses are represented as an expression
// paired with a set of loops for which the expression is in "post-increment"
// mode (there may be multiple loops).
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_ANALYSIS_SCALAREVOLUTIONNORMALIZATION_H
#define LLVM_ANALYSIS_SCALAREVOLUTIONNORMALIZATION_H

#include "llvm/ADT/STLFunctionalExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Support/Compiler.h"

namespace llvm {

class Loop;
class ScalarEvolution;
class SCEV;
class SCEVAddRecExpr;
class Value;

typedef SmallPtrSet<const Loop *, 2> PostIncLoopSet;

typedef function_ref<bool(const SCEVAddRecExpr *)> NormalizePredTy;

/// Normalize \p S to be post-increment for all loops present in \p
/// Loops. Returns nullptr if the result is not invertible and \p
/// CheckInvertible is true.
LLVM_ABI const SCEV *normalizeForPostIncUse(const SCEV *S,
                                            const PostIncLoopSet &Loops,
                                            ScalarEvolution &SE,
                                            bool CheckInvertible = true);

/// Normalize \p S for all add recurrence sub-expressions for which \p
/// Pred returns true.
///
/// If \p NewStartPoison is non-null, it is populated with the maybe-poison
/// values that normalization newly exposes in the start (loop-invariant base)
/// of an add recurrence. Such values become a new poison dependency of the
/// loop-invariant remainder when the result is denormalized and expanded for a
/// post-increment user, even though normalization is structurally invertible.
/// Callers that have the original IR value can use this to detect and reject
/// rewrites that would introduce a new use of poison (see PR174200).
LLVM_ABI const SCEV *
normalizeForPostIncUseIf(const SCEV *S, NormalizePredTy Pred,
                         ScalarEvolution &SE,
                         SmallPtrSetImpl<const Value *> *NewStartPoison = nullptr);

/// Denormalize \p S to be post-increment for all loops present in \p
/// Loops.
LLVM_ABI const SCEV *denormalizeForPostIncUse(const SCEV *S,
                                              const PostIncLoopSet &Loops,
                                              ScalarEvolution &SE);
} // namespace llvm

#endif
