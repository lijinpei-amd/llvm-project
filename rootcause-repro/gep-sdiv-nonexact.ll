; sdiv analogue: simplifyGEPInst folds
;   gep <i16>, %v, (sdiv (sub addr(%p), addr(%v)), 2) -> %p
; WITHOUT requiring the sdiv to be `exact`. Non-exact sdiv drops the remainder
; of D/2, so for odd D (e.g. D=3): sdiv 3,2 = 1 -> %v+2, but fold returns %v+3.
target datalayout = "e-p:64:64:64"

define ptr @src(ptr %v, i64 %n) {
  %p  = getelementptr i8, ptr %v, i64 %n
  %av = ptrtoaddr ptr %v to i64
  %ap = ptrtoaddr ptr %p to i64
  %d  = sub i64 %ap, %av
  %idx = sdiv i64 %d, 2                 ; NON-exact sdiv: drops remainder
  %r = getelementptr i16, ptr %v, i64 %idx
  ret ptr %r
}
