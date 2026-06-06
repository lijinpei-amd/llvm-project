# Root Cause: `simplifyGEPInst` folds `gep(V, ashr/sdiv(sub(addr P, addr V), C))` to `P` without requiring `exact`

## Summary

`InstructionSimplify.cpp::simplifyGEPInst` recognizes the idiom
"reconstruct a pointer from a scaled byte-difference" and folds

```
getelementptr <ty 2^C>, V, (ashr (sub addr(P), addr(V)), C)  -> P
getelementptr <ty C>,   V, (sdiv (sub addr(P), addr(V)), C)  -> P
```

The fold is only valid when the `ashr` / `sdiv` is **`exact`**, i.e. when the
divided/shifted value has no discarded low bits. The code matches the pattern
**without** the `exact` requirement, so for any byte-difference `D = addr(P) -
addr(V)` that is not a multiple of the element size, the low `C` bits of `D` are
silently dropped: the gep actually computes `V + ((D >> C) << C) != V + D = P`,
but the fold still returns `P`. Result: a wrong pointer.

This was latent in the `ptrtoint` paths and was surfaced by the new
`ptrtoaddr` support (#164262), which made the pattern (and these reproducers)
exercisable.

## Reproducer + command

`repro/gep-ashr-nonexact.ll` (the offset is a runtime `%n` so the
`sub`/`ashr` chain is not constant-folded before the buggy matcher runs):

```llvm
target datalayout = "e-p:64:64:64"
define ptr @src(ptr %v, i64 %n) {
  %p   = getelementptr i8, ptr %v, i64 %n   ; %p = %v + %n (same underlying object)
  %av  = ptrtoaddr ptr %v to i64
  %ap  = ptrtoaddr ptr %p to i64
  %d   = sub i64 %ap, %av                    ; D = %n
  %idx = ashr i64 %d, 1                       ; NON-exact ashr: drops low bit of D
  %r   = getelementptr i16, ptr %v, i64 %idx ; correct result: %v + ((D>>1)<<1)
  ret ptr %r
}
```

Command:

```
build/bin/opt -passes=instsimplify repro/gep-ashr-nonexact.ll -S
```

## Faulty logic (precise)

File `llvm/lib/Analysis/InstructionSimplify.cpp`, function `simplifyGEPInst`,
the single-index block (origin/main, ~line 5299):

```cpp
// getelementptr V, (ashr (sub P, V), C) -> P if P points to a type of
// size 1 << C.
if (match(Indices[0], m_AShr(m_Sub(m_PtrToIntOrAddr(m_Value(P)),
                                   m_PtrToIntOrAddr(m_Specific(Ptr))),
                             m_ConstantInt(C))) &&
    TyAllocSize == 1ULL << C && CanSimplify())
  return P;

// getelementptr V, (sdiv (sub P, V), C) -> P if P points to a type of
// size C.
if (match(Indices[0], m_SDiv(m_Sub(m_PtrToIntOrAddr(m_Value(P)),
                                   m_PtrToIntOrAddr(m_Specific(Ptr))),
                             m_SpecificInt(TyAllocSize))) &&
    CanSimplify())
  return P;
```

Both matchers accept a plain `m_AShr` / `m_SDiv`. They do **not** check the
`exact` flag. The gep that is being simplified scales `Indices[0]` back up by
`TyAllocSize`, so the round trip is `(D >> C) << C` (ashr) or `(D / C) * C`
(sdiv). That round trip equals `D` only when the shift/division is exact. The
fold replaces the gep with `P`, asserting the round trip equals `D` for all
inputs — which is false for non-exact operands.

## Experimental evidence

### 1. Instrumented fold site fires with `exact = false`

Instrumentation added at the fold site (this branch) prints the matched
constant, the `exact` flag (read via `cast<PossiblyExactOperator>(Indices[0])
->isExact()`), and that the fold returns `P` regardless.

`opt -passes=instsimplify repro/gep-ashr-nonexact.ll -S`:

```
[ROOTCAUSE gep-ashr-fold] C(shift)=1 TyAllocSize=2 (== 1<<C=2) ashr-has-exact-flag=false -> FOLDING gep(V, ashr(sub(P,V),C)) to P (UNSOUND: low C bit(s) of (P-V) discarded)

define ptr @src(ptr %v, i64 %n) {
  %p = getelementptr i8, ptr %v, i64 %n
  ret ptr %p            ; <-- folded to P; the correct gep i16 %v, 1 is gone
}
```

The dump confirms: shift amount `C = 1`, element size `TyAllocSize = 2 == 1<<C`,
**`ashr-has-exact-flag = false`**, and the fold fires anyway, replacing the gep
with `%p` (= `%v + %n`).

`opt -passes=instsimplify repro/gep-sdiv-nonexact.ll -S` (sdiv analogue):

```
[ROOTCAUSE gep-sdiv-fold] C(divisor)=2 sdiv-has-exact-flag=false -> FOLDING gep(V, sdiv(sub(P,V),C)) to P (UNSOUND: remainder of (P-V)/C discarded)
```

Control with `ashr exact` (`repro/gep-ashr-exact.ll`) — same fold, but now sound:

```
[ROOTCAUSE gep-ashr-fold] C(shift)=1 TyAllocSize=2 (== 1<<C=2) ashr-has-exact-flag=true -> FOLDING gep(V, ashr(sub(P,V),C)) to P (sound)
```

So the only difference between the unsound and sound cases is the `exact` flag —
exactly the condition the matcher fails to require.

### 2. The D = 3, C = 1, elemsize = 2 arithmetic

With `%n = 3`, so `D = addr(%p) - addr(%v) = 3`, element type `i16`
(`TyAllocSize = 2`), shift `C = 1`:

```
idx           = ashr 3, 1            = 1        (low bit of 3 discarded)
correct gep   = %v + idx*elemsize    = %v + 1*2 = %v + 2
fold returns  = %p = %v + D          = %v + 3
2 != 3   -> off-by-one (off-by-(D mod 2)) pointer
```

### 3. alive-tv counterexample

`build/alive-tv repro/alive_ashr.ll` (src = the gep; tgt = `ret %p`, i.e. the
fold) using the standalone alive2 at
`/mnt/nvme2/jinpli/workspace/home/jinpli/development/alive2`:

```
Transformation doesn't verify!
ERROR: Value mismatch

Example:
ptr %v = null
i64 %n = #x0000000000000003 (3)

Source:
i64 %d   = 3
i64 %idx = 1
ptr %r   = pointer(non-local, block_id=0, offset=2) / Address=0x2

Target:
ptr %p   = pointer(non-local, block_id=0, offset=3) / Address=0x3

Source value: pointer ... offset=2 / Address=0x2
Target value: pointer ... offset=3 / Address=0x3
```

Same `%v = null, %n = 3` witness: source pointer = offset 2 (Address 0x2),
target pointer = offset 3 (Address 0x3). The `ashr exact` control
(`repro/alive_ashr_exact.ll`) verifies: "Transformation seems to be correct!".

## Why it is wrong (concise)

The fold replaces `gep(V, op(D, C))` with `P` assuming `op(D, C)` scaled back by
`C` recovers `D`. That holds only when `op` is `exact`; a non-exact `ashr`/`sdiv`
truncates the low `C` bits / remainder of `D`, so the gep lands at `V + (D
rounded down)`, not at `P = V + D`.

## One-line fix

Require the operand to be `exact` by wrapping the matchers in `m_Exact(...)`
(i.e. `m_Exact(m_AShr(...))` and `m_Exact(m_SDiv(...))`). Implemented on branch
`2026-06-06-alive2-instsimplify-gep-ptrtoaddr`, commit `e28bfd0680a5`
("[InstSimplify] Require exact on ashr/sdiv in gep-of-sub fold").
