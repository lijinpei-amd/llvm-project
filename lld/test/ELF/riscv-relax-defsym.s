# REQUIRES: riscv
## A linker-script-defined symbol (--defsym or SECTIONS `sym = expr`) that
## resolves to an input section plus a non-zero offset must not be treated as a
## relaxation anchor. Such symbols are recomputed by assignSymbol() on every
## relaxation pass; anchoring them double-counts the relaxation delta and used to
## cause a spurious "assignment to symbol foo does not converge" error.

# RUN: rm -rf %t && split-file %s %t && cd %t
# RUN: llvm-mc -filetype=obj -triple=riscv64 -mattr=+relax a.s -o a.o

## --defsym with a non-zero offset relative to a symbol in a relaxable section.
# RUN: ld.lld a.o --defsym=foo=_start+8 -o defsym
# RUN: llvm-objdump -td --no-show-raw-insn -M no-aliases defsym | FileCheck %s

## The same expression via a linker script symbol assignment.
# RUN: ld.lld -T lds a.o -o script
# RUN: llvm-objdump -td --no-show-raw-insn -M no-aliases script | FileCheck %s

# CHECK:      [[#%x,START:]] g       .text {{0*}}0000000000000000 _start
# CHECK-NEXT: [[#%x,START+8]] g       .text {{0*}}0000000000000000 foo
# CHECK:      <_start>:
# CHECK-NEXT:   jal ra, {{.*}} <foo>

#--- a.s
.global _start
_start:
  call foo

#--- lds
foo = _start + 8;
