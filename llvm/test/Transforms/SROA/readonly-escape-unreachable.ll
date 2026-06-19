; RUN: opt < %s -passes=sroa -S | FileCheck %s

define void @unreachable_store_self_before_load_with_readonly_escape(i64 %idx) {
; CHECK-LABEL: define void @unreachable_store_self_before_load_with_readonly_escape(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A:%.*]] = alloca [2 x i32], align 4
; CHECK-NEXT:    ret void
; CHECK:       dead.store_load:
; CHECK-NEXT:    store i32 poison, ptr [[A]], align 4
; CHECK-NEXT:    br label [[DEAD_STORE_LOAD:%.*]]
; CHECK:       dead.readonly:
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr [2 x i32], ptr [[A]], i64 0, i64 [[IDX:%.*]]
; CHECK-NEXT:    [[V:%.*]] = load i32, ptr [[GEP]], align 4
; CHECK-NEXT:    br label [[DEAD_READONLY:%.*]]
;
entry:
  %a = alloca [2 x i32], align 4
  ret void

dead.store_load:
  store i32 %l, ptr %a, align 4
  %l = load i32, ptr %a, align 4
  br label %dead.store_load

dead.readonly:
  %gep = getelementptr [2 x i32], ptr %a, i64 0, i64 %idx
  %v = load i32, ptr %gep, align 4
  br label %dead.readonly
}
