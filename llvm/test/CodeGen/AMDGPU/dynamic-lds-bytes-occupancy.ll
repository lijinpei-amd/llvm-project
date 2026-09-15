; Occupancy is estimated from the statically allocated LDS. A kernel that
; requests its LDS dynamically at dispatch declares zero there, so the estimate
; has to be told about it. "amdgpu-dynamic-lds-bytes" declares the dynamic
; allocation as a "min[,max]" byte range, and -amdgpu-dynamic-lds-bytes overrides
; the attribute for every kernel in the module. Omitting max defaults it to min.
;
; Since more LDS per workgroup means fewer workgroups per CU, min bounds the
; maximum occupancy -- which is what "; Occupancy:" below reports -- and max
; bounds the minimum occupancy.
;
; gfx942 has 64KiB of LDS, so 32KiB per workgroup allows two workgroups per CU.

; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx942 < %s \
; RUN:   | FileCheck -check-prefix=DEFAULT %s
; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx942 \
; RUN:     -amdgpu-dynamic-lds-bytes=32768 < %s \
; RUN:   | FileCheck -check-prefix=CLI %s
; RUN: llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx942 \
; RUN:     -amdgpu-dynamic-lds-bytes=0,32768 < %s \
; RUN:   | FileCheck -check-prefix=CLI-RANGE %s

; No dynamic LDS declared: the estimate assumes LDS is free.
; DEFAULT-LABEL: {{^}}no_dynamic_lds:
; DEFAULT: ; LDSByteSize: 0 bytes/workgroup
; DEFAULT: ; Occupancy: 8
; CLI-LABEL: {{^}}no_dynamic_lds:
; CLI: ; Occupancy: 2
; CLI-RANGE-LABEL: {{^}}no_dynamic_lds:
; CLI-RANGE: ; Occupancy: 8
define amdgpu_kernel void @no_dynamic_lds(ptr addrspace(1) %out) #0 {
  store i32 0, ptr addrspace(1) %out
  ret void
}

; The attribute lowers the estimate without allocating anything:
; group_segment_fixed_size (LDSByteSize) stays at 0.
; DEFAULT-LABEL: {{^}}dynamic_lds_attr:
; DEFAULT: ; LDSByteSize: 0 bytes/workgroup
; DEFAULT: ; Occupancy: 2
; The command line option wins over the attribute, in both directions.
; CLI-LABEL: {{^}}dynamic_lds_attr:
; CLI: ; Occupancy: 2
; CLI-RANGE-LABEL: {{^}}dynamic_lds_attr:
; CLI-RANGE: ; Occupancy: 8
define amdgpu_kernel void @dynamic_lds_attr(ptr addrspace(1) %out) #1 {
  store i32 0, ptr addrspace(1) %out
  ret void
}

; A "min,max" attribute: the maximum achievable occupancy follows from the
; minimum allocation, so a minimum of 0 leaves the estimate alone.
; DEFAULT-LABEL: {{^}}dynamic_lds_attr_range:
; DEFAULT: ; Occupancy: 8
; CLI-LABEL: {{^}}dynamic_lds_attr_range:
; CLI: ; Occupancy: 2
; CLI-RANGE-LABEL: {{^}}dynamic_lds_attr_range:
; CLI-RANGE: ; Occupancy: 8
define amdgpu_kernel void @dynamic_lds_attr_range(ptr addrspace(1) %out) #2 {
  store i32 0, ptr addrspace(1) %out
  ret void
}

; The 32KiB minimum caps the reported occupancy at 2 waves even though the
; kernel may go on to request up to 48KiB.
; DEFAULT-LABEL: {{^}}dynamic_lds_attr_range_min:
; DEFAULT: ; Occupancy: 2
; CLI-LABEL: {{^}}dynamic_lds_attr_range_min:
; CLI: ; Occupancy: 2
; CLI-RANGE-LABEL: {{^}}dynamic_lds_attr_range_min:
; CLI-RANGE: ; Occupancy: 8
define amdgpu_kernel void @dynamic_lds_attr_range_min(ptr addrspace(1) %out) #3 {
  store i32 0, ptr addrspace(1) %out
  ret void
}

; The dynamic request is added to the statically allocated LDS: 32KiB of
; @lds plus 16KiB dynamic leaves room for a single workgroup. The static
; allocation itself is untouched, so LDSByteSize stays at 32768.
; DEFAULT-LABEL: {{^}}static_and_dynamic_lds:
; DEFAULT: ; LDSByteSize: 32768 bytes/workgroup
; DEFAULT: ; Occupancy: 1
; CLI-LABEL: {{^}}static_and_dynamic_lds:
; CLI: ; LDSByteSize: 32768 bytes/workgroup
; CLI: ; Occupancy: 1
; Overridden to a 0 minimum, the 32KiB of static LDS alone allows two.
; CLI-RANGE-LABEL: {{^}}static_and_dynamic_lds:
; CLI-RANGE: ; LDSByteSize: 32768 bytes/workgroup
; CLI-RANGE: ; Occupancy: 2
define amdgpu_kernel void @static_and_dynamic_lds(ptr addrspace(1) %out, i32 %i) #4 {
  %p = getelementptr [8192 x i32], ptr addrspace(3) @lds, i32 0, i32 %i
  store i32 1, ptr addrspace(3) %p
  %v = load i32, ptr addrspace(3) %p
  store i32 %v, ptr addrspace(1) %out
  ret void
}

; A request larger than the LDS of any hardware must still report the minimum
; occupancy, not wrap around to the maximum.
; DEFAULT-LABEL: {{^}}huge_dynamic_lds:
; DEFAULT: ; Occupancy: 1
; CLI-LABEL: {{^}}huge_dynamic_lds:
; CLI: ; Occupancy: 2
; CLI-RANGE-LABEL: {{^}}huge_dynamic_lds:
; CLI-RANGE: ; Occupancy: 8
define amdgpu_kernel void @huge_dynamic_lds(ptr addrspace(1) %out) #5 {
  store i32 0, ptr addrspace(1) %out
  ret void
}

@lds = internal addrspace(3) global [8192 x i32] poison, align 4

attributes #0 = { "amdgpu-flat-work-group-size"="1,256" }
attributes #1 = { "amdgpu-flat-work-group-size"="1,256" "amdgpu-dynamic-lds-bytes"="32768" }
attributes #2 = { "amdgpu-flat-work-group-size"="1,256" "amdgpu-dynamic-lds-bytes"="0,32768" }
attributes #3 = { "amdgpu-flat-work-group-size"="1,256" "amdgpu-dynamic-lds-bytes"="32768,49152" }
attributes #4 = { "amdgpu-flat-work-group-size"="1,256" "amdgpu-dynamic-lds-bytes"="16384" }
attributes #5 = { "amdgpu-flat-work-group-size"="1,256" "amdgpu-dynamic-lds-bytes"="4294967295" }
