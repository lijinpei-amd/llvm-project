# Root Cause: `@llvm.objectsize` miscompile for `select(gep@2, gep@10)` into a 5-byte object

## Summary
In `Min` evaluation mode, `@llvm.objectsize` folds to `65531` (i.e. `(uint16_t)-5`)
instead of `0` for a pointer that may be out of bounds. The intrinsic must return
`0` in `Min` mode when any reachable pointer is past the end of the object; instead
it returns a huge value, which a caller (e.g. `__builtin_object_size` /
`-fsanitize=object-size` / bounds checks) treats as "plenty of room", defeating the
check. This is a real miscompile.

## Reproducer
File: `repro/min.ll`

```llvm
target datalayout = "e-p:16:16:16"

define i32 @possible_out_of_bounds_gep_i16_sroa(i1 %c0, i1 %c1) {
entry:
  %obj = alloca [5 x i8], align 1
  %.sroa.gep  = getelementptr i8, ptr %obj, i16 2
  %.sroa.gep1 = getelementptr i8, ptr %obj, i16 10        ; offset 10 into a 5-byte object => OOB
  %offset.sroa.sel = select i1 %c0, ptr %.sroa.gep, ptr %.sroa.gep1
  %objsize_max = call i32 @llvm.objectsize.i32.p0(ptr %offset.sroa.sel, i1 false, i1 true, i1 false) ; Max
  %objsize_min = call i32 @llvm.objectsize.i32.p0(ptr %offset.sroa.sel, i1 true,  i1 true, i1 false) ; Min
  %res = select i1 %c1, i32 %objsize_max, i32 %objsize_min
  ret i32 %res
}
```

Command (matches the failing pipeline):

```
opt -passes=lower-constant-intrinsics repro/min.ll -S
```

Buggy result: `%res = select i1 %c1, i32 3, i32 65531` — the `Min` operand is `65531`
(should be `0`). See `repro/tgt_buggy.ll` (observed) vs `repro/tgt.ll` (correct: `0`).

## Faulty logic
Two cooperating defects in `llvm/lib/Analysis/MemoryBuiltins.cpp`:

1. `ObjectSizeOffsetVisitor::combineOffsetRange` (Min mode) minimizes the `Before`
   and `After` fields of the two branch `OffsetSpan`s **independently**:

   ```cpp
   case ObjectSizeOpts::Mode::Min:
     return {LHS.Before.slt(RHS.Before) ? LHS.Before : RHS.Before,
             LHS.After.slt(RHS.After) ? LHS.After : RHS.After};
   ```

   `Before` (offset from object start) is taken from one branch and `After`
   (bytes remaining after the pointer) from the other, producing a combined span
   that corresponds to **neither** actual branch. Here: `Before=2` (from gep@2)
   and `After=-5` (from gep@10).

2. `compute()` lowers the span to `SizeOffsetAPInt` via
   `{Size = Before + After, Offset = Before}` (MemoryBuiltins.cpp:811).
   With the inconsistent span this gives `Size = 2 + (-5) = -3`, `Offset = 2`.
   The negative `After` makes `Size` **wrap negative**.

3. `getSizeWithOverflow` then uses an **unsigned** out-of-bounds check:

   ```cpp
   if (Offset.isNegative() || Size.ult(Offset))   // BUG: ult
     return APInt::getZero(...);
   return Size - Offset;
   ```

   `Size = -3` as unsigned 16-bit is `65533`, which is **not** `< Offset (2)`, so
   the clamp-to-zero is skipped and the function returns `Size - Offset = -5 =
   65531`. A negative (wrapped) remaining size is invisible to an unsigned compare.

## Experimental evidence
Instrumentation added to `combineOffsetRange` (Min) and `getSizeWithOverflow`.
Running the command above prints (verbatim):

```
[objsize] getSizeWithOverflow: Size=13 Offset=10 Size.ult(Offset)=false Size.slt(Offset)=false => result(ult-path)=3
[objsize] combineOffsetRange(Min): LHS{Before=2,After=3} RHS{Before=10,After=-5} => Combined{Before=2,After=-5} (Size=Before+After=-3)
[objsize] getSizeWithOverflow: Size=-3 Offset=2 Size.ult(Offset)=false Size.slt(Offset)=true => result(ult-path)=65531
```
and emits `%res = select i1 %c1, i32 3, i32 65531`.

Reading the trace:
- Line 1 is the `Max` call (`objsize_max`): a single branch, `Size=13,Offset=10`,
  remaining `= 3`. Correct.
- Line 2 is the `Min` combine: the two real branches are
  `LHS{Before=2,After=3}` (gep@2, valid) and `RHS{Before=10,After=-5}` (gep@10, OOB).
  Independent min yields `Combined{Before=2,After=-5}` — an inconsistent span that
  belongs to neither branch — so `Size = Before+After = -3`.
- Line 3 is the `Min` `getSizeWithOverflow`: `Size=-3, Offset=2`.
  - `Size.ult(Offset)=false`  <- buggy unsigned check, OOB **missed**
  - `Size.slt(Offset)=true`   <- signed check, OOB **detected**
  - With the `ult` path the result is `65531`, exactly the wrong folded value seen
    in the output.

This is the smoking gun: `Size.ult(Offset)=false` while `Size.slt(Offset)=true`,
and the `ult` path yields `65531`.

## Why this is wrong
The remaining object size after the pointer is `Size - Offset`; when the pointer is
past the end this is negative and must clamp to `0`. An unsigned `Size.ult(Offset)`
test cannot detect a negative (wrapped) `Size`, so out-of-bounds spans escape as
huge positive sizes.

## One-line fix
Use a signed comparison so a negative remaining size is detected:
`Size.ult(Offset)` -> `Size.slt(Offset)` in `getSizeWithOverflow`.
(Verified on patch branch `2026-06-06-alive2-objectsize-oob-gep`, which makes the
`Min` operand fold to `0`.)
