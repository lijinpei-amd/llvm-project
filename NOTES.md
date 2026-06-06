# Alive2 "Value mismatch" investigation: InstCombine @splat_test (pshufb -> shufflevector)

Report: alive2/build/logs/in_vYaCLTrW.txt
Sibling report: alive2/build/logs/in_Lcp39aa9.txt

## Verdict: NOT A REAL BUG. No patch. Duplicate of in_Lcp39aa9.

## The transform (transform #27 in the log)

Test: llvm/test/Transforms/InstCombine/X86/x86-pshufb.ll, function `@splat_test`.
Pipeline: `opt -passes=instcombine -mtriple=x86_64-unknown-unknown`.

Source:
    %1 = call <16 x i8> @llvm.x86.ssse3.pshuf.b.128(<16 x i8> %InVec, <16 x i8> zeroinitializer)
=>
Target:
    %1 = shufflevector <16 x i8> %InVec, <16 x i8> poison, <16 x i32> zeroinitializer

Performed by `simplifyX86pshufb` in
llvm/lib/Target/X86/X86InstCombineIntrinsic.cpp (~line 2024).
With an all-zero control mask, pshufb selects byte index `0 & 0x0F = 0` for
every output lane (within each 128-bit lane), i.e. a splat of byte 0. The fold
to `shufflevector ..., <0,0,...,0>` is exactly that splat. Semantically correct.

## Why Alive2 reports a mismatch (undef artifact)

Counterexample: `%InVec = <undef, poison, poison, ...>`.
- Source value: `<3,3,3,...,3>` (all lanes equal, "based on undef") -- Alive2's
  intrinsic model resolves the single undef source byte to one value per lane and
  here yields a uniform vector.
- Target value: `<0,...,0,1,0,...>` (lane 11 = 1) -- per LangRef, shufflevector
  reading an undef source element yields an INDEPENDENT undef per output lane, so
  Alive2 lets each result lane pick a different value.

The target therefore has strictly MORE undef freedom than the source. Alive2's
refinement check (target may only ever produce values the source can produce)
flags this as "unsound" because the target can produce a non-uniform vector that
the source's uniform model cannot. This is the classic "splat of undef" /
"duplicated undef is per-lane independent" Alive2 modeling limitation, not a
miscompile: for any *defined* input both forms produce identical results.

## Proof it is undef-only

Adding `freeze` to the input makes the transform verify:
    %InVec = freeze <16 x i8> %InVec0
    src: pshufb(%InVec, zero)   tgt: shufflevector %InVec, poison, zero
=> alive-tv: "Transformation seems to be correct!"  (1 correct, 0 incorrect)

Repro files: NOTES are accompanied by build/ repro dir at
alive2-working/2026-06-06-splat-undef-b-vYaCLTrW/repro/ (min.ll, src.ll, tgt.ll,
src_frozen.ll, tgt_frozen.ll).

## Relation to sibling finding in_Lcp39aa9

in_Lcp39aa9.txt is the SAME test file run, the SAME function @splat_test, the
SAME transform (#27: pshufb zero-mask -> shufflevector zero-mask), and the SAME
Value mismatch with the identical counterexample (lane 11 = 1). The two logs are
duplicates of one finding; same root cause.

## Conclusion

No LLVM bug; the fold is sound. No code change. This is an Alive2 undef-modeling
artifact (splat of undef). Recommend no action (or, if desired upstream, this is
a known false-positive class for X86 intrinsic -> shufflevector folds with undef
inputs).
