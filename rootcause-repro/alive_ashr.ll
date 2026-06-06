target datalayout = "e-p:64:64:64"

; SRC: what the original program computes (gep i16 with the non-exact ashr index)
define ptr @src(ptr %v, i64 %n) {
  %p  = getelementptr i8, ptr %v, i64 %n
  %av = ptrtoaddr ptr %v to i64
  %ap = ptrtoaddr ptr %p to i64
  %d  = sub i64 %ap, %av
  %idx = ashr i64 %d, 1
  %r = getelementptr i16, ptr %v, i64 %idx
  ret ptr %r
}

; TGT: what simplifyGEPInst rewrites it to (returns %p directly)
define ptr @tgt(ptr %v, i64 %n) {
  %p  = getelementptr i8, ptr %v, i64 %n
  ret ptr %p
}
