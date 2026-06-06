# Root Cause: InstCombine `fabs(X)*fabs(X) -> X*X` undef unsoundness

## Summary

InstCombine miscompiles `fabs(X) * fabs(X)` into `X * X` (and the `fdiv`
variant `fabs(X)/fabs(X) -> X/X`). The fold takes a value `X` that is used
**once** (only under `fabs`) and rewrites it to a value used **twice**, with no
`freeze`. When `X` is `undef`, each of the two uses may independently
materialize a different concrete value. The target `X * X` can therefore
produce `-0.0` (e.g. `+0.0 * -0.0`), while the source always squares a single
sign-cleared value (`fabs` makes the operand non-negative and identical on both
sides of the multiply), so the source can never yield `-0.0`. The result is a
value mismatch under `undef`.

The transform is correct for every non-`undef` input.

## Repro

`repro_fabs.ll`:

```llvm
declare float @llvm.fabs.f32(float)

define float @fabs_squared(float %x) {
  %a = call float @llvm.fabs.f32(float %x)
  %r = fmul float %a, %a
  ret float %r
}
```

Command:

```
opt -passes=instcombine repro_fabs.ll -S
```

## Faulty logic

`llvm/lib/Transforms/InstCombine/InstCombineMulDivRem.cpp`,
`InstCombinerImpl::foldFPSignBitOps`, ~line 619 (origin/main):

```cpp
// fabs(X) * fabs(X) -> X * X
// fabs(X) / fabs(X) -> X / X
if (Op0 == Op1 && match(Op0, m_FAbs(m_Value(X))))
  return BinaryOperator::CreateWithCopiedFlags(Opcode, X, X, &I);
```

`X` is matched from a single `fabs(X)` (one use of `X`). The result reuses `X`
twice with no `freeze`. Nothing checks `isGuaranteedNotToBeUndef(X)`, unlike the
sibling `X*(2^k+1)` folds in the same file (which freeze a doubly-reused value).

## Experimental evidence

### 1. Instrumented fold fires; X is not known-non-undef; rewrite has no freeze

Instrumentation added at the fold site (this branch) prints the matched value,
`isGuaranteedNotToBeUndef(X)`, and confirms the no-freeze rewrite. Running
`opt -passes=instcombine repro_fabs.ll -S` produced (verbatim, on stderr):

```
[fabs-squared-rootcause] FIRING fold fabs(X)*/ fabs(X) -> X*/X on instr:   %r = fmul float %a, %a
[fabs-squared-rootcause]   matched X = float %x
[fabs-squared-rootcause]   isGuaranteedNotToBeUndef(X) = false
[fabs-squared-rootcause]   rewriting to (Opcode X, X) WITHOUT freeze: X now used twice
```

Resulting IR (the `fabs` is gone and `%x` is now consumed twice by one `fmul`):

```llvm
define float @fabs_squared(float %x) {
  %r = fmul float %x, %x
  ret float %r
}
```

This proves: (a) the fold fires on the repro, (b) `X` (`%x`) is **not**
guaranteed non-undef, and (c) the produced IR reuses `%x` twice with no freeze.

### 2. alive-tv: undef counterexample (the bug)

Source (`fabs_src_h.ll`) vs target (`fabs_tgt_h.ll`), `half` type for tractable
SMT:

```
alive-tv fabs_src_h.ll fabs_tgt_h.ll

Transformation doesn't verify!
ERROR: Value mismatch

Example:
half %x = undef

Source:
half %a = #x0000 (+0.0)
half %r = #x0000 (+0.0)

Target:
half %r = #x8000 (-0.0)
Source value: #x0000 (+0.0)
Target value: #x8000 (-0.0)
```

With `%x = undef`: the source picks one realization, `fabs` yields `+0.0`, and
`+0.0 * +0.0 = +0.0`. The target's two independent uses of `undef` realize
`+0.0` and `-0.0`, giving `+0.0 * -0.0 = -0.0`. `+0.0 != -0.0` bit-for-bit, so
the transform is unsound.

### 3. alive-tv control: correct for all non-undef inputs

```
alive-tv --disable-undef-input fabs_src_h.ll fabs_tgt_h.ll

Transformation seems to be correct!
  1 correct transformations
  0 incorrect transformations
```

(Same result holds for the `float` version with `--disable-undef-input`.) This
isolates `undef` as the sole cause: the only counterexample is the
per-use divergence of `undef`; non-`undef` inputs verify.

## Why it is wrong (concise)

`undef` is refined independently per use. Folding a once-used `X` into a
twice-used `X` lets the two uses take different concrete values, so `X*X` covers
results (e.g. `-0.0`) unreachable by `fabs(X)*fabs(X)`, which always squares one
identical, sign-cleared value.

## Fix (one line)

Freeze `X` before reusing it (skip when already non-undef), matching the
neighboring folds:

```cpp
if (Op0 == Op1 && match(Op0, m_FAbs(m_Value(X)))) {
  if (!isGuaranteedNotToBeUndef(X))
    X = Builder.CreateFreeze(X, X->getName() + ".fr");
  return BinaryOperator::CreateWithCopiedFlags(Opcode, X, X, &I);
}
```

Reference patch: branch `2026-06-06-alive2-instcombine-fabs-squared-signzero`,
commit `981350ba9be2` ("[InstCombine] Freeze X in fabs(X)*fabs(X) -> X*X to fix
undef unsoundness").
