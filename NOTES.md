# Alive2 finding: InstCombine @fabs_nsz_src_known_positive_except_negzero

## Finding
- Pass: InstCombinePass
- Source: `%fabs = fabs nsz float nofpclass(31) %x ; ret %fabs`  (fn ret attr `nofpclass(1)`)
- Target: `ret %x`
- Alive2 counterexample: `%x = -0.0` -> source `+0.0`, target `-0.0`. "Value mismatch".

`nofpclass(31)` = nan|ninf|nsub|nnorm excluded, i.e. the arg is known
non-negative except it MAY be `-0.0` (and may be +inf/+sub/+norm/+zero).

## Verdict: ALIVE2 FALSE POSITIVE (nsz-modeling artifact). The LLVM transform is CORRECT. No LLVM patch.

## Reproduced
- Standalone alive-tv (src.ll/tgt.ll): "Transformation doesn't verify! ERROR: Value mismatch",
  unique counterexample %x=-0.0, source=+0.0, target=-0.0. (matches the original report)
- Freshly built opt (origin/main @ 89f4b84d8b2c) `-passes=instcombine` folds
  `fabs nsz %x => %x` exactly as the in-tree lit test expects.
- Lit test `llvm/test/Transforms/InstCombine/simplify-demanded-fpclass.ll`: PASS (1/1).
  Function `fabs_nsz_src_known_positive_except_negzero` is a deliberate, validated
  upstream test of precisely this nsz fold.

## Root cause (LLVM side: correct)
InstCombine `simplifyDemandedFPClassFabs`
(llvm/lib/Transforms/InstCombine/InstCombineSimplifyDemanded.cpp:2072-2075):

    // If the only sign bit difference is due to -0, ignore it with nsz
    if (NSZ &&
        KnownSrc.isKnownNever(KnownFPClass::OrderedLessThanZeroMask | fcNan))
      return Src;

The source is known to never be ordered-less-than-zero or nan (it can only be a
non-negative value or `-0.0`). The only way `fabs(x)` can differ from `x` here is
the sign of zero (`-0.0` -> `+0.0`). LangRef `nsz`: "Allow optimizations to treat
the sign of a zero argument or zero **result** as insignificant." So a `fabs nsz`
result that is a zero may legally be returned with either sign; folding to `%x`
(which may yield `-0.0`) is a valid refinement of `fabs nsz` (which may yield
`-0.0` for the same input). Transform is sound.

## Root cause (Alive2 side: the artifact)
alive2/ir/instr.cpp, `fm_poison` (lines 749-837) and `any_fp_zero` (679-697):

- NSZ is modeled by applying `any_fp_zero` to the OPERANDS only (lines 769-776):
  each zero input becomes a nondet choice of +0/-0.
- For `bitwise` ops (FAbs, FNeg) the result is `fn(a,b,c,{})` directly (line 791);
  no nsz freedom is applied to the RESULT.

For `fabs`: input `any_fp_zero(-0.0)` -> {+0.0, -0.0}, then `fabs(+/-0.0) = +0.0`
always. The operand-level nsz nondeterminism collapses under fabs, and since the
result never receives `any_fp_zero`, Alive2 fixes `fabs nsz(<any zero>) = +0.0`
and rejects the legal `-0.0` result.

Contrast: `fadd nsz x, 0.0 => x` verifies in Alive2, because there the operand-level
`any_fp_zero` can produce a negative-zero result path (e.g. (-0.0)+(-0.0) = -0.0),
so the result can be either sign. The bug is specific to ops where operand
zero-sign freedom does not propagate to the result (fabs; also fneg of a zero, and
generally any nsz fp op whose zero result sign is fixed by the operation).

Minimal demonstration of the Alive2 gap (x constrained to {+0,-0}):
  src: `%r = call nsz @llvm.fabs.f32(float %x)` ; `ret %r`
  tgt: `ret float -0.0`
  Alive2 reports mismatch (source +0.0 vs target -0.0) even though `fabs nsz` of a
  zero should permit -0.0.

## Suggested Alive2 fix (not applied here; LLVM is correct)
In `fm_poison`, when `fmath` has NSZ, also wrap the computed result in
`any_fp_zero` (so a zero result may take either sign), in addition to the existing
operand wrapping. This would make `fabs nsz`/`fneg nsz`/etc. results honor nsz's
"zero result sign is insignificant" semantics and clear this class of false
positives.

## Artifacts
- Workspace: see directory of this file's parent's parent (the -1921460 dir).
- min.ll, src.ll, tgt.ll, t1_*.ll (fadd nsz control), t3_*.ll (fabs nsz zero gap).
- Upstream commit verified: 89f4b84d8b2c.
