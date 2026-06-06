# Root Cause: GVN forwards a memset to a wider typed load with an unsound splat

## Summary
When GVN forwards a `memset` to a load whose type is wider than one byte, it
reconstructs the loaded value in `VNCoercion::getMemInstValueForLoad` by
splatting the memset's *stored SSA value* across all bytes with a
`zext` + `shl`/`or` chain. A real memset writes one byte value to every byte of
memory, so a wide reload must observe a value whose bytes are **all equal**
(`0xVVVVVVVV`). The splat, however, reuses the same SSA value at multiple uses,
and under LLVM's `undef` semantics each use of an `undef` value may
independently take a different value. For a memset of an `undef` byte the
target can therefore produce **mixed-byte** patterns (e.g. `0x00000002`) that
the source can never produce. This is a non-refinement (the transform is
strictly more defined than the source), i.e. a miscompile.

This is observed only for a non-constant memset value that is (or may be)
`undef`/`poison`. Constants are all-equal-byte by construction and are sound.

## Reproducer
File: `repro/min.ll` (and `repro/src.ll` / `repro/tgt.ll` for alive-tv).

```llvm
target datalayout = "e-p:32:32:32-p1:16:16:16-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-n8:16:32"
declare void @llvm.memset.p0.i64(ptr, i8, i64, i1)
define float @memset_to_float_local(ptr %A, i8 %Val) nounwind ssp {
entry:
  tail call void @llvm.memset.p0.i64(ptr %A, i8 %Val, i64 400, i1 false)
  %arrayidx = getelementptr inbounds float, ptr %A, i64 42
  %ttmp2 = load float, ptr %arrayidx
  ret float %ttmp2
}
```

Command:
```
opt -passes=gvn repro/min.ll -S
```

## Faulty logic
`llvm/lib/Transforms/Utils/VNCoercion.cpp`, `getMemInstValueForLoad`
(memset branch, ~lines 424-449 on the unfixed baseline):

```cpp
Value *Val = MSI->getValue();          // possibly undef, NOT frozen
if (LoadSize != 1)
  Val = Builder.CreateZExtOrBitCast(Val, IntegerType::get(Ctx, LoadSize * 8));
Value *OneElt = Val;
// splat: Val = Val | (Val << 8) | (Val << 16) | ...   <-- multiple uses of Val
```

The single SSA value `Val` (= `%Val`, here `undef`) is consumed by every
`shl`/`or` in the splat chain. Each use of an `undef` value is independent, so
byte _i_ and byte _j_ of the reconstructed word need not be equal. The source
memset guarantees they are equal. Hence target ⊐ source (more defined) =
miscompile.

## EXPERIMENTAL EVIDENCE

### 1. Instrumented compiler dump (smoking gun)
Built `opt` with `errs()` instrumentation at the splat-construction site on
branch `2026-06-06-alive2-gvn-memset-typed-load-rootcause`.
`opt -passes=gvn repro/min.ll -S` prints:

```
[VNCoerce-RC] getMemInstValueForLoad: memset splat into wide load
[VNCoerce-RC]   LoadSize(bytes) = 4
[VNCoerce-RC]   splatted value  = i8 %Val
[VNCoerce-RC]   isa<Constant>   = 0
[VNCoerce-RC]   guaranteedNotUndefOrPoison = 0  (this is the soundness precondition; false here)
[VNCoerce-RC]   -> splat reuses this NON-frozen value LoadSize times; undef uses may diverge across bytes
[VNCoerce-RC]   emitted splat root value =   %4 = or i32 %2, %3
[VNCoerce-RC]   emitted broadcast IR (built from non-frozen value):
[VNCoerce-RC]       tail call void @llvm.memset.p0.i64(ptr %A, i8 %Val, i64 400, i1 false)
[VNCoerce-RC]       %arrayidx = getelementptr inbounds float, ptr %A, i64 42
[VNCoerce-RC]       %0 = zext i8 %Val to i32
[VNCoerce-RC]       %1 = shl i32 %0, 8
[VNCoerce-RC]       %2 = or i32 %0, %1
[VNCoerce-RC]       %3 = shl i32 %2, 16
[VNCoerce-RC]       %4 = or i32 %2, %3
[VNCoerce-RC]       ...
```

Interpretation: the value being splatted is the non-constant `i8 %Val`;
`isa<Constant> = 0` and `guaranteedNotToBeUndefOrPoison = 0`, so the soundness
precondition (all bytes provably equal) does **not** hold. The emitted chain
derives every byte from `%0 = zext i8 %Val` — the same non-frozen `undef` value
reused, so the bytes are free to diverge.

### 2. Emitted target IR
```llvm
%0 = zext i8 %Val to i32
%1 = shl i32 %0, 8
%2 = or i32 %0, %1
%3 = shl i32 %2, 16
%4 = or i32 %2, %3
%5 = bitcast i32 %4 to float
ret float %5
```

### 3. alive-tv counterexample (before)
`alive-tv repro/src.ll repro/tgt.ll`:

```
Transformation doesn't verify!
ERROR: Value mismatch
Example:
  i8 %Val = undef
Source: float %ttmp2 = #x03030303 (3.8500897e-37)   [based on undef]
Target: float %#5     = #x00000002 (3e-45)
Source value: #x03030303
Target value: #x00000002
  0 correct / 1 incorrect
```

The source can only yield an all-equal-byte value (here `0x03030303`); the
target yields a mixed-byte value `0x00000002` that the source cannot produce.
This matches the predicted failure mode exactly.

### 4. alive-tv freeze controls (correct)
- Control A — freeze the memset value in BOTH src and tgt
  (`repro/src_frz.ll -> repro/tgt_frz.ll`): **"Transformation seems to be
  correct!"** (1 correct / 0 incorrect). Freezing collapses `undef` to a single
  fixed byte, so all splatted bytes are forced equal.
- Control B — the actual fix: insert `freeze` before the splat in the target
  only (`repro/src.ll -> repro/tgt_fix.ll`): **"Transformation seems to be
  correct!"** (1 correct / 0 incorrect).

(alive-tv binary:
`/mnt/nvme2/jinpli/workspace/home/jinpli/development/alive2/build/alive-tv`.)

## Why it is wrong
The splat reconstructs a "broadcast" word by reusing a possibly-`undef` SSA
value at multiple byte positions; independent undef uses let those bytes
diverge, so the target can produce mixed-byte values that the memset source
(which writes one byte everywhere) provably cannot. Target is strictly more
defined than source — a non-refinement.

## One-line fix
Freeze the non-constant memset value before splatting it
(`if (!isa<Constant>(Val)) Val = Builder.CreateFreeze(Val);`), so all splatted
bytes are guaranteed equal; leave constants untouched to preserve
constant-folding paths. Reference patch:
branch `2026-06-06-alive2-gvn-memset-typed-load`, commit
`[GVN] Freeze non-constant memset value when forwarding to a wider load`.
