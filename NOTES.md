# Alive2 "Value mismatch" investigation — InstCombine `@splat_test` (in_Lcp39aa9)

## Finding
- Pass: `InstCombinePass`
- Function: `@splat_test` from `llvm/test/Transforms/InstCombine/X86/x86-pshufb.ll`
- Transform (still present on `origin/main`, base commit `89f4b84d8b2c`):

  Source:
  ```
  %1 = call <16 x i8> @llvm.x86.ssse3.pshuf.b.128(<16 x i8> %InVec, <16 x i8> zeroinitializer)
  ```
  Target (after instcombine):
  ```
  %1 = shufflevector <16 x i8> %InVec, <16 x i8> poison, <16 x i32> zeroinitializer
  ```
- alive-tv: "Transformation doesn't verify! / ERROR: Value mismatch".

## Reproduced?
YES, on fresh upstream `origin/main` (base `89f4b84d8b2c`).
- `opt -passes=instcombine min.ll -S` produces the `shufflevector ... zeroinitializer` target.
- `alive-tv src.ll tgt.ll` fails with the exact counterexample from the report:
  `%InVec = <undef, poison, ...>`, source = all-3 splat, target = `<0,..,1,..,0>` (lane 11 = 1).

## Root cause
A pshufb with an all-zero index mask makes every output lane equal `%InVec[0]`, i.e. a
*guaranteed splat* (all lanes equal). InstCombine canonicalizes this to
`shufflevector %InVec, poison, zeroinitializer`, which is also a lane-0 broadcast.

The divergence is entirely about how `undef` is modeled:

- Alive2's pshufb model (`alive2/ir/x86_intrinsics.cpp`, case `x86_ssse3_pshuf_b_128`)
  extracts input element `id` from the already-materialized input vector and reuses the
  *same* symbolic expression for every output lane. Result: all 16 lanes are bit-identical
  → a true all-equal splat, even for an undef input (the report shows the all-3 splat).

- `shufflevector` broadcasting an `undef` input element follows undef's "may take a
  different value at each use" rule: the 16 reads of the undef lane-0 are independent, so
  the result is NOT guaranteed all-equal (e.g. `<0,...,1,...,0>`).

So target's set of possible values (any vector) is a strict superset of source's
(all-equal vectors only). Refinement requires target ⊆ source, hence "unsound".

## Verdict: undef-specific Alive2 artifact — NOT a real miscompile. No patch.

Evidence:
1. Frozen input (`freeze %In` before the call): transform **verifies** (correct).
2. Explicit **poison** lane-0 input: transform **verifies** (correct) — poison broadcasts
   consistently.
3. The mismatch only arises from a literal `undef` input element.
4. Reverse direction (shufflevector → pshufb) **verifies**; the asymmetry confirms the
   difference is solely the undef model, not symmetric noise.
5. The pure-IR canonical splat (`extractelement; insertelement; shufflevector`) is modeled
   identically to a direct `shufflevector` splat — both pass both directions. So nothing on
   the shufflevector side is "wrong"; the only special-case is the intrinsic's single-read
   model.

This is the classic "splat-of-undef breaks all-equal invariant" category. The
`pshufb → shufflevector` canonicalization is long-standing, valuable, and physically sound
(real hardware broadcasts the same register byte). Restricting it (e.g. inserting a
`freeze`) purely to satisfy undef's pathological multi-use semantics would pessimize a good
canonicalization for no real-world benefit, and `undef` is being deprecated in favor of
`poison` (which already verifies). Therefore no patch is made.

## alive-tv before/after
- Before (and after, since no code change): forward `pshufb → shufflevector` fails with
  "Value mismatch" only for an `undef` input element.
- Control runs that PASS: frozen input, explicit poison input, reverse direction.

## Files
- Repro: `repro/{min.ll,src.ll,tgt.ll,src_frz.ll,tgt_frz.ll,src_pois.ll,tgt_pois.ll}`
  under the workspace root (`$AW/repro`).
- Relevant LLVM code: `llvm/lib/Target/X86/X86InstCombineIntrinsic.cpp` `simplifyX86pshufb`.
- Relevant Alive2 model: `alive2/ir/x86_intrinsics.cpp` case `x86_ssse3_pshuf_b_128`.
