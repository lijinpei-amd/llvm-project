# Alive2 finding investigation: VectorCombine reduce_xor over <6 x i16> with poison lanes

## Finding
- Pass: `VectorCombinePass` (`foldShuffleChainsToReduce`)
- Function: `@test_reduce_v6i16_xor`
- Alive2 report: `Value mismatch`, source value `0`, target value `1`.
- Counterexample: `%a0 = <0, 1, 0, 0, 0, 0>`.

The transform folds a manual XOR-reduction tree (binop + shufflevector chain
with poison lanes) over a `<6 x i16>` into `llvm.vector.reduce.xor.v6i16`.

## Verdict: REAL bug (now fixed upstream)

This was a genuine miscompile, not an Alive2 artifact. It is already fixed on
upstream `main`.

- Fixing commit: `dc448dad35c8` — "[VectorCombine] Don't fold non-idempotent
  shuffle reductions when shuffle duplicates element (#200778)"
  (Author: lijinpei-amd <jinpli@amd.com>, 2026-06-02)

## Root cause
`foldShuffleChainsToReduce` reduces a vector with a tree of (binop, shuffle)
steps. For each step it halves the active lane count using a parity-based
shuffle mask. When the active lane count is odd (which happens for
non-power-of-2 vectors, e.g. 6 -> 3 -> 2 -> 1), the parity mask DUPLICATES a
lane into the next step.

Lane duplication is harmless only for idempotent reduction ops (e.g. and, or,
smax, umin: `x op x == x`). For non-idempotent ops (xor, add) the duplicated
lane is combined more than once and changes the result.

### Trace of the counterexample (`%a0 = <0,1,0,0,0,0>`)
- `%2 = a0 ^ shuffle(a0,<3,4,5,..>)` = `<0, 1, 0, p, p, p>`
- `%4 = %2 ^ shuffle(%2,<1,2,..>)`   = `<0^1, 1^0, p, ...>` = `<1, 1, p, ...>`
  (here lane 1's value 1 has been mixed into BOTH lane 0 and lane 1 — the
  duplication, because 3 active lanes is odd)
- `%6 = %4 ^ shuffle(%4,<1,..>)`     = `<1^1, ...>` = `<0, p, ...>`
- result = 0.

The duplicated contribution of `a0[1]` is XOR'd twice and cancels, so the
source yields 0. A true `reduce_xor` counts every lane exactly once:
`0^1^0^0^0^0 = 1`. Hence source 0 vs target 1.

## Fix (already upstream — reproduced here for the record)
In `VectorCombine::foldShuffleChainsToReduce`, track a `HasLaneDuplication`
flag whenever the parity mask is odd, and bail out of the fold when a lane was
duplicated and the common binop is not idempotent:

```cpp
HasLaneDuplication |= (ExpectedParityMask & 1) != 0;
...
// If the parity masks duplicated any lane, the fold only preserves semantics
// for idempotent ops.
if (HasLaneDuplication && CommonBinOp &&
    !Instruction::isIdempotent(*CommonBinOp))
  return false;
```

## Verification

### alive-tv (buggy direction — confirms unsound)
`alive-tv repro/src.ll repro/tgt.ll` →
`Transformation doesn't verify! / ERROR: Value mismatch`
with the exact same counterexample as the Alive2 report (src 0, tgt 1).

### Current upstream `opt` (fixed)
`opt -passes=vector-combine repro/min.ll -S` leaves the xor shuffle chain
unchanged (does NOT introduce `reduce_xor`). The idempotent `smax` case
(`test_reduce_v3i16_smax`) still folds to `reduce.smax`. Regression coverage
lives in
`llvm/test/Transforms/VectorCombine/fold-shuffle-chains-to-reduce.ll`
(`test_no_reduce_v6i16_xor`, `test_no_reduce_v3i32_add`,
`test_no_partial_reduce_v6i32_add`, `test_reduce_v3i16_smax`).

## Conclusion
No new patch required: the bug is already correctly fixed and tested on
upstream main as of commit `dc448dad35c8`. This branch documents the
investigation only.
