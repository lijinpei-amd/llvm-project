# Alive2 "Value mismatch": InstSimplifyPass / @minnum_float_p0_snan

## Finding
InstSimplify constant-folds `llvm.minnum.f32(+0.0, sNaN 0x7fa00000)` to the
quieted qNaN `+nan(0x200000)` (`0x7fe00000`). Alive2 reports:

    Source: float %min = +0.0
    Target value: 0x7fe00000 (QNaN)
    Transformation doesn't verify! (unsound) -- ERROR: Value mismatch

Test: llvm/test/Transforms/InstSimplify/ConstProp/min-max.ll : @minnum_float_p0_snan

## Verdict: NOT a miscompile. Alive2 sNaN-model artifact. No LLVM patch.

## Reasoning (per LangRef on the same checkout, commit 89f4b84d8b2c)

LangRef `'llvm.minnum.*'` Semantics (llvm/docs/LangRef.rst ~line 18191), as
clarified by commit 6bae2a98b4c7 ("[LangRef] Clarify specification for float
min/max operations", PR #172012, present in this checkout):

    If an operand is a signaling NaN, then the intrinsic will
    non-deterministically either:
     * Return a NaN.
     * Or treat the signaling NaN as a quiet NaN.

So `minnum(+0.0, sNaN)` has a NON-DETERMINISTIC result set:
  - "Return a NaN": per the floatnan section (LangRef ~4125), a returned NaN has
    quiet bit set; payload may be all-zero (preferred) OR the quieted input
    payload ("Quieting NaN propagation"). 0x7fe00000 (quieted sNaN payload) is
    one of these allowed NaNs.
  - "Treat sNaN as qNaN": then minnum(+0.0, qNaN) = the number = +0.0.

Therefore the legal result set is { +0.0, qNaN (incl. 0x7fe00000) }.
The fold deterministically picks qNaN 0x7fe00000, which is a member of that set,
so target behavior is a subset of source behavior -> VALID REFINEMENT.

LLVM's APFloat::minnum (llvm/include/llvm/ADT/APFloat.h:1676) implements the
IEEE-754-2008 "if sNaN -> qNaN" branch (A.makeQuiet()/B.makeQuiet()), which is
exactly the "Return a NaN" option. ConstantFolding.cpp:3528 calls it. Correct.

## Why Alive2 disagrees (the artifact)

Alive2's fmin/fmax model (alive2/ir/instr.cpp, fmin_fmax, ~line 655):

    return expr::mkIf(a.isNaN(), b,
                      expr::mkIf(b.isNaN(), a,            // <-- any NaN (incl sNaN) -> other operand
                                 expr::mkIf(a.foeq(b), ...)));

It models minnum as ALWAYS returning the other operand when one operand is any
NaN -- i.e. it only encodes the "treat sNaN as quiet NaN" branch and OMITS the
LangRef-permitted "Return a NaN" branch for signaling NaN inputs. Its source
model is thus too strict: it forces +0.0 and rejects the (legal) qNaN refinement.

This is the inverse of the usual Alive2 situation: Alive2's source semantics are
narrower than LangRef, so a correct LLVM refinement is flagged as a mismatch.

## Reproduction (fresh origin/main, build at $AW/build)

- opt -passes=instsimplify min.ll -S            => ret float +nan(0x200000)
- Upstream lit test min-max.ll                  => FileCheck PASS (expected behavior)
- LangRef clarification commit 6bae2a98b4c7     => present (ancestor of HEAD)

### alive-tv (build/alive-tv, the existing verification asset)

BEFORE (current): src = fmin(+0.0, sNaN), tgt = ret 0x7fe00000
    Transformation doesn't verify!  ERROR: Value mismatch
    Source: +0.0 ; Target: 0x7fe00000 (QNaN)

AFTER: no LLVM change. The mismatch is a property of Alive2's fmin model, not of
LLVM. Fixing it would require teaching Alive2's fmin_fmax to non-deterministically
return a NaN when an input is a signaling NaN (out of scope for an LLVM patch).

## Files of interest
- llvm/include/llvm/ADT/APFloat.h:1676  (APFloat::minnum -> makeQuiet on sNaN)
- llvm/lib/Analysis/ConstantFolding.cpp:3528 (fold uses minnum())
- llvm/docs/LangRef.rst:18191 (sNaN non-deterministic semantics)
- llvm/docs/LangRef.rst:4125 (floatnan: returned-NaN payload rules)
- llvm/test/Transforms/InstSimplify/ConstProp/min-max.ll:98 (the test)
- alive2/ir/instr.cpp:655 (fmin_fmax model -- the artifact)
