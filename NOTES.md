# Alive2 "Value mismatch": EarlyCSEPass / @smin_commute

Date: 2026-06-06
LLVM worktree base: origin/main @ 89f4b84d8b2c
Investigator: automated rigorous analysis

## TL;DR verdict

The transform EarlyCSE performs is **CSE of two structurally-equal `smin` selects**:

```
%cmp1 = icmp slt i8 %a, %b
%cmp2 = icmp slt i8 %b, %a
%m1   = select i1 %cmp1, i8 %a, i8 %b   ; min(a,b)
%m2   = select i1 %cmp2, i8 %b, i8 %a   ; min(a,b)
%r    = mul i8 %m1, %m2
   =>
%cmp1 = icmp slt i8 %a, %b
%m1   = select i1 %cmp1, i8 %a, i8 %b
%r    = mul i8 %m1, %m1                  ; %m2 CSE'd into %m1
```

This is **correct for all defined inputs** (both `%m1` and `%m2` compute `min(a,b)`,
including the `a == b` tie). But Alive2 reports a **real refinement violation under
`undef`**, not a false positive.

The original preliminary hypothesis ("Alive2 false positive; spurious [based on undef]
tags even though %a,%b are plain i8 args") is **REFUTED**. Function arguments without
`noundef` may legitimately be `undef`, and the `[based on undef]` tags are accurate.

Bottom line:
- NOT an Alive2 modeling bug / false positive.
- NOT a newly-discovered exploitable EarlyCSE miscompile.
- It is the well-known, long-accepted tension between value-numbering CSE and LLVM's
  `undef` semantics (each *use* of `undef` may independently take any value). EarlyCSE
  intentionally numbers commuted min/max selects as equal; that is unsound only in the
  presence of `undef`, which is exactly the motivation behind `freeze`/poison migration.

=> No LLVM patch. This NOTES.md is the deliverable.

## Reproduction (both stock alive-tv and freshly-built upstream opt)

`min.ll`:
```
define i8 @smin_commute(i8 %a, i8 %b) {
  %cmp1 = icmp slt i8 %a, %b
  %cmp2 = icmp slt i8 %b, %a
  %m1 = select i1 %cmp1, i8 %a, i8 %b
  %m2 = select i1 %cmp2, i8 %b, i8 %a
  %r = mul i8 %m1, %m2
  ret i8 %r
}
```

Freshly built `opt` (origin/main @ 89f4b84d8b2c) reproduces the exact transform:
```
opt -passes=early-cse -earlycse-debug-hash min.ll -S
# => %m2 removed, %r = mul i8 %m1, %m1, %cmp2 dropped as dead
```

`alive-tv min.ll <opt-output>`:
```
ERROR: Value mismatch
Example:  %a = #x80 (-128)   %b = undef
Source:   ... %r = #x00  [based on undef]
Target:   ... %r = #x08
```

## Discriminating experiments (the proof)

| Variant                              | alive-tv result            |
|--------------------------------------|----------------------------|
| bare `i8 %a, i8 %b`                  | **doesn't verify** (mismatch, witness `%b = undef`) |
| `i8 noundef %a, i8 noundef %b`       | **correct**                |
| `freeze %b` (a left undef)           | **correct**                |
| `freeze %a` only (b still undef)     | **doesn't verify**         |

Interpretation:
- Removing `undef` from the inputs (via `noundef`) makes the transform verify => the
  mismatch is *entirely* an `undef` artifact, not an arithmetic flaw in min/min.
- Freezing the specific witness operand `%b` (so its two select reads are forced to be
  one fixed value) fixes it; freezing the other operand `%a` does not. This pinpoints
  the cause to *two independent `undef` reads of `%b` being collapsed into one*.

## Why it is genuinely a refinement violation under `undef` semantics

LangRef: an `undef` value "may take any one of the allowed values for that type" and
**each use may observe a different value**. With `%b = undef`:

Source has TWO separate select instructions, each independently reading `%b`:
- `%m1 = select(slt(a,b), a, b)` reads `%b` once (call its realization `b1`)
- `%m2 = select(slt(b,a), b, a)` reads `%b` again (independent realization `b2`)

So source `%r = min(a, b1) * min(b2, a)` where `b1` and `b2` are *independent*. The set
of values `%r` may take is therefore larger / different from the target's.

Target has ONE select; `%r = m1 * m1` forces the two factors to use the SAME realization
of the undef-derived value. This removes a degree of freedom present in the source.

Refinement direction for CSE (target must refine source: for fixed inputs, every value
the target may yield must be a value the source may yield). Alive2 found inputs
(`%a=-128`, `%b=undef`) and a target output (the `m1*m1` value, shown `0x08` in the SMT
model) that the source's value-set does not contain for the *same* assignment. Hence the
target is NOT a refinement of the source -> unsound under undef.

The witness `%a = -128 = 0x80` is the i8 minimum: `slt(x, -128)` is false for all `x`, so
`%cmp2` is forced to 0 and `%m2 = a = -128`, while `%cmp1 = slt(-128, undef)` can be made
true so `%m1 = a`. This maximally separates the behaviors of the two selects on undef and
lets the solver exhibit a source value (`0x00`) unreachable by the squared target.

(The exact displayed numbers `0x00` vs `0x08` come from a particular SMT model and have
residual undef freedom in the model; they are illustrative, not load-bearing. The
load-bearing facts are the four-row table above.)

## Root cause in EarlyCSE source

`llvm/lib/Transforms/Scalar/EarlyCSE.cpp`:

- `matchSelectWithOptionalNotCond` (~line 188-208) recognizes both selects as `SPF_SMIN`
  by matching `icmp slt` over `{A,B}` in either operand order (it explicitly checks the
  commuted comparand form and swaps the predicate).
- `getHashValueImpl` (~lines 261-266): for `SPF_SMIN/SMAX/UMIN/UMAX` it sorts `{A,B}` and
  hashes `hash_combine(opcode, SPF, A, B)` -> `%m1` and `%m2` hash identically.
- `isEqualImpl` (~lines 415-418): two `SPF_SMIN` selects are equal iff their operand
  *sets* match (`(LHSA==RHSA && LHSB==RHSB) || (LHSA==RHSB && LHSB==RHSA)`), regardless of
  which exact compare/operand arrangement -> `%m1` and `%m2` compare equal, so `%m2` is
  replaced by `%m1`.

This is the intended min/max-commutation CSE (added precisely so commuted min/max get
value-numbered together). It is correct for defined values and is the same behavior GVN
and other value-numbering passes exhibit. The "unsoundness" only manifests through
`undef`, which is the accepted state of the world for these passes.

## Conclusion / recommendation

- Reproduced: YES (stock alive-tv and freshly built upstream opt, identical witness).
- Verdict: REAL undef-related refinement violation that is *intended/accepted* pass
  behavior; NOT an Alive2 false positive and NOT a fixable miscompile bug. Equivalent to
  the broad family of "CSE is unsound w.r.t. undef" findings.
- No code change. If desired, this could be added to an Alive2 known-undef-CSE allowlist,
  but it should not block EarlyCSE.
