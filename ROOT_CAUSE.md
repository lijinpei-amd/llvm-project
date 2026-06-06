# Root Cause: InstCombine drops `smax(frexp_exp, -148)` for possible NaN/Inf frexp source

## Summary

`computeConstantRange` (llvm/lib/Analysis/ValueTracking.cpp) computes a
**bounded** `ConstantRange` for the integer exponent result of `llvm.frexp`,
derived purely from the floating-point type's exponent range. It does this
**unconditionally**, even when the frexp source value may be NaN or Inf. Per
LangRef the exponent is *unspecified* for NaN/Inf inputs, so no finite bound is
valid. InstCombine consumes the bogus range, concludes `exp >= -148` always
holds, and removes a clamp `smax(exp, -148)`. For a runtime NaN input the
exponent may be any value (Alive2 models it as fully nondeterministic, e.g.
`INT_MIN`), so the removed clamp is observable -> miscompile.

## Reproducer

`repro/min.ll`:

```llvm
define i32 @frexp_f32_clamp_min(float %x) {
  %frexp = call { float, i32 } @llvm.frexp.f32.i32(float %x)
  %exp = extractvalue { float, i32 } %frexp, 1
  %clamp = call i32 @llvm.smax.i32(i32 %exp, i32 -148)
  ret i32 %clamp
}
```

Command:

```
opt -passes=instcombine repro/min.ll -S
```

## Faulty logic

llvm/lib/Analysis/ValueTracking.cpp, `computeConstantRange`, frexp case
(~lines 10430-10452). The source FP class is queried with mask `fcSubnormal`
only (so nan/inf are not even requested), and a bounded range is then built
**without any guard on whether the source can be NaN/Inf**:

```cpp
KnownFPClass KnownSrc =
    computeKnownFPClass(FrexpSrc, fcSubnormal, SQ, Depth + 1);

// Exponent result is (src == 0) ? 0 : ilogb(src) + 1, and unspecified
// for inf/nan.
int MinExp = APFloat::semanticsMinExponent(FltSem) + 1;
if (!KnownSrc.isKnownNeverSubnormal())
  MinExp -= (APFloat::semanticsPrecision(FltSem) - 1);
int MaxExp = APFloat::semanticsMaxExponent(FltSem) + 1;
CR = ConstantRange::getNonEmpty(
    APInt(BitWidth, MinExp, /*isSigned=*/true),
    APInt(BitWidth, MaxExp + 1, /*isSigned=*/true));   // <-- always bounded
```

For `f32`: `MinExp = (-126 + 1) - (24 - 1) = -148`, `MaxExp + 1 = 129`, giving
the range `[-148, 129)`. The comment even acknowledges the exponent is
"unspecified for inf/nan", but the code never acts on it.

## Experimental evidence

Instrumentation added inside the frexp case (guarded by env var
`FREXP_RC_DEBUG`) prints the queried FP-class facts and the returned range.

Running on the *unfixed* tree (branch
`2026-06-06-alive2-instcombine-frexp-clamp-min-rootcause`):

```
$ FREXP_RC_DEBUG=1 opt -passes=instcombine repro/min.ll -S
```

Captured stderr (smoking gun):

```
[frexp-rootcause] computeConstantRange for frexp exponent
  FrexpSrc          = float %x
  query FPClass mask= fcSubnormal ONLY (nan/inf NOT queried)
  KnownSrc.isKnownNeverNaN()      = 0
  KnownSrc.isKnownNeverInfinity() = 0
  KnownSrc.isKnownNeverSubnormal()= 0
  --> returned BOUNDED ConstantRange = [-148,129)
      (lower=-148, upper=129) despite possible nan/inf source
```

Interpretation: `isKnownNeverNaN() == 0` and `isKnownNeverInfinity() == 0`
prove the source *may* be NaN/Inf, yet a finite range `[-148, 129)` is still
returned. Because the range's lower bound (`-148`) equals the clamp constant,
InstCombine proves `smax(exp, -148) == exp`.

Resulting transformed IR (stdout) — the clamp is gone:

```llvm
define i32 @frexp_f32_clamp_min(float %x) {
  %frexp = call { float, i32 } @llvm.frexp.f32.i32(float %x)
  %exp = extractvalue { float, i32 } %frexp, 1
  ret i32 %exp                ; smax(%exp, -148) removed
}
```

Contrast — `repro/nninf.ll` declares `float nofpclass(nan inf) %x`. There the
debug shows `isKnownNeverNaN() == 1` / `isKnownNeverInfinity() == 1`, and
dropping the clamp is legitimate (this is the only case where a bounded range
is sound).

## Why it is wrong

LangRef, `llvm.frexp.*` Semantics (llvm/docs/LangRef.rst:17901-17905):

> If the argument is a NaN, a NaN is returned and the returned exponent is
> unspecified. If the argument is an infinity, returns an infinity with the
> same sign and an unspecified exponent.

So for a NaN/Inf source the exponent is unconstrained; `[-148, 129)` is not a
valid bound and `exp >= -148` need not hold.

## Fix (one line of conditioning)

Only narrow the range when the source is known to be neither NaN nor Inf;
widen the query mask to `fcSubnormal | fcNan | fcInf` so those classes are
available, then guard the bounded-range construction with
`KnownSrc.isKnownNeverNaN() && KnownSrc.isKnownNeverInfinity()`.

Reference patch: branch `2026-06-06-alive2-instcombine-frexp-clamp-min`,
commit `13ef18602699` ("[ValueTracking] Don't bound frexp exponent range for
possible nan/inf").
