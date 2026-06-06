# Root Cause: InstCombine wrongly folds `icmp ne <aligned-allocator>, null` to `true`

## Summary

`isAllocSiteRemovable` (the `Instruction::ICmp` case in
`llvm/lib/Transforms/InstCombine/InstructionCombining.cpp`) folds an
equality/inequality compare of an allocation pointer against `null` to a
constant when the allocation's only uses are such comparisons (it assumes the
allocator never returns null).

A bail-out exists for *aligned* allocators (commit `0af5c0668a1b`, #69474),
because an aligned allocator may legally return `null` when the requested
alignment cannot be satisfied. **But that bail-out is keyed on the TLI libc
function identity** (`TheLibFunc == LibFunc_aligned_alloc`), **not on the
generic `allockind("aligned")` attribute.** Any user-declared allocator that is
`allockind("...,aligned")` but is *not* recognized as the libc `aligned_alloc`
bypasses the guard, is wrongly assumed never-null, and its `icmp ne null` is
folded to `true` — a miscompile.

## Reproducer

`repro/src.ll`:

```llvm
target datalayout = "p:32:32:32"

define i1 @other_aligned_allocation_function(i32 %size, i32 %alignment, i8 %value) {
  %aligned_allocation = tail call ptr @other_aligned_alloc(i32 %alignment, i32 %size)
  %cmp = icmp ne ptr %aligned_allocation, null
  ret i1 %cmp
}

declare noalias ptr @other_aligned_alloc(i32, i32) allockind("alloc,uninitialized,aligned") allocsize(1) "alloc-family"="malloc"
```

Command:

```
opt -passes=instcombine repro/src.ll -S
```

## Faulty logic

In the `ICmp` case, the only thing protecting an aligned allocator from the
"never null" fold is:

```cpp
auto *CB = dyn_cast<CallBase>(AI);
LibFunc TheLibFunc;
if (CB && TLI.getLibFunc(*CB->getCalledFunction(), TheLibFunc) &&
    TLI.has(TheLibFunc) && TheLibFunc == LibFunc_aligned_alloc &&
    !AlignmentAndSizeKnownValid(CB))
  return std::nullopt;          // bail out: do NOT fold
```

The guard only triggers for the one libc function `LibFunc_aligned_alloc`. An
allocator carrying `allockind("...,aligned")` but with any other name (or no
matching libfunc) never satisfies `TheLibFunc == LibFunc_aligned_alloc`, so the
`return std::nullopt` never executes and the compare is folded. The decision is
made on the *name* of the allocator instead of on its *aligned* allocation
property.

## Experimental evidence

The bail-out was instrumented (see the `[ROOTCAUSE]` block in
`InstructionCombining.cpp` on branch
`2026-06-06-alive2-instcombine-aligned-alloc-rootcause`) to print, at the guard,
the callee name, whether the `Aligned` allockind bit is set, whether the
resolved TLI libfunc is `aligned_alloc`, and whether the guard fires.

Running the command above produces (stderr then stdout):

```
[ROOTCAUSE] isAllocSiteRemovable ICmp on call to 'other_aligned_alloc': allockind Aligned=YES, resolved-libfunc-is-aligned_alloc=no -> guard SKIPPED.
[ROOTCAUSE]   BUG: aligned allocator NOT keyed by LibFunc_aligned_alloc; bail-out skipped; compare '  %cmp = icmp ne ptr %aligned_allocation, null' will be folded to a constant.

define i1 @other_aligned_allocation_function(i32 %size, i32 %alignment, i8 %value) {
  ret i1 true
}
```

Interpretation:

- `allockind Aligned=YES` — the callee *is* an aligned allocator (the `aligned`
  bit of `allockind` is set), so per LangRef it may return null.
- `resolved-libfunc-is-aligned_alloc=no` — TLI does not classify
  `other_aligned_alloc` as `LibFunc_aligned_alloc`, so the name-keyed condition
  is false.
- `guard SKIPPED` — `return std::nullopt` does not execute; the allocation is
  treated as never-null.
- Result IR: the function body collapses to `ret i1 true`, i.e. `icmp ne
  %aligned_allocation, null` was folded to `true`. This is the miscompile: at
  runtime `other_aligned_alloc` may return null (the source could yield
  `false`), so the transform is unsound.

## Why this is wrong (LangRef)

LangRef `allocalign` / `allockind("aligned")`: the returned value "must either
have the specified alignment or be the null pointer," and "invalid (e.g.,
non-power-of-2) alignments are permitted ... so long as the returned pointer is
null." Therefore any `allockind("aligned")` allocator may legally return null,
and `icmp ne null` cannot be folded to `true` unless the alignment (and size)
are provably valid.

## Fix (one line, conceptually)

Gate the bail-out on the generic *aligned* allocation property instead of the
libc name: bail out whenever the call's combined `allockind` contains
`AllocFnKind::Aligned` (and the alignment/size are not provably valid), regardless
of whether TLI recognizes it as `LibFunc_aligned_alloc`. See the implemented fix
on branch `2026-06-06-alive2-instcombine-aligned-alloc` (`IsAlignedAllocation`
helper checking `(Kind & AllocFnKind::Aligned) != AllocFnKind::Unknown`).
