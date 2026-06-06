# Root Cause: ConstantFolding `FoldBitCast` drops defined bits on big-endian non-integer-ratio bitcast with an undef source lane

## Summary

`FoldBitCast` in `llvm/lib/Analysis/ConstantFolding.cpp` miscompiles a constant
`bitcast <4 x i24> -> <3 x i32>` when a source lane is `undef` and the data layout
is **big-endian**. The undef-element path inserts a `DstBitSize`-wide (32-bit) zero
placeholder for a `SrcBitSize`-wide (24-bit) element. `APInt::insertBits` clears
exactly the width it inserts, so it zeroes `DstBitSize - SrcBitSize = 8` extra bits
that belong to an adjacent, already-loaded, fully-defined source element. The result
is a wrong (too-zeroed) destination lane.

## Repro

`repro/src.ll` (big-endian datalayout — the `E` prefix is essential):

```llvm
target datalayout = "E-p:32:32:32-i1:8:8-i8:8:8-f64:32:64-v64:64:64-v128:128:128"
define <3 x i32> @f() {
  %cast = bitcast <4 x i24><i24 -1, i24 255, i24 undef, i24 undef> to <3 x i32>
  ret <3 x i32> %cast
}
```

Command:

```
opt -passes=instsimplify repro/src.ll -S
```

Buggy output (lane 1 wrong):

```llvm
ret <3 x i32> <i32 -256, i32 0, i32 undef>
```

Correct output (lane 1 = 0x00FF0000 = 16711680):

```llvm
ret <3 x i32> <i32 -256, i32 16711680, i32 undef>
```

## Faulty logic

In the data-buffer path (`while (Result.size() != NumDstElt)` loop, ~line 357):

```cpp
if (isa<UndefValue>(Element)) {
  UndefMask.setBits(BitPosition, BitPosition + SrcBitSize);
  ...
  SrcValue = APInt::getZero(DstBitSize);   // <-- BUG: DstBitSize, not SrcBitSize
}
...
Buffer.insertBits(SrcValue, BitPosition); // clears SrcValue.getBitWidth() bits
```

`insertBits(V, pos)` clears `[pos, pos + V.getBitWidth())` and writes `V` there.
A source element only owns `SrcBitSize` bits, and the non-undef path correctly
inserts a `SrcBitSize`-wide value (`Src->getValue()`). The undef path instead
inserts a `DstBitSize`-wide value, so it clears `DstBitSize - SrcBitSize` *extra*
bits. The two paths are inconsistent.

On big-endian, defined source elements are shifted toward the high end of the
Buffer and remain resident there while later lanes are loaded; the over-wide clear
then lands on top of those still-live defined bits. (On little-endian the Buffer
happens to be empty/zero at the moment the undef lanes are inserted, so the extra
clear hits only zero bits and is harmless — the bug is endian-specific.)

## Experimental evidence (captured with instrumentation on this branch)

Instrumentation added immediately around the undef-element `insertBits`
(prints `SrcBitSize`, `DstBitSize`, `BitPosition`, placeholder width, and the
Buffer as hex before/after).

### Big-endian (`repro/src.ll`) — bug fires

```
[RC] undef elt: SrcBitSize=24 DstBitSize=32 BitPosition=0 SrcValue.width=32 (placeholder is 32-bit, but element is only 24-bit)
[RC]   Buffer BEFORE insertBits = 0xFFFF0000FF000000
[RC]   insertBits will clear [0, 32); element only owns [0, 24) -> 8 neighbor bits clobbered
[RC]   Buffer AFTER  insertBits = 0xFFFF000000000000
```

Reading the hex:

- BEFORE = `0xFFFF0000FF000000`. The byte `FF` at bit range **[24,32)** is the low
  byte of the defined `i24 255` lane (0x0000FF) still resident in the Buffer.
- The placeholder is 32-bit and inserted at BitPosition 0, so `insertBits` clears
  bits **[0,32)** — but the undef element only owns **[0,24)**. Bits **[24,32)** =
  the live `FF` belong to the neighbor.
- AFTER = `0xFFFF000000000000`. The `FF` at [24,32) has been wiped to `00`.

That single wiped byte is the value that should have surfaced in destination lane 1
(`0x00FF0000` = 16711680); after the clobber the lane folds to `0`.

### Little-endian (`repro/min.ll`, default layout) — bug latent, output happens to be valid

```
[RC] undef elt: SrcBitSize=24 DstBitSize=32 BitPosition=16 ... (placeholder is 32-bit, but element is only 24-bit)
[RC]   Buffer BEFORE insertBits = 0x0
[RC]   Buffer AFTER  insertBits = 0x0
```

Buffer is `0x0` before the undef insertion, so the 8 extra cleared bits are already
zero — no defined data is lost. Confirms the miscompile is big-endian-specific and
driven entirely by whether defined bits are resident in the clobbered range.

## Why this is wrong

`insertBits` clears the full inserted width, so a `DstBitSize`-wide placeholder for
a `SrcBitSize`-wide undef element clears `DstBitSize - SrcBitSize` bits that belong
to an adjacent *defined* element — i.e. it drops bits that are not undef. Folding
must preserve every defined bit.

## One-line fix

```cpp
SrcValue = APInt::getZero(SrcBitSize);   // was getZero(DstBitSize)
```

Make the undef placeholder exactly `SrcBitSize` wide, matching the non-undef path
so `insertBits` only touches the element's own bits.

Reference fix: branch `2026-06-06-alive2-instsimplify-bitcast-constexpr-undef`,
commit `[ConstantFolding] Fix dropped bits in non-integer-ratio bitcast with undef lane`.
