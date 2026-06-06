# Root cause: SLP miscompile — shared `zext i16 65535` demoted to i16 flips a signed `icmp slt`

## 1. Summary
SLP's minimum-bitwidth analysis (`BoUpSLP::collectValuesToDemote` → `IsPotentiallyTruncated`)
takes a zero-extend fast path that demotes `xor5 = zext i16 65535 to i32` (= 0x0000FFFF) to
**i16** because its leading bits are zero — but the same SSA value also feeds a **signed**
`icmp slt`; at i16 the bit pattern 0xFFFF is **-1**, so `0 slt 65535` (true) becomes
`0 slt -1` (false), and `conv13 = zext i1 ...` collapses from **1 to 0**.

## 2. Minimal reproducer + exact command
File: `llvm/test/Transforms/SLPVectorizer/X86/minbw-node-used-twice.ll`
(identical body to `$AW/repro/full.ll` / `src.ll`).

```llvm
define i8 @test() {
entry:
  %conv4.i.i = zext i16 0 to i32
  %conv7.i.i = sext i16 0 to i32
  %cmp8.i.i = icmp slt i32 %conv7.i.i, %conv4.i.i
  %conv9.i.i = zext i1 %cmp8.i.i to i32
  %or10.i.i = or i32 %conv9.i.i, %conv4.i.i
  %cmp11.i.i = icmp eq i32 %or10.i.i, %conv4.i.i
  %sub.i.i79.peel.i = sub i16 0, 1                          ; = 65535
  %xor5.i81.peel.i = zext i16 %sub.i.i79.peel.i to i32      ; = 0x0000FFFF, SHARED value
  %conv7.i84.peel.i = sext i16 0 to i32                     ; = 0
  %cmp8.i85.peel.i = icmp slt i32 %conv7.i84.peel.i, %xor5.i81.peel.i  ; SIGNED user: 0 slt 65535 = true
  %conv9.i86.peel.i = zext i1 %cmp8.i85.peel.i to i32
  %or10.i87.peel.i = or i32 %conv9.i86.peel.i, %xor5.i81.peel.i
  %cmp11.i88.peel.i = icmp eq i32 %or10.i87.peel.i, %xor5.i81.peel.i   ; EQ user (drives demotion)
  %conv13.i89.peel.i = zext i1 %cmp8.i85.peel.i to i8       ; result: should be 1
  ret i8 %conv13.i89.peel.i
}
```

Command:
```
bin/opt -S -passes=slp-vectorizer -mtriple=x86_64-unknown-linux minbw-node-used-twice.ll
```

## 3. Root cause — the precise faulty logic
`llvm/lib/Transforms/Vectorize/SLPVectorizer.cpp`, lambda `IsPotentiallyTruncated`
inside `BoUpSLP::collectValuesToDemote`:

```cpp
bool IsSignedVal = !isKnownNonNegative(V, SimplifyQuery(*DL));
if ((!IsSignedNode || IsSignedVal) && OrigBitWidth > BitWidth) {
  APInt Mask = APInt::getBitsSetFrom(OrigBitWidth, BitWidth);
  if (MaskedValueIsZero(V, Mask, SimplifyQuery(*DL)))
    return true;            // <-- ZEXT FAST PATH: "V fits in BitWidth bits"
}
```

The fast path only asks "are the bits above `BitWidth` zero?" (an **unsigned** fit test).
For `xor5 = 0x0000FFFF` with `BitWidth = 16`, bits [31:16] are zero, so it returns `true`
("safe to truncate to i16"). It **never** checks whether `V` is consumed by a *signed*
comparison vectorized as a different in-tree node. Truncating to i16 drops the leading bits
**without preserving a sign bit**; the signed `icmp slt` then re-reads 0xFFFF at i16 as **-1**.

The demotion is driven by the equality node (`cmp11` / `cmp8.i.i` on `<2 x i32>`), which
*is* legal to narrow, but `xor5` is **shared** with the signed `slt` node, which is not.
(The older d1a722507621 "keep original bitwidth" guard was order-dependent and, after the
graph-as-tree / Sub-as-copyable-base reorderings, no longer fires for this tree.)

## 4. EXPERIMENTAL EVIDENCE (captured, not inferred)
Built on `origin/main` (89f4b84d8b2c, no fix) with added `errs()` instrumentation at the
fast path. Decisive lines from stderr (`bin/opt ... 2>&1 >/dev/null`):

```
[ROOTCAUSE] zext fast path DEMOTES value used by signed icmp
[ROOTCAUSE]   demoted value :   %xor5.i81.peel.i = zext i16 %sub.i.i79.peel.i to i32
[ROOTCAUSE]   OrigBitWidth=32  chosen BitWidth=16
[ROOTCAUSE]   in-tree signed icmp user :   %cmp8.i85.peel.i = icmp slt i32 %conv7.i84.peel.i, %xor5.i81.peel.i
[ROOTCAUSE]   sign bit set at i16 (UNSAFE for signed cmp)? YES
[ROOTCAUSE]   --> returning true: value WILL be truncated to i16, signed icmp result will flip
```

Resulting WRONG IR on stdout:
```llvm
define i8 @test() {
entry:
  %0 = icmp eq <2 x i16> <i16 -1, i16 0>, <i16 -1, i16 0>
  %conv13.i89.peel.i = zext i1 false to i8
  ret i8 %conv13.i89.peel.i
}
```

How each printed value proves the mechanism:
- `demoted value : %xor5.i81.peel.i = zext i16 ... to i32` — the exact shared SSA value
  (0x0000FFFF) entering the fast path.
- `chosen BitWidth=16` with `OrigBitWidth=32` — the analysis decides i32 → **i16**.
- `in-tree signed icmp user : ... icmp slt ... %xor5...` — proof the *same value* also
  feeds a SIGNED, in-tree (vectorized) comparison, the operand that must keep its width.
- `sign bit set at i16 ... ? YES` — at the new width bit 15 is set, i.e. 0xFFFF reads as
  **-1**; this is the precise condition under which the signed compare flips.
- `--> returning true` — the fast path nonetheless declares the value demotable.
- Output `icmp eq <2 x i16> <i16 -1, ...>` confirms the literal 65535 is now stored as the
  i16 constant **-1**, and `zext i1 false` confirms `cmp8` evaluated `0 slt -1 = false`,
  giving `conv13 = 0` instead of 1.

(The dump fires repeatedly for several candidate BitWidths during the search; the
`BitWidth=16 / YES` block is the one matching the final demotion seen in the output IR.)

## 5. Why it is wrong (semantics)
`0 slt 65535` is `true` over the original i32 values. Demoting the shared operand to i16
reinterprets 0xFFFF as the signed value -1, so the optimized program computes `0 slt -1 =
false`. The unsigned equality node that justified the demotion does not authorize narrowing
a value also consumed by a signed comparison; demotion is unsound for that shared operand.

## 6. One-line fix
On branch **`2026-06-06-alive2-slp-conv13`** (commit 93ab03beaa15): in
`IsPotentiallyTruncated`, when `V` feeds an in-tree signed icmp and does not fit *signed* in
`BitWidth` (`MaskedValueIsZero` over bits `[OrigBitWidth-1 : BitWidth-1]` is false), skip the
zext fast path and keep an extra sign bit, forcing a safe width — output becomes
`icmp eq <2 x i32>` and `zext i1 true` (conv13 = 1). Verified sound with alive-tv.
