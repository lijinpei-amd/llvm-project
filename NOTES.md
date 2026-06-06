# Alive2 finding: uitofp i129 -> half/float expansion produces -0.0 instead of +inf

## Status: ALREADY FIXED UPSTREAM (no new patch needed)

Fixing commit: `4e47b560196a` — "[ExpandIRInsts] Fix sitofp/uitofp to float
producing garbage instead of inf (#200291)", authored 2026-05-29, Fixes #189054.
It is an ancestor of current `origin/main` (HEAD `89f4b84d8b2c`).

## The finding

Alive2 report: `build/logs/in_We6A2fW8.txt`.

Pass: `--expand-ir-insts` (LLVM ExpandIRInsts, the int<->fp soft expansion in
`llvm/lib/CodeGen/ExpandIRInsts.cpp`, function `expandIToFP`). Formerly
ExpandLargeFpConvert / ExpandFp.

Source:
```llvm
define float @ui129tofloat(i129 %a) { %c = uitofp i129 %a to float  ret float %c }
define half  @ui129tohalf (i129 %a) { %c = uitofp i129 %a to half   ret half  %c }
```

Counterexample (from the report, ui129tofloat):
`%a = 0x1fffffffffffffffffffffffffffffc00` (= 2^129 - 1024, top bit = bit 128).
- Source value: `0x7f800000` = +inf (correct: value ~6.8e38 >> float max 3.4e38).
- Target (buggy expansion) value: `0x80000000` = -0.0.

## Root cause (verified by reading the source)

`expandIToFP` assembles the float bit pattern manually. The unbiased exponent is
the position of the top set bit, `Sub2 = BitWidth-1-ctlz` (`Sub1 = BitWidth-ctlz`
on one path). It is placed into the exponent field by:
`biased = (E << FPMantissaWidth) + (ExponentBias << FPMantissaWidth)`.

For the counterexample `ctlz=0`, so the exponent fed in is 129 (or 128).
`129 + bias 127 = 256 = 0x100`, which does not fit the 8-bit float exponent field
and carries into the sign bit -> `0x80000000` -> -0.0. There was **no overflow /
saturation-to-infinity** for input magnitudes that exceed the float's max finite
value. This cannot happen for i32->float (exponent always fits) but happens for
wide integers like i129/i256.

For the `half` type the expansion goes through float (FPMantissaWidth is forced to
23, FloatWidth=32) and then `fptrunc float -> half`. So half inherited the broken
float intermediate (garbage / -0.0), instead of saturating to half +inf.

## The fix (commit 4e47b560196a)

After assembling `A4`, it adds:
```cpp
unsigned ExponentWidth = FloatWidth - FPMantissaWidth - 1;
uint64_t MinInfExp = 1ULL << (ExponentWidth - 1);   // float: 1<<7 = 128
if (BitWidth - 1 >= MinInfExp) {
  Value *Overflow = Builder.CreateICmpUGE(Sub2, MinInfExpVal);
  Value *Inf = +inf; // -inf selected by sign for sitofp
  A4 = Builder.CreateSelect(Overflow, Inf, A4);
}
```
i.e. when the unbiased exponent reaches the value at which the exponent field would
overflow, saturate to a correctly-signed infinity.

Correctness for `half`: half overflows at a much smaller exponent (>= 16) than the
threshold here (128). For 16 <= Sub2 < 128 the float intermediate is a *valid
finite* float, and `fptrunc float -> half` correctly rounds it up to half +inf.
For Sub2 >= 128 the float itself would be garbage, so the explicit saturate select
handles it. Both ranges are covered. (The half lit CHECK in
`test/Transforms/ExpandIRInsts/X86/expand-large-fp-convert-ui129tofp.ll` now
contains `select i1 ..., half +inf, half ...`.)

## Verification performed in this worktree (built from origin/main)

opt: `<AW>/build/bin/opt`, alive-tv: `alive2/build/alive-tv`.

Reproducer dir: `<AW>/repro/`.

1. JIT (lli) run of the EXPANSION on the exact counterexample
   `%a = 680564733841876926926749214863536421888`:
   - FIXED   expansion: `float_bits=0x7f800000  half_bits=0x7c00`  (both +inf) CORRECT.
   - BUGGY   expansion (saturation select removed): `float_bits=0x80000000
     half_bits=0x8000` (both -0.0) -> exactly reproduces the report.

2. alive-tv `uitofp i129 -> half`:
   - BUGGY (saturation removed): "1 incorrect transformation",
     Source `0x7c00 (+oo)` vs Target `0x7fff (QNaN)` -> bug confirmed.
   - FIXED: 0 incorrect (full proof times out due to i129 ctlz SMT cost; the
     original Alive2 report likewise timed out on the half function and only
     produced the definitive Value mismatch on the float function).

3. lit: `Transforms/ExpandIRInsts/X86/expand-large-fp-convert-{ui,si}129tofp.ll`
   PASS with the fixed code.

## Verdict

REAL bug in the ExpandIRInsts int->fp expansion (missing overflow saturation to
infinity for wide integers), affecting float, half and bfloat results. Already
fixed upstream by 4e47b560196a (#200291, Fixes #189054). No new patch required.
