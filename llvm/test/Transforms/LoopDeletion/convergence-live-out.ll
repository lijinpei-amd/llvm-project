; RUN: opt -S -passes=loop-deletion < %s | FileCheck %s

declare void @f() convergent
declare token @llvm.experimental.convergence.anchor()

define i32 @extended_loop(i32 %n) {
; CHECK-LABEL: define i32 @extended_loop(
; CHECK:       l3:
; CHECK:         [[TOK:%.*]] = call token @llvm.experimental.convergence.anchor()
; CHECK:         br i1 {{%.*}}, label %exit, label %l3
; CHECK:       exit:
; CHECK:         call void @f() [ "convergencectrl"(token [[TOK]]) ]
; CHECK-NEXT:    ret i32 0
;
entry:
  br label %l3, !llvm.loop !1

l3:
  %x.0 = phi i32 [ 0, %entry ], [ %inc, %l3 ]
  %tok.loop = call token @llvm.experimental.convergence.anchor()
  %inc = add nsw i32 %x.0, 1
  %exitcond = icmp eq i32 %inc, %n
  br i1 %exitcond, label %exit, label %l3, !llvm.loop !1

exit:
  call void @f() [ "convergencectrl"(token %tok.loop) ]
  ret i32 0
}

!1 = !{!1, !{!"llvm.loop.unroll.count", i32 2}}
