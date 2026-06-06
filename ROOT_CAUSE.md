# Root Cause: InstCombine X86 `simplifyX86immShift` miscompiles masked psra/psrl/psll (undef/poison low lane)

## Summary

`simplifyX86immShift` (X86 InstCombine) lowers a *shift-by-scalar* x86 vector shift
intrinsic (`x86.sse2.psra.w` and friends) to a generic vector shift by broadcasting
the low element of the amount operand via
`shufflevector(Amt, poison, zeroinitializer)`.

When the low element of `Amt` may be **undef/poison**, this is unsound: a generic
`ashr`/`lshr`/`shl` against a non-frozen possibly-undef splat lets **each result lane
choose its own value** for the shift amount, whereas the intrinsic reads **one** scalar
amount from lane 0 and applies the **same** amount to every lane. The two are not
equivalent → miscompile (Alive2 "Value mismatch").

## Reproducer + command

Self-contained repro (note: the x86 `target datalayout`/`triple` are **required** —
without them `simplifyX86immShift` is never invoked for the shift-by-scalar path):

File: `rootcause_psra_repro.ll`
```llvm
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
declare <8 x i16> @llvm.x86.sse2.psra.w(<8 x i16>, <8 x i16>)
define <8 x i16> @f(<8 x i16> %v, <8 x i16> %a) {
  %1 = and <8 x i16> %a, <i16 15, i16 0, i16 0, i16 0, i16 undef, i16 undef, i16 undef, i16 undef>
  %2 = tail call <8 x i16> @llvm.x86.sse2.psra.w(<8 x i16> %v, <8 x i16> %1)
  ret <8 x i16> %2
}
```

Command:
```
opt -passes=instcombine rootcause_psra_repro.ll -S
```

The `src.ll`/`tgt.ll` pair under `../repro/` is the matching Alive2 transform pair
(src = intrinsic form, tgt = exactly the IR InstCombine emits below); Alive2 reports a
Value mismatch for it.

## Faulty logic

`llvm/lib/Target/X86/X86InstCombineIntrinsic.cpp`, `simplifyX86immShift`,
shift-by-scalar (`else`) branch, ~lines 237-243 on `origin/main`:

```cpp
if (KnownLowerBits.getMaxValue().ult(BitWidth) &&
    (DemandedUpper.isZero() || KnownUpperBits.isZero())) {
  SmallVector<int, 16> ZeroSplat(VWidth, 0);
  Amt = Builder.CreateShuffleVector(Amt, ZeroSplat);   // <-- broadcasts lane 0, no freeze
  return (LogicalShift ? (ShiftLeft ? Builder.CreateShl(Vec, Amt)
                                    : Builder.CreateLShr(Vec, Amt))
                       : Builder.CreateAShr(Vec, Amt));
}
```

The guard only checks that lane 0's *value* is in range (`KnownLowerBits`) and that the
other demanded low-half lanes are zero. It does **not** check that lane 0 is defined.
`computeKnownBits` treats undef/poison conservatively (it does not prove range), but the
`and X, undef` lanes still leave lane 0 possibly-undef once `undef` is canonicalized to
`poison`. The broadcast is then performed on a possibly-poison element without a
`freeze`.

## Experimental evidence (instrumented build)

Instrumentation added at the broadcast site (this branch) prints `Amt`, the
undef/poison guard, and the emitted splat. Running the command above:

STDERR (instrumentation dump):
```
[ROOT-CAUSE psra] Amt =   %1 = and <8 x i16> %a, <i16 15, i16 0, i16 0, i16 0, i16 undef, i16 undef, i16 undef, i16 undef>
[ROOT-CAUSE psra] isGuaranteedNotToBeUndefOrPoison(Amt) = false
[ROOT-CAUSE psra] emitted splat =   %2 = shufflevector <8 x i16> %1, <8 x i16> poison, <8 x i32> zeroinitializer
```

STDOUT (resulting IR):
```llvm
define <8 x i16> @f(<8 x i16> %v, <8 x i16> %a) {
  %1 = and <8 x i16> %a, <i16 15, i16 poison, i16 poison, i16 poison, i16 poison, i16 poison, i16 poison, i16 poison>
  %2 = shufflevector <8 x i16> %1, <8 x i16> poison, <8 x i32> zeroinitializer
  %3 = ashr <8 x i16> %v, %2
  ret <8 x i16> %3
}
```

Interpretation, tying each line to the bug:

1. `isGuaranteedNotToBeUndefOrPoison(Amt) = false` — InstCombine itself proves it
   **cannot** guarantee the amount operand (whose lane 0 feeds the splat) is well
   defined. Despite this, the transform proceeds with no `freeze`.
2. `emitted splat = shufflevector %1, poison, zeroinitializer` reads lane 0 of `%1`.
   In the final IR `%1`'s lane 0 is `%a & 15`; the source-level `undef` lanes were
   canonicalized to `poison`. A `shufflevector` reading a possibly-undef lane 0 produces
   a splat that is **not guaranteed uniform**: undef/poison may be materialized
   differently per use/lane.
3. The final `ashr <8 x i16> %v, %2` therefore allows **each lane** to be shifted by a
   potentially different amount, whereas `llvm.x86.sse2.psra.w` uses the single scalar
   lane-0 amount for **all** lanes. (Diagnostic confirmation: the guard condition
   `cond=1` with `LowerMax=15`, `UpperZero=1` is satisfied purely on value/range — it
   never tests definedness — so the rewrite fires exactly in the undef-lane case.)

This is the divergence Alive2 reports as a Value mismatch.

## Why this is wrong (concise)

The x86 immediate-shift intrinsics apply one scalar shift amount (lane 0) uniformly to
every lane; broadcasting a possibly-undef/poison lane 0 with `shufflevector` does not
yield a single fixed amount, so result lanes may legally differ from the intrinsic's
uniform shift.

## One-line fix

Freeze the amount before splatting when it is not provably defined:
`if (!isGuaranteedNotToBeUndefOrPoison(Amt)) Amt = Builder.CreateFreeze(Amt);`
before `Builder.CreateShuffleVector(Amt, ZeroSplat)`.
See patch branch `2026-06-06-alive2-instcombine-sse2-psra-mask`
(hash `886364dd89270608839c85f01bb895a02bb994cf`).
