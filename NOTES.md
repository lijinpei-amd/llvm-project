# Alive2 "Value mismatch" investigation — InstCombine inttoptr/ptrtoint roundtrip

Date: 2026-06-06
Worktree base: origin/main @ 89f4b84d8b2c
Report: alive2/build/logs/in_ns23a8rP.txt

## Finding (as logged)
Reported as `SLPVectorizerPass / @test`, but the actual failing transform in the
log is from **InstCombinePass**:

```
src:                                   tgt:
  %V = ptrtoint ptr %P to i32            ret ptr %P
  %P2 = inttoptr i32 %V to ptr
  ret ptr %P2
```

alive-tv: "Transformation doesn't verify! / ERROR: Value mismatch".
Counterexample: `%P = pointer(block_id=0, offset=1)`, source returns
`phy-ptr(addr=1)` (provenance-free physical pointer), target returns `%P`
(provenance block_id=0).

## Reproduced? YES (exactly)
- alive-tv on the isolated src/tgt reproduces the Value mismatch.
- This is the classic `inttoptr(ptrtoint(P)) -> P` fold. It fires only when the
  integer type width EQUALS the pointer width. The log uses `i32`, so the
  original module had a **32-bit-pointer datalayout** (e.g. `e-p:32:32`).
  Reproduced with `target datalayout = "e-p:32:32"`.

## Root cause
InstCombine `commonCastTransforms` -> `isEliminableCastPair`
(llvm/lib/Transforms/InstCombine/InstCombineCasts.cpp:187-209) eliminates a
ptrtoint->inttoptr cast pair, yielding `P`. The pair is only eliminated when the
intermediate integer type matches the pointer's index type
(`SrcTy == DstIntPtrTy`), guarding against truncation:
- i32 under 32-bit ptr  => folds to `ret %P`            (no width change)
- i32 under 64-bit ptr  => does NOT fold; emits `and i64 %x, 0xffffffff` mask

Verified with freshly built opt @ 89f4b84d8b2c — behavior identical, present in
the tree, and exercised by an existing test
(llvm/test/Transforms/InstCombine/cast_ptr.ll, `target datalayout = "p:32:32..."`).

## Verdict: Alive2 modeling artifact (known provenance limitation). NOT a real miscompile.
- The mismatch is purely about pointer **provenance**. In Alive2's strict memory
  model, `inttoptr` produces a physical pointer that may alias ANY live object at
  that address (no provenance); `%P` carries the provenance of a specific block.
  A returned pointer whose aliasing freedom shrinks from "any" to "one block" is
  flagged as a refinement violation. Refinement fails in BOTH directions
  (checked) — i.e. the two pointer values are simply incomparable in the model,
  the signature of this known issue, not a one-way unsoundness.
- LangRef does not define provenance semantics for `inttoptr`/`ptrtoint`
  (llvm/docs/LangRef.rst, i_inttoptr §13311). LLVM treats `ptrtoint` as
  "exposing" the pointer so that `inttoptr` may legitimately recover an
  equivalent pointer; the `inttoptr(ptrtoint(P)) -> P` fold is intentional,
  long-standing, and test-covered canonicalization.
- This build of alive-tv has no flag to relax physical-pointer / int<->ptr
  provenance modeling, so the model reports it.

## Patch: NONE
No LLVM change is justified — the optimization is correct under LLVM's intended
semantics. The divergence is in Alive2's conservative provenance model, not in
the compiler. The width guard already correctly prevents the genuinely-wrong
truncating case.

## alive-tv before/after
Before and after are identical (no compiler change): the equal-width roundtrip
fold reports "Value mismatch" (provenance), the truncating case is safely
rejected by InstCombine via masking. No patch applied.
