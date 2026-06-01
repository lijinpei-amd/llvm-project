; RUN: opt -S -verify-each -passes=hotcoldsplit -hotcoldsplit-threshold=0 < %s | FileCheck %s

; Reproducer for https://github.com/llvm/llvm-project/issues/192014
;
; A cold region containing a call to @llvm.experimental.deoptimize can be
; outlined. The intrinsic must be immediately followed by a return of its value
; and its return type must match the enclosing function, so when the block is
; moved into the outlined function the intrinsic is re-created with the outlined
; function's return type (mirroring the inliner). The deoptimizing path
; terminates the outlined function rather than flowing back to the caller.

; A single normal exit (the outlined function returns void) alongside a deopt
; exit: the deopt call is rewritten to the void intrinsic.
define i64 @combined_bridge() {
; CHECK-LABEL: define i64 @combined_bridge()
; CHECK:       codeRepl:
; CHECK-NEXT:    call void @combined_bridge.cold.1()
; CHECK-NEXT:    br label %guarded1.i.ret
; CHECK:       guarded1.i.ret:
; CHECK-NEXT:    ret i64 0
entry:
  br i1 false, label %loop.i, label %failed.i, !prof !0

loop.i:                                           ; preds = %entry
  br i1 false, label %guarded1.i, label %deopt2.i

deopt2.i:                                         ; preds = %loop.i
  %0 = call i64 (...) @llvm.experimental.deoptimize.i64() [ "deopt"() ]
  ret i64 %0

guarded1.i:                                       ; preds = %loop.i
  %iv.next.i147 = add i32 0, 0
  %loop.cond.i148 = icmp ult i32 0, 0
  ret i64 0

failed.i:                                         ; preds = %entry
  ret i64 0
}

; Two normal exits (the outlined function returns an i1 selector) alongside a
; deopt exit: the deopt call is rewritten to the i1 intrinsic and the deopt
; operand bundle (including an outlined-function argument) is preserved.
define i64 @multi_exit(i1 %c, i1 %c2, i64 %x) {
; CHECK-LABEL: define i64 @multi_exit(
; CHECK:       codeRepl:
; CHECK-NEXT:    [[SEL:%.*]] = call i1 @multi_exit.cold.1(
; CHECK-NEXT:    br i1 [[SEL]], label %ret1.ret, label %ret2.ret
entry:
  br i1 false, label %cold, label %hot, !prof !0

cold:                                             ; preds = %entry
  br i1 %c, label %deopt, label %mid

deopt:                                            ; preds = %cold
  %d = call i64 (...) @llvm.experimental.deoptimize.i64() [ "deopt"(i64 %x) ]
  ret i64 %d

mid:                                              ; preds = %cold
  br i1 %c2, label %ret1, label %ret2

ret1:                                             ; preds = %mid
  ret i64 7

ret2:                                             ; preds = %mid
  ret i64 9

hot:                                              ; preds = %entry
  ret i64 0
}

; The outlined functions are appended after the original functions.

; combined_bridge.cold.1 returns void; the deopt call is rewritten to match.
; CHECK-LABEL: define internal void @combined_bridge.cold.1()
; CHECK:       deopt2.i:
; CHECK-NEXT:    call void (...) @llvm.experimental.deoptimize.isVoid() [ "deopt"() ]
; CHECK-NEXT:    ret void

; multi_exit.cold.1 returns an i1 selector; the deopt call is rewritten to the
; i1 intrinsic, returning its value (this path deoptimizes and never reaches the
; caller's selector switch).
; CHECK-LABEL: define internal i1 @multi_exit.cold.1(
; CHECK:       deopt:
; CHECK-NEXT:    [[D:%.*]] = call i1 (...) @llvm.experimental.deoptimize.i1() [ "deopt"(i64 %x) ]
; CHECK-NEXT:    ret i1 [[D]]

declare i64 @llvm.experimental.deoptimize.i64(...)

!0 = !{!"branch_weights", i32 1, i32 1000}
