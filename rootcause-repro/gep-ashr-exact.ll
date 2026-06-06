; Repro: simplifyGEPInst folds
;   gep <i16>, %v, (ashr (sub addr(%p), addr(%v)), 1)  -> %p
; WITHOUT requiring the ashr to be `exact`.
;
; %p is derived from %v (same underlying object) via a *runtime* byte offset
; %n so the sub/ashr chain is NOT constant-folded and the buggy pattern fires.
; The miscompile manifests for any odd %n (e.g. %n = 3, D = 3): the non-exact
; ashr drops the low bit, so gep i16 %v,(3>>1=1) = %v+2, but the fold returns
; %p = %v+3.
target datalayout = "e-p:64:64:64"

define ptr @src(ptr %v, i64 %n) {
  %p  = getelementptr i8, ptr %v, i64 %n   ; %p = %v + %n, same underlying object
  %av = ptrtoaddr ptr %v to i64
  %ap = ptrtoaddr ptr %p to i64
  %d  = sub i64 %ap, %av                    ; D = %n
  %idx = ashr exact i64 %d, 1                      ; NON-exact ashr: drops low bit of D
  %r = getelementptr i16, ptr %v, i64 %idx
  ret ptr %r
}
