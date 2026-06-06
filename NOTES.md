# Alive2 "Value mismatch" — InstSimplifyPass @test_undef_aggregate

Date: 2026-06-06
Upstream base: origin/main @ 89f4b84d8b2c
Test: llvm/test/Transforms/InstSimplify/ConstProp/loads.ll  (`@test_undef_aggregate`)

## Finding

Source:
```
@g_undef = constant { i128 } undef
define ptr @test_undef_aggregate() {
  %v = load ptr, ptr @g_undef
  ret ptr %v
}
```
Target (InstSimplify, via ConstantFoldLoadFromConst):
```
  ret ptr undef
```

Alive2 reports `Value mismatch (unsound)`:
- Source value: `pointer(non-local, block_id=0, offset=3) / Address=#x03  [based on undef]`
- Target value: `pointer(non-local, block_id=2, offset=0) / Address=#x01`

## Reproduced

Yes. Confirmed two ways:
1. Pre-existing alive-tv (alive2/build/alive-tv) on hand-written src/tgt → "Transformation doesn't verify! ERROR: Value mismatch".
2. Freshly built upstream opt @89f4b84d8b2c:
   `opt -passes=instsimplify min.ll -S` → `ret ptr undef`
   `opt -passes=instcombine min.ll -S` → `ret ptr undef`
   The transform is current, stable upstream behavior (the `ret ptr undef`
   CHECK line dates back years; not fixed on main).

## Verdict: ALIVE2 MODELING ARTIFACT — NOT a real miscompile. No LLVM patch.

The transform is canonical and correct: loading any type from undef-initialized
constant memory yields `undef` of the loaded type. `ptr undef` denotes a fully
unconstrained pointer, which is exactly what loading undef bytes as a pointer
should denote. In LangRef semantics the two are equivalent.

## Root cause (Alive2 internals)

The asymmetry is in how Alive2 models the two pointer values:

1. SOURCE — load `ptr` from integer-typed undef bytes.
   The stored `{i128} undef` writes DATA_INT undef bytes. When loaded as a
   pointer, `bytesToValue` (ir/memory.cpp, `toType.isPtrType()` branch, ~L737)
   takes the "not all pointer bytes" path and builds an *auto-cast* pointer:
       Pointer auto_cast(m, bid=0, offset = int_undef_value & mask);
   i.e. an integer reinterpreted as a pointer with the canonical "no provenance"
   block (bid 0, the null block) and an ARBITRARY offset. With undef input the
   offset is arbitrary, so the source can produce `pointer(bid=0, offset=3)`,
   reaching address #x03 — an "any-ADDRESS" pointer.

2. TARGET — `ret ptr undef` uses `Pointer::mkUndef` (ir/pointer.cpp ~L139),
   which yields an arbitrary well-formed LOGICAL pointer: any *block* + offset.
   A well-formed nonlocal logical pointer cannot use the null block (bid 0) when
   it is non-dereferenceable (the `skip_null` / `bid != 0` constraints in
   ir/memory.cpp and ir/pointer.cpp). So mkUndef is an "any-BLOCK" pointer and
   cannot equal `pointer(bid=0, offset=3)`.

Refinement for nonlocal pointers requires exact equality (`*this == other`,
ir/pointer.cpp `Pointer::refined`, ~L832). The logical->physical bid==0 escape
hatch (~L843) does not apply because the target undef is itself logical. Hence
the source's "any-address via null-block auto-cast" value set is a STRICT
SUPERSET of the target's "any well-formed logical pointer" value set, and
`forall src exists tgt` fails: the source can reach address #x03 that no
logical `ptr undef` can reach.

In short: Alive2 models "load undef bytes as a pointer" as an any-*address*
pointer (auto-cast on null block with arbitrary offset), but models `ptr undef`
as an any-*block* logical pointer. The former is strictly more permissive, so
the (correct) folding to `undef` looks unsound to the verifier.

This is the same class of "integer-to-pointer auto-cast vs. logical undef
pointer" provenance mismatch; it is a known limitation of the memory/provenance
model, not a bug in InstSimplify/InstCombine.

## alive-tv before/after

No LLVM change is warranted, so there is no "after". The transform is correct
under LLVM semantics; only Alive2's pointer-undef vs. auto-cast modeling makes it
appear unsound. (For comparison, the sibling `@test_poison_aggregate` folds to
`ret ptr poison` and verifies fine, since poison has no provenance subtleties.)

## Files
- repro/min.ll, repro/src2.ll, repro/tgt2.ll (constant-init form; reproduces the
  exact counterexample)
- repro/src.ll, repro/tgt.ll (explicit-store form; trivially correct because the
  store makes the source always-UB, which is why the bug only shows with the
  constant initializer path)
