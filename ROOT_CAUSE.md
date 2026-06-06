# Root Cause: `KnownFPClass::canonicalize` drops `-0.0` under positive-zero denormal mode

## 1. Summary

In a function whose denormal handling is **positive-zero** flushing
(`denormal_fpenv(positivezero)` / `"denormal-fp-math"="positive-zero,positive-zero"`),
`KnownFPClass::canonicalize` *unconditionally* removes `fcNegZero` from the
result's known fpclass mask. This makes value tracking conclude that
`@llvm.canonicalize(x)` can never be `-0.0`, even when the source operand `x`
may itself be `-0.0`. InstCombine then folds the call to `+0.0`.

This is a **miscompile**: positive-zero denormal mode flushes *subnormals* to
`+0.0`, but it does **not** flush a genuine `-0.0`. Per LangRef, `canonicalize`
must conserve the sign of zero: `@llvm.canonicalize(-0.0) = -0.0`.

## 2. Reproducer + command

`repro/src.ll`:

```llvm
define nofpclass(nan) float @f(float nofpclass(sub norm inf) %x) #2 {
  %canon = call float @llvm.canonicalize.f32(float %x)
  ret float %canon
}
declare float @llvm.canonicalize.f32(float)
attributes #2 = { denormal_fpenv(positivezero|positivezero) }
```

Here `%x` is `nofpclass(sub norm inf)` and the result is `nofpclass(nan)`, so the
only possible values of `%x` are `{+0.0, -0.0}`. The true result is
`canonicalize(%x)`, which for `%x == -0.0` must be `-0.0`.

Command:

```
$AW/build/bin/opt -passes=instcombine repro/src.ll -S
```

Buggy output:

```llvm
define nofpclass(nan) float @f(float nofpclass(inf sub norm) %x) #0 {
  ret float 0.000000e+00          ; <-- +0.0, WRONG: loses the -0.0 case
}
```

For input `%x = -0.0`: source yields `-0.0`, optimized output yields `+0.0`.
`-0.0` and `+0.0` differ in their bit pattern, so this is a real miscompile.

## 3. Faulty line

`llvm/lib/Support/KnownFPClass.cpp`, `KnownFPClass::canonicalize`
(origin/main, commit `89f4b84d8b2c`):

```cpp
  if (DenormMode.Input == DenormalMode::PositiveZero ||
      (DenormMode.Output == DenormalMode::PositiveZero &&
       DenormMode.Input == DenormalMode::IEEE))
    Known.knownNot(fcNegZero);   // <-- BUG: unconditional, ignores KnownSrc
```

`Known.knownNot(fcNegZero)` is applied with no guard. It should only be applied
when the source operand is known never to be `-0.0`.

## 4. Experimental evidence (captured debug output)

The showcase branch adds `LLVM_DEBUG` instrumentation (under
`-debug-only=known-fpclass-canon`) inside the positive-zero branch, printing the
fpclass mask immediately before and after `knownNot(fcNegZero)`.

Command:

```
$AW/build/bin/opt -passes=instcombine repro/src.ll -S \
    -debug-only=known-fpclass-canon
```

Captured output (verbatim):

```
[canon-denormal-negzero] PositiveZero branch entered
  DenormMode = positive-zero,positive-zero
  KnownSrc mask           = (zero)
  KnownSrc.isKnownNever(fcNegZero) = 0
  mask BEFORE knownNot(fcNegZero) = (zero)  (fcNegZero present? 1)
  mask AFTER  knownNot(fcNegZero) = (pzero)  (fcNegZero present? 0)
  >>> BUG: fcNegZero unconditionally cleared even though source MAY be -0.0
```

Reading the dump:

- `KnownSrc mask = (zero)` — the source operand may be **either** `+0.0` or
  `-0.0` (`fcZero == fcPosZero | fcNegZero`).
- `KnownSrc.isKnownNever(fcNegZero) = 0` — the source is **not** known to avoid
  `-0.0`; i.e. `-0.0` is a live possibility.
- `mask BEFORE = (zero)` — the result mask still contains `fcNegZero`
  (`fcNegZero present? 1`), which is correct so far.
- `mask AFTER = (pzero)` — `fcNegZero` was cleared (`present? 0`), leaving only
  `+0.0`. This is the **incorrect** conclusion.

The downstream consequence (final IR for `repro/src.ll`):

```llvm
  ret float 0.000000e+00
```

Because value tracking now believes the result can only be `+0.0`, InstCombine
replaces the canonicalize call with the `+0.0` constant — dropping the `-0.0`
case the source allows.

## 5. Why it is wrong

LangRef (`llvm/docs/LangRef.rst`, `@llvm.canonicalize`): *"the sign of zero must
be conserved: `@llvm.canonicalize(-0.0) = -0.0` and
`@llvm.canonicalize(+0.0) = +0.0`."* Positive-zero denormal mode flushes
**subnormals** to `+0.0`; a true `-0.0` is **not** a subnormal and is left
unchanged. Therefore the canonicalized result can still be `-0.0` whenever the
source can be `-0.0`, and `fcNegZero` must not be cleared unconditionally.

## 6. One-line fix

Guard the clear on the source: only `Known.knownNot(fcNegZero)` when
`KnownSrc.isKnownNever(fcNegZero)` (and clear `fcPosZero` only when the source is
never `+0.0` or a subnormal that would flush to `+0.0`). Implemented on branch
**`2026-06-06-alive2-instcombine-canonicalize-denormal-negzero`**.
