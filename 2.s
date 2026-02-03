	.amdgcn_target "amdgcn-amd-amdhsa--gfx950"
	.amdhsa_code_object_version 5
	.text
	.globl	v10_f8                          ; -- Begin function v10_f8
	.p2align	8
	.type	v10_f8,@function
v10_f8:                                 ; @v10_f8
.Lfunc_begin0:
	.cfi_sections .debug_frame
	.cfi_startproc
; %bb.3:
	.file	1 "/home/jinpli/home/development/triton_03/study_matmul/gluon/matmul_kernels" "matmul_kernel.py"
	.loc	1 2115 0 prologue_end           ; matmul_kernel.py:2115:0
	s_load_dwordx2 s[2:3], s[0:1], 0x0
	s_load_dwordx8 s[4:11], s[0:1], 0x8
	s_load_dwordx4 s[12:15], s[0:1], 0x28
	s_waitcnt lgkmcnt(0)
	s_branch .LBB0_0
	.loc	1 0 0 is_stmt 0                 ; :0:0
.Ltmp0:
	.p2align	8
; %bb.4:
.LBB0_0:
.Ltmp1:
	.loc	1 2385 28 is_stmt 1             ; matmul_kernel.py:2385:28
	v_readfirstlane_b32 s13, v0
	.loc	1 2387 62                       ; matmul_kernel.py:2387:62
	s_lshr_b32 s14, s13, 6
	s_bfe_u32 s15, s13, 0x20006
.Ltmp2:
	.file	2 "/home/jinpli/home/development/triton_03/python/triton/language" "standard.py"
	.loc	2 43 17                         ; standard.py:43:17 @[ matmul_kernel.py:13:27 @[ matmul_kernel.py:2121:71 ] ]
	s_add_i32 s0, s8, 0xff
	.loc	2 43 30 is_stmt 0               ; standard.py:43:30 @[ matmul_kernel.py:13:27 @[ matmul_kernel.py:2121:71 ] ]
	s_ashr_i32 s1, s0, 31
	s_lshr_b32 s1, s1, 24
	s_add_i32 s0, s0, s1
	s_ashr_i32 s0, s0, 8
.Ltmp3:
	.loc	2 43 17                         ; standard.py:43:17 @[ matmul_kernel.py:14:27 @[ matmul_kernel.py:2121:71 ] ]
	s_add_i32 s1, s9, 0xff
	.loc	2 43 30                         ; standard.py:43:30 @[ matmul_kernel.py:14:27 @[ matmul_kernel.py:2121:71 ] ]
	s_ashr_i32 s8, s1, 31
	s_lshr_b32 s8, s8, 24
	s_add_i32 s1, s1, s8
	s_ashr_i32 s1, s1, 8
.Ltmp4:
	.loc	1 28 27 is_stmt 1               ; matmul_kernel.py:28:27 @[ matmul_kernel.py:2121:71 ]
	s_ashr_i32 s8, s16, 31
	s_lshr_b32 s8, s8, 29
	s_add_i32 s8, s16, s8
	s_ashr_i32 s8, s8, 3
	.loc	1 34 39                         ; matmul_kernel.py:34:39 @[ matmul_kernel.py:2121:71 ]
	s_lshl_b32 s9, s16, 5
	s_mulk_i32 s8, 0xff01
	s_add_i32 s8, s8, s9
	.loc	1 42 42                         ; matmul_kernel.py:42:42 @[ matmul_kernel.py:2121:71 ]
	s_lshl_b32 s9, s1, 2
	.loc	1 43 26                         ; matmul_kernel.py:43:26 @[ matmul_kernel.py:2121:71 ]
	s_xor_b32 s1, s8, s1
	s_ashr_i32 s1, s1, 31
	s_abs_i32 s16, s8
	s_abs_i32 s17, s9
	v_cvt_f32_u32_e32 v1, s17
	s_sub_i32 s18, 0, s17
.Ltmp5:
	.loc	1 2133 36                       ; matmul_kernel.py:2133:36
	v_and_b32_e32 v2, 63, v0
	v_lshl_or_b32 v4, s15, 6, v2
.Ltmp6:
	.loc	1 43 26                         ; matmul_kernel.py:43:26 @[ matmul_kernel.py:2121:71 ]
	v_rcp_iflag_f32_e32 v1, v1
.Ltmp7:
	.loc	1 2133 36                       ; matmul_kernel.py:2133:36
	v_lshlrev_b32_e32 v21, 1, v0
	v_and_b32_e32 v2, 0x70, v21
	v_or_b32_e32 v5, s15, v2
.Ltmp8:
	.loc	1 43 26                         ; matmul_kernel.py:43:26 @[ matmul_kernel.py:2121:71 ]
	v_mul_f32_e32 v1, 0x4f7ffffe, v1
	v_cvt_u32_f32_e32 v1, v1
.Ltmp9:
	.loc	1 2134 36                       ; matmul_kernel.py:2134:36
	v_lshlrev_b32_e32 v2, 4, v0
	v_and_b32_e32 v6, 0x70, v2
	.loc	1 2142 35                       ; matmul_kernel.py:2142:35
	s_mul_i32 s21, s10, 0x74
.Ltmp10:
	.loc	1 43 26                         ; matmul_kernel.py:43:26 @[ matmul_kernel.py:2121:71 ]
	v_readfirstlane_b32 s19, v1
	s_mul_i32 s18, s18, s19
	s_mul_hi_u32 s18, s19, s18
	s_add_i32 s19, s19, s18
	s_mul_hi_u32 s18, s16, s19
	s_mul_i32 s19, s18, s17
	s_sub_i32 s16, s16, s19
	s_add_i32 s19, s18, 1
	s_sub_i32 s20, s16, s17
	s_cmp_ge_u32 s16, s17
	s_cselect_b32 s18, s19, s18
	s_cselect_b32 s16, s20, s16
	s_add_i32 s19, s18, 1
	s_cmp_ge_u32 s16, s17
	s_cselect_b32 s16, s19, s18
	s_xor_b32 s16, s16, s1
	s_sub_i32 s1, s16, s1
	.loc	1 44 33                         ; matmul_kernel.py:44:33 @[ matmul_kernel.py:2121:71 ]
	s_lshl_b32 s16, s1, 2
	.loc	1 45 39                         ; matmul_kernel.py:45:39 @[ matmul_kernel.py:2121:71 ]
	s_sub_i32 s0, s0, s16
	.loc	1 45 52 is_stmt 0               ; matmul_kernel.py:45:52 @[ matmul_kernel.py:2121:71 ]
	s_min_i32 s17, s0, 4
	.loc	1 46 38 is_stmt 1               ; matmul_kernel.py:46:38 @[ matmul_kernel.py:2121:71 ]
	s_mul_i32 s1, s1, s9
	s_sub_i32 s8, s8, s1
	.loc	1 47 44                         ; matmul_kernel.py:47:44 @[ matmul_kernel.py:2121:71 ]
	s_xor_b32 s0, s8, s17
	s_ashr_i32 s9, s0, 31
	s_abs_i32 s20, s8
	s_abs_i32 s23, s17
	v_cvt_f32_u32_e32 v1, s23
	s_sub_i32 s24, 0, s23
.Ltmp11:
	.loc	1 2142 47                       ; matmul_kernel.py:2142:47
	v_mad_u64_u32 v[2:3], s[0:1], v5, s10, v[6:7]
.Ltmp12:
	.loc	1 47 44                         ; matmul_kernel.py:47:44 @[ matmul_kernel.py:2121:71 ]
	v_rcp_iflag_f32_e32 v1, v1
.Ltmp13:
	.loc	1 2143 53                       ; matmul_kernel.py:2143:53
	v_mad_u64_u32 v[24:25], s[0:1], v5, s11, v[6:7]
	.loc	1 2145 79                       ; matmul_kernel.py:2145:79
	v_add_u32_e32 v5, 0x80, v24
.Ltmp14:
	.loc	1 47 44                         ; matmul_kernel.py:47:44 @[ matmul_kernel.py:2121:71 ]
	v_mul_f32_e32 v1, 0x4f7ffffe, v1
	v_cvt_u32_f32_e32 v1, v1
	s_mov_b32 s19, 0x27000
	s_mov_b32 s18, 0x7ffffffe
.Ltmp15:
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	s_mov_b32 s22, s18
.Ltmp16:
	.loc	1 47 44                         ; matmul_kernel.py:47:44 @[ matmul_kernel.py:2121:71 ]
	v_readfirstlane_b32 s0, v1
	s_mul_i32 s24, s24, s0
	s_mul_hi_u32 s1, s0, s24
	s_add_i32 s0, s0, s1
	s_mul_hi_u32 s0, s20, s0
	s_mul_i32 s1, s0, s23
	s_sub_i32 s1, s20, s1
	s_add_i32 s20, s0, 1
	s_sub_i32 s24, s1, s23
	s_cmp_ge_u32 s1, s23
	s_cselect_b32 s0, s20, s0
	s_cselect_b32 s1, s24, s1
	s_add_i32 s20, s0, 1
	s_cmp_ge_u32 s1, s23
	s_cselect_b32 s0, s20, s0
	s_xor_b32 s0, s0, s9
	s_sub_i32 s0, s0, s9
	.loc	1 46 58                         ; matmul_kernel.py:46:58 @[ matmul_kernel.py:2121:71 ]
	s_mul_i32 s1, s0, s17
	s_sub_i32 s1, s8, s1
	.loc	1 46 31 is_stmt 0               ; matmul_kernel.py:46:31 @[ matmul_kernel.py:2121:71 ]
	s_add_i32 s1, s1, s16
.Ltmp17:
	.loc	1 2139 29 is_stmt 1             ; matmul_kernel.py:2139:29
	s_lshl_b32 s9, s1, 8
	.loc	1 2139 39 is_stmt 0             ; matmul_kernel.py:2139:39
	s_mul_i32 s8, s9, s10
	.loc	1 2139 21                       ; matmul_kernel.py:2139:21
	s_ashr_i32 s17, s8, 31
	s_add_u32 s16, s2, s8
	s_addc_u32 s33, s3, s17
	.loc	1 2140 29 is_stmt 1             ; matmul_kernel.py:2140:29
	s_lshl_b32 s8, s0, 8
	.loc	1 2140 39 is_stmt 0             ; matmul_kernel.py:2140:39
	s_mul_i32 s0, s8, s11
	.loc	1 2140 21                       ; matmul_kernel.py:2140:21
	s_ashr_i32 s17, s0, 31
	s_add_u32 s20, s4, s0
	s_addc_u32 s0, s5, s17
	.loc	1 2142 35 is_stmt 1             ; matmul_kernel.py:2142:35
	s_lshl_b32 s4, s10, 2
	.loc	1 2142 47 is_stmt 0             ; matmul_kernel.py:2142:47
	v_add_u32_e32 v6, s4, v2
	v_add_u32_e32 v7, s4, v6
	v_add_u32_e32 v8, s4, v7
	v_add_u32_e32 v9, s21, v8
	v_add_u32_e32 v10, s4, v9
	v_add_u32_e32 v11, s4, v10
	v_add_u32_e32 v12, s4, v11
	.loc	1 2143 72 is_stmt 1             ; matmul_kernel.py:2143:72
	s_lshl_b32 s4, s11, 2
	.loc	1 2143 53 is_stmt 0             ; matmul_kernel.py:2143:53
	v_add_u32_e32 v1, s4, v24
	v_add_u32_e32 v23, s4, v1
	v_add_u32_e32 v25, s4, v23
	.loc	1 2145 79 is_stmt 1             ; matmul_kernel.py:2145:79
	v_add_u32_e32 v13, 0x80, v1
	v_add_u32_e32 v14, 0x80, v23
	v_add_u32_e32 v15, 0x80, v25
	.loc	1 2146 89                       ; matmul_kernel.py:2146:89
	s_lshl_b32 s4, s11, 8
	.loc	1 2146 102 is_stmt 0            ; matmul_kernel.py:2146:102
	s_ashr_i32 s4, s4, 1
	.loc	1 2146 79                       ; matmul_kernel.py:2146:79
	v_add_u32_e32 v16, s4, v24
	v_add_u32_e32 v17, s4, v1
	v_add_u32_e32 v18, s4, v23
	v_add_u32_e32 v19, s4, v25
	.loc	1 2200 71 is_stmt 1             ; matmul_kernel.py:2200:71
	s_and_b32 s17, s33, 0xffff
	s_lshl_b32 s4, s15, 10
	s_and_b32 s5, s14, 2
	s_add_i32 s15, s15, s5
	s_lshl_b32 s5, s15, 4
	s_or_b32 s52, s5, s4
	s_add_i32 s4, s52, 0
	s_mov_b32 m0, s4
	s_or_b32 s54, s52, 0x1080
	buffer_load_dwordx4 v2, s[16:19], 0 offen lds
	s_add_i32 s11, s4, 0x1080
	s_mov_b32 m0, s11
	s_or_b32 s53, s52, 0x2100
	s_add_i32 s14, s4, 0x2100
	s_or_b32 s5, s52, 0x3180
	s_add_i32 s15, s4, 0x3180
	buffer_load_dwordx4 v6, s[16:19], 0 offen lds
	s_mov_b32 m0, s14
	s_add_i32 s24, s4, 0x4200
	s_add_i32 s25, s4, 0x5280
	s_add_i32 s26, s4, 0x6300
	s_add_i32 s27, s4, 0x7380
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	s_and_b32 s21, s0, 0xffff
	.loc	1 2200 71                       ; matmul_kernel.py:2200:71
	buffer_load_dwordx4 v7, s[16:19], 0 offen lds
	s_mov_b32 m0, s15
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	s_mov_b32 s23, s19
	s_add_i32 s55, 0, 0x107d0
	s_add_i32 s28, s55, s52
	s_add_i32 s29, s55, s54
	s_add_i32 s30, s55, s53
	.loc	1 2200 71                       ; matmul_kernel.py:2200:71
	buffer_load_dwordx4 v8, s[16:19], 0 offen lds
	s_mov_b32 m0, s24
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	s_add_i32 s31, s55, s5
	.loc	1 2222 65                       ; matmul_kernel.py:2222:65
	v_and_b32_e32 v3, 15, v0
	v_lshlrev_b32_e32 v22, 10, v3
	v_lshlrev_b32_e32 v20, 1, v4
	s_movk_i32 s34, 0x160
	.loc	1 2200 71                       ; matmul_kernel.py:2200:71
	buffer_load_dwordx4 v9, s[16:19], 0 offen lds
	s_mov_b32 m0, s25
	.loc	1 2222 65                       ; matmul_kernel.py:2222:65
	v_and_or_b32 v20, v20, s34, v22
	v_and_b32_e32 v26, 14, v0
	v_add_lshl_u32 v26, v3, v26, 4
	v_add_u32_e32 v20, v20, v26
	v_add_u32_e32 v20, 0, v20
	.loc	1 2200 71                       ; matmul_kernel.py:2200:71
	buffer_load_dwordx4 v10, s[16:19], 0 offen lds
	s_mov_b32 m0, s26
	s_movk_i32 s34, 0x60
	.loc	1 2223 67                       ; matmul_kernel.py:2223:67
	v_and_or_b32 v21, v21, s34, v22
	v_add_u32_e32 v26, v21, v26
	.loc	1 2226 35                       ; matmul_kernel.py:2226:35
	s_mul_i32 s1, s10, s1
	v_mov_b32_e32 v27, 0
	s_mov_b32 s10, -2
	.loc	1 2200 71                       ; matmul_kernel.py:2200:71
	buffer_load_dwordx4 v11, s[16:19], 0 offen lds
	s_mov_b32 m0, s27
	v_mov_b32_e32 v21, 0x7f
	v_bfrev_b32_e32 v22, 1
	v_accvgpr_write_b32 a64, v27
	v_accvgpr_write_b32 a65, v27
	v_accvgpr_write_b32 a66, v27
	buffer_load_dwordx4 v12, s[16:19], 0 offen lds
	.loc	1 2204 14                       ; matmul_kernel.py:2204:14
	s_add_u32 s16, s16, 0x80
	s_addc_u32 s17, s33, 0
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	s_mov_b32 m0, s28
	.loc	1 2210 71                       ; matmul_kernel.py:2210:71
	s_add_i32 s46, s4, 0xc600
	s_add_i32 s45, s4, 0xb580
	.loc	1 2211 72                       ; matmul_kernel.py:2211:72
	s_add_i32 s37, 0, 0x149d0
	s_add_i32 s35, s37, s54
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	buffer_load_dwordx4 v24, s[20:23], 0 offen lds
	s_mov_b32 m0, s29
	.loc	1 2211 72                       ; matmul_kernel.py:2211:72
	s_add_i32 s33, s37, s5
	.loc	1 2210 71                       ; matmul_kernel.py:2210:71
	s_add_i32 s36, s4, 0xf780
	.loc	1 2211 72                       ; matmul_kernel.py:2211:72
	s_add_i32 s34, s37, s52
	s_add_i32 s37, s37, s53
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	s_add_i32 s41, 0, 0x18ba0
	s_add_i32 s40, s41, s54
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	buffer_load_dwordx4 v1, s[20:23], 0 offen lds
	s_mov_b32 m0, s30
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	s_add_i32 s38, s41, s5
	.loc	1 2210 71                       ; matmul_kernel.py:2210:71
	s_and_b32 s17, s17, 0xffff
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	s_add_i32 s39, s41, s52
	s_add_i32 s41, s41, s53
	.loc	1 2210 71                       ; matmul_kernel.py:2210:71
	s_add_i32 s42, s4, 0x8400
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	buffer_load_dwordx4 v23, s[20:23], 0 offen lds
	s_mov_b32 m0, s31
	.loc	1 2210 71                       ; matmul_kernel.py:2210:71
	s_add_i32 s44, s4, 0x9480
	s_add_i32 s43, s4, 0xa500
	s_add_i32 s47, s4, 0xd680
	s_add_i32 s48, s4, 0xe700
	.loc	1 2215 14                       ; matmul_kernel.py:2215:14
	s_add_u32 s49, s20, 0x80
	.loc	1 2201 72                       ; matmul_kernel.py:2201:72
	buffer_load_dwordx4 v25, s[20:23], 0 offen lds
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	s_mov_b32 m0, s39
	.loc	1 2215 14                       ; matmul_kernel.py:2215:14
	s_addc_u32 s50, s0, 0
	.loc	1 2226 35                       ; matmul_kernel.py:2226:35
	s_lshl_b32 s0, s1, 8
	s_ashr_i32 s1, s0, 31
	.loc	1 2217 72                       ; matmul_kernel.py:2217:72
	s_add_i32 s56, 0, 0x1cda0
	s_add_i32 s52, s56, s52
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	buffer_load_dwordx4 v16, s[20:23], 0 offen lds
	s_mov_b32 m0, s40
	.loc	1 2217 72                       ; matmul_kernel.py:2217:72
	s_add_i32 s51, s56, s5
	.loc	1 2223 67                       ; matmul_kernel.py:2223:67
	s_and_b32 s5, s13, 64
	v_lshl_add_u32 v28, s5, 2, v26
	v_add_u32_e32 v1, 0, v28
	v_add_u32_e32 v26, 0x1cda0, v1
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	buffer_load_dwordx4 v17, s[20:23], 0 offen lds
	s_mov_b32 m0, s41
	.loc	1 2223 67                       ; matmul_kernel.py:2223:67
	v_add_u32_e32 v28, s55, v28
	v_add_u32_e32 v25, 0x149d0, v1
	v_add_u32_e32 v23, 0x107d0, v1
	v_add_u32_e32 v24, 0x18ba0, v1
	.loc	1 2217 72                       ; matmul_kernel.py:2217:72
	s_add_i32 s53, s56, s53
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	buffer_load_dwordx4 v18, s[20:23], 0 offen lds
	s_mov_b32 m0, s38
	.loc	1 2217 72                       ; matmul_kernel.py:2217:72
	s_add_i32 s54, s56, s54
	v_accvgpr_write_b32 a67, v27
	v_accvgpr_write_b32 a124, v27
	v_accvgpr_write_b32 a125, v27
	v_accvgpr_write_b32 a126, v27
	.loc	1 2206 72                       ; matmul_kernel.py:2206:72
	buffer_load_dwordx4 v19, s[20:23], 0 offen lds
	.loc	1 2210 71                       ; matmul_kernel.py:2210:71
	s_mov_b32 m0, s42
	s_waitcnt lgkmcnt(0)
	s_barrier
	v_accvgpr_write_b32 a127, v27
	v_accvgpr_write_b32 a104, v27
	v_accvgpr_write_b32 a105, v27
	buffer_load_dwordx4 v2, s[16:19], 0 offen lds
	s_mov_b32 m0, s44
	v_accvgpr_write_b32 a106, v27
	v_accvgpr_write_b32 a107, v27
	v_accvgpr_write_b32 a112, v27
	v_accvgpr_write_b32 a113, v27
	v_accvgpr_write_b32 a114, v27
	buffer_load_dwordx4 v6, s[16:19], 0 offen lds
	s_mov_b32 m0, s43
	v_accvgpr_write_b32 a115, v27
	v_accvgpr_write_b32 a100, v27
	v_accvgpr_write_b32 a101, v27
	v_accvgpr_write_b32 a102, v27
	v_accvgpr_write_b32 a103, v27
	buffer_load_dwordx4 v7, s[16:19], 0 offen lds
	s_mov_b32 m0, s45
	v_accvgpr_write_b32 a108, v27
	v_accvgpr_write_b32 a109, v27
	v_accvgpr_write_b32 a110, v27
	v_accvgpr_write_b32 a111, v27
	v_accvgpr_write_b32 a116, v27
	buffer_load_dwordx4 v8, s[16:19], 0 offen lds
	s_mov_b32 m0, s46
	v_accvgpr_write_b32 a117, v27
	v_accvgpr_write_b32 a118, v27
	v_accvgpr_write_b32 a119, v27
	v_accvgpr_write_b32 a120, v27
	v_accvgpr_write_b32 a121, v27
	buffer_load_dwordx4 v9, s[16:19], 0 offen lds
	s_mov_b32 m0, s47
	v_accvgpr_write_b32 a122, v27
	v_accvgpr_write_b32 a123, v27
	v_accvgpr_write_b32 a68, v27
	v_accvgpr_write_b32 a69, v27
	v_accvgpr_write_b32 a70, v27
	buffer_load_dwordx4 v10, s[16:19], 0 offen lds
	s_mov_b32 m0, s48
	v_accvgpr_write_b32 a71, v27
	v_accvgpr_write_b32 a52, v27
	v_accvgpr_write_b32 a53, v27
	v_accvgpr_write_b32 a54, v27
	v_accvgpr_write_b32 a55, v27
	buffer_load_dwordx4 v11, s[16:19], 0 offen lds
	s_mov_b32 m0, s36
	v_accvgpr_write_b32 a32, v27
	v_accvgpr_write_b32 a33, v27
	v_accvgpr_write_b32 a34, v27
	v_accvgpr_write_b32 a35, v27
	v_accvgpr_write_b32 a36, v27
	buffer_load_dwordx4 v12, s[16:19], 0 offen lds
	.loc	1 2211 72                       ; matmul_kernel.py:2211:72
	s_mov_b32 m0, s34
	.loc	1 2217 72                       ; matmul_kernel.py:2217:72
	s_and_b32 s17, s50, 0xffff
	s_mov_b32 s16, s49
	.loc	1 2226 35                       ; matmul_kernel.py:2226:35
	s_add_u32 s0, s2, s0
	s_addc_u32 s1, s3, s1
	s_add_u32 s55, s0, 0x180
	.loc	1 2211 72                       ; matmul_kernel.py:2211:72
	buffer_load_dwordx4 v5, s[20:23], 0 offen lds
	s_mov_b32 m0, s35
	.loc	1 2226 35                       ; matmul_kernel.py:2226:35
	s_addc_u32 s56, s1, 0
	v_accvgpr_write_b32 a37, v27
	v_accvgpr_write_b32 a38, v27
	v_accvgpr_write_b32 a39, v27
	v_accvgpr_write_b32 a40, v27
	.loc	1 2211 72                       ; matmul_kernel.py:2211:72
	buffer_load_dwordx4 v13, s[20:23], 0 offen lds
	s_mov_b32 m0, s37
	v_accvgpr_write_b32 a41, v27
	v_accvgpr_write_b32 a42, v27
	v_accvgpr_write_b32 a43, v27
	v_accvgpr_write_b32 a44, v27
	v_accvgpr_write_b32 a45, v27
	buffer_load_dwordx4 v14, s[20:23], 0 offen lds
	s_mov_b32 m0, s33
	v_accvgpr_write_b32 a46, v27
	v_accvgpr_write_b32 a47, v27
	v_accvgpr_write_b32 a60, v27
	v_accvgpr_write_b32 a61, v27
	v_accvgpr_write_b32 a62, v27
	buffer_load_dwordx4 v15, s[20:23], 0 offen lds
	.loc	1 2217 72                       ; matmul_kernel.py:2217:72
	s_mov_b32 m0, s52
	v_accvgpr_write_b32 a63, v27
	v_accvgpr_write_b32 a56, v27
	v_accvgpr_write_b32 a57, v27
	v_accvgpr_write_b32 a58, v27
	v_accvgpr_write_b32 a59, v27
	buffer_load_dwordx4 v16, s[16:19], 0 offen lds
	s_mov_b32 m0, s54
	v_accvgpr_write_b32 a12, v27
	v_accvgpr_write_b32 a13, v27
	v_accvgpr_write_b32 a14, v27
	v_accvgpr_write_b32 a15, v27
	v_accvgpr_write_b32 a8, v27
	buffer_load_dwordx4 v17, s[16:19], 0 offen lds
	s_mov_b32 m0, s53
	v_accvgpr_write_b32 a9, v27
	v_accvgpr_write_b32 a10, v27
	v_accvgpr_write_b32 a11, v27
	v_accvgpr_write_b32 a0, v27
	v_accvgpr_write_b32 a1, v27
	buffer_load_dwordx4 v18, s[16:19], 0 offen lds
	v_accvgpr_write_b32 a2, v27
	v_accvgpr_write_b32 a3, v27
	s_mov_b32 m0, s51
	v_accvgpr_write_b32 a4, v27
	v_accvgpr_write_b32 a5, v27
	v_accvgpr_write_b32 a6, v27
	buffer_load_dwordx4 v19, s[16:19], 0 offen lds
	.loc	1 2220 32                       ; matmul_kernel.py:2220:32
	s_waitcnt vmcnt(20) lgkmcnt(0)
	s_barrier
	.loc	1 2222 65                       ; matmul_kernel.py:2222:65
	ds_read_b128 v[100:103], v20
	ds_read_b128 v[104:107], v20 offset:16
	v_accvgpr_write_b32 a7, v27
	v_accvgpr_write_b32 a16, v27
	ds_read_b128 v[92:95], v20 offset:128
	ds_read_b128 v[96:99], v20 offset:144
	v_accvgpr_write_b32 a17, v27
	v_accvgpr_write_b32 a18, v27
	ds_read_b128 v[84:87], v20 offset:512
	ds_read_b128 v[88:91], v20 offset:528
	v_accvgpr_write_b32 a19, v27
	v_accvgpr_write_b32 a24, v27
	ds_read_b128 v[76:79], v20 offset:640
	ds_read_b128 v[80:83], v20 offset:656
	v_accvgpr_write_b32 a25, v27
	v_accvgpr_write_b32 a26, v27
	ds_read_b128 v[68:71], v20 offset:16896
	ds_read_b128 v[72:75], v20 offset:16912
	v_accvgpr_write_b32 a27, v27
	v_accvgpr_write_b32 a28, v27
	ds_read_b128 v[60:63], v20 offset:17024
	ds_read_b128 v[64:67], v20 offset:17040
	v_accvgpr_write_b32 a29, v27
	v_accvgpr_write_b32 a30, v27
	ds_read_b128 v[52:55], v20 offset:17408
	ds_read_b128 v[56:59], v20 offset:17424
	v_accvgpr_write_b32 a31, v27
	v_accvgpr_write_b32 a48, v27
	ds_read_b128 v[44:47], v20 offset:17536
	ds_read_b128 v[48:51], v20 offset:17552
	v_accvgpr_write_b32 a49, v27
	v_accvgpr_write_b32 a50, v27
	.loc	1 2223 67                       ; matmul_kernel.py:2223:67
	ds_read_b128 v[108:111], v28
	ds_read_b128 v[112:115], v28 offset:16
	v_accvgpr_write_b32 a51, v27
	v_accvgpr_write_b32 a20, v27
	ds_read_b128 v[116:119], v28 offset:128
	ds_read_b128 v[120:123], v28 offset:144
	v_accvgpr_write_b32 a21, v27
	v_accvgpr_write_b32 a22, v27
	ds_read_b128 v[124:127], v28 offset:512
	ds_read_b128 v[128:131], v28 offset:528
	v_accvgpr_write_b32 a23, v27
	v_accvgpr_write_b32 a96, v27
	ds_read_b128 v[132:135], v28 offset:640
	ds_read_b128 v[136:139], v28 offset:656
	.loc	1 2225 32                       ; matmul_kernel.py:2225:32
	s_waitcnt vmcnt(16) lgkmcnt(0)
	s_barrier
	v_accvgpr_write_b32 a97, v27
	v_accvgpr_write_b32 a98, v27
	v_accvgpr_write_b32 a99, v27
	v_accvgpr_write_b32 a92, v27
	v_accvgpr_write_b32 a93, v27
	v_accvgpr_write_b32 a94, v27
	v_accvgpr_write_b32 a95, v27
	v_accvgpr_write_b32 a88, v27
	v_accvgpr_write_b32 a89, v27
	v_accvgpr_write_b32 a90, v27
	v_accvgpr_write_b32 a91, v27
	v_accvgpr_write_b32 a84, v27
	v_accvgpr_write_b32 a85, v27
	v_accvgpr_write_b32 a86, v27
	v_accvgpr_write_b32 a87, v27
	v_accvgpr_write_b32 a80, v27
	v_accvgpr_write_b32 a81, v27
	v_accvgpr_write_b32 a82, v27
	v_accvgpr_write_b32 a83, v27
	v_accvgpr_write_b32 a76, v27
	v_accvgpr_write_b32 a77, v27
	v_accvgpr_write_b32 a78, v27
	v_accvgpr_write_b32 a79, v27
	v_accvgpr_write_b32 a72, v27
	v_accvgpr_write_b32 a73, v27
	v_accvgpr_write_b32 a74, v27
	v_accvgpr_write_b32 a75, v27
	v_accvgpr_write_b32 a252, v27
	v_accvgpr_write_b32 a253, v27
	v_accvgpr_write_b32 a254, v27
	v_accvgpr_write_b32 a255, v27
	v_accvgpr_write_b32 a248, v27
	v_accvgpr_write_b32 a249, v27
	v_accvgpr_write_b32 a250, v27
	v_accvgpr_write_b32 a251, v27
	v_accvgpr_write_b32 a244, v27
	v_accvgpr_write_b32 a245, v27
	v_accvgpr_write_b32 a246, v27
	v_accvgpr_write_b32 a247, v27
	v_accvgpr_write_b32 a240, v27
	v_accvgpr_write_b32 a241, v27
	v_accvgpr_write_b32 a242, v27
	v_accvgpr_write_b32 a243, v27
	v_accvgpr_write_b32 a236, v27
	v_accvgpr_write_b32 a237, v27
	v_accvgpr_write_b32 a238, v27
	v_accvgpr_write_b32 a239, v27
	v_accvgpr_write_b32 a232, v27
	v_accvgpr_write_b32 a233, v27
	v_accvgpr_write_b32 a234, v27
	v_accvgpr_write_b32 a235, v27
	v_accvgpr_write_b32 a228, v27
	v_accvgpr_write_b32 a229, v27
	v_accvgpr_write_b32 a230, v27
	v_accvgpr_write_b32 a231, v27
	v_accvgpr_write_b32 a224, v27
	v_accvgpr_write_b32 a225, v27
	v_accvgpr_write_b32 a226, v27
	v_accvgpr_write_b32 a227, v27
	v_accvgpr_write_b32 a220, v27
	v_accvgpr_write_b32 a221, v27
	v_accvgpr_write_b32 a222, v27
	v_accvgpr_write_b32 a223, v27
	v_accvgpr_write_b32 a216, v27
	v_accvgpr_write_b32 a217, v27
	v_accvgpr_write_b32 a218, v27
	v_accvgpr_write_b32 a219, v27
	v_accvgpr_write_b32 a212, v27
	v_accvgpr_write_b32 a213, v27
	v_accvgpr_write_b32 a214, v27
	v_accvgpr_write_b32 a215, v27
	v_accvgpr_write_b32 a208, v27
	v_accvgpr_write_b32 a209, v27
	v_accvgpr_write_b32 a210, v27
	v_accvgpr_write_b32 a211, v27
	v_accvgpr_write_b32 a204, v27
	v_accvgpr_write_b32 a205, v27
	v_accvgpr_write_b32 a206, v27
	v_accvgpr_write_b32 a207, v27
	v_accvgpr_write_b32 a200, v27
	v_accvgpr_write_b32 a201, v27
	v_accvgpr_write_b32 a202, v27
	v_accvgpr_write_b32 a203, v27
	v_accvgpr_write_b32 a196, v27
	v_accvgpr_write_b32 a197, v27
	v_accvgpr_write_b32 a198, v27
	v_accvgpr_write_b32 a199, v27
	v_accvgpr_write_b32 a192, v27
	v_accvgpr_write_b32 a193, v27
	v_accvgpr_write_b32 a194, v27
	v_accvgpr_write_b32 a195, v27
	v_accvgpr_write_b32 a188, v27
	v_accvgpr_write_b32 a189, v27
	v_accvgpr_write_b32 a190, v27
	v_accvgpr_write_b32 a191, v27
	v_accvgpr_write_b32 a184, v27
	v_accvgpr_write_b32 a185, v27
	v_accvgpr_write_b32 a186, v27
	v_accvgpr_write_b32 a187, v27
	v_accvgpr_write_b32 a180, v27
	v_accvgpr_write_b32 a181, v27
	v_accvgpr_write_b32 a182, v27
	v_accvgpr_write_b32 a183, v27
	v_accvgpr_write_b32 a176, v27
	v_accvgpr_write_b32 a177, v27
	v_accvgpr_write_b32 a178, v27
	v_accvgpr_write_b32 a179, v27
	v_accvgpr_write_b32 a172, v27
	v_accvgpr_write_b32 a173, v27
	v_accvgpr_write_b32 a174, v27
	v_accvgpr_write_b32 a175, v27
	v_accvgpr_write_b32 a168, v27
	v_accvgpr_write_b32 a169, v27
	v_accvgpr_write_b32 a170, v27
	v_accvgpr_write_b32 a171, v27
	v_accvgpr_write_b32 a164, v27
	v_accvgpr_write_b32 a165, v27
	v_accvgpr_write_b32 a166, v27
	v_accvgpr_write_b32 a167, v27
	v_accvgpr_write_b32 a160, v27
	v_accvgpr_write_b32 a161, v27
	v_accvgpr_write_b32 a162, v27
	v_accvgpr_write_b32 a163, v27
	v_accvgpr_write_b32 a156, v27
	v_accvgpr_write_b32 a157, v27
	v_accvgpr_write_b32 a158, v27
	v_accvgpr_write_b32 a159, v27
	v_accvgpr_write_b32 a152, v27
	v_accvgpr_write_b32 a153, v27
	v_accvgpr_write_b32 a154, v27
	v_accvgpr_write_b32 a155, v27
	v_accvgpr_write_b32 a148, v27
	v_accvgpr_write_b32 a149, v27
	v_accvgpr_write_b32 a150, v27
	v_accvgpr_write_b32 a151, v27
	v_accvgpr_write_b32 a144, v27
	v_accvgpr_write_b32 a145, v27
	v_accvgpr_write_b32 a146, v27
	v_accvgpr_write_b32 a147, v27
	v_accvgpr_write_b32 a140, v27
	v_accvgpr_write_b32 a141, v27
	v_accvgpr_write_b32 a142, v27
	v_accvgpr_write_b32 a143, v27
	v_accvgpr_write_b32 a136, v27
	v_accvgpr_write_b32 a137, v27
	v_accvgpr_write_b32 a138, v27
	v_accvgpr_write_b32 a139, v27
	v_accvgpr_write_b32 a132, v27
	v_accvgpr_write_b32 a133, v27
	v_accvgpr_write_b32 a134, v27
	v_accvgpr_write_b32 a135, v27
	v_accvgpr_write_b32 a128, v27
	v_accvgpr_write_b32 a129, v27
	v_accvgpr_write_b32 a130, v27
	v_accvgpr_write_b32 a131, v27
.LBB0_1:                                ; =>This Inner Loop Header: Depth=1
	.loc	1 2228 22                       ; matmul_kernel.py:2228:22
	s_add_u32 s16, s55, 0xffffff80
	s_addc_u32 s0, s56, -1
	; sched_barrier mask(0x00000000)
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[252:255], v[108:115], v[100:107], a[252:255], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	s_mov_b32 m0, s4
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	s_waitcnt lgkmcnt(0)
	.loc	1 2234 67                       ; matmul_kernel.py:2234:67
	ds_read_b128 v[180:183], v24
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[248:251], v[116:123], v[100:107], a[248:251], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2234 67                       ; matmul_kernel.py:2234:67
	ds_read_b128 v[184:187], v24 offset:16
	.loc	1 2236 94                       ; matmul_kernel.py:2236:94
	s_cmp_eq_u32 s10, 28
	.loc	1 2234 67                       ; matmul_kernel.py:2234:67
	ds_read_b128 v[192:195], v24 offset:144
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[244:247], v[124:131], v[100:107], a[244:247], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2234 67                       ; matmul_kernel.py:2234:67
	ds_read_b128 v[188:191], v24 offset:128
	.loc	1 2236 94                       ; matmul_kernel.py:2236:94
	s_cselect_b64 vcc, -1, 0
	.loc	1 2236 71 is_stmt 0             ; matmul_kernel.py:2236:71
	v_cndmask_b32_e32 v31, v2, v22, vcc
	.loc	1 2233 75 is_stmt 1             ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[240:243], v[132:139], v[100:107], a[240:243], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2234 67                       ; matmul_kernel.py:2234:67
	ds_read_b128 v[200:203], v24 offset:528
	ds_read_b128 v[196:199], v24 offset:512
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	s_and_b32 s17, s0, 0xffff
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[236:239], v[108:115], v[92:99], a[236:239], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2234 67                       ; matmul_kernel.py:2234:67
	ds_read_b128 v[208:211], v24 offset:656
	ds_read_b128 v[204:207], v24 offset:640
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	buffer_load_dwordx4 v31, s[16:19], 0 offen lds
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[232:235], v[116:123], v[92:99], a[232:235], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	s_mov_b32 m0, s11
	v_cndmask_b32_e32 v38, v6, v22, vcc
	v_cndmask_b32_e32 v36, v7, v22, vcc
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[228:231], v[124:131], v[92:99], a[228:231], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	v_cndmask_b32_e32 v34, v8, v22, vcc
	buffer_load_dwordx4 v38, s[16:19], 0 offen lds
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[224:227], v[132:139], v[92:99], a[224:227], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	s_mov_b32 m0, s14
	v_cndmask_b32_e32 v37, v9, v22, vcc
	v_cndmask_b32_e32 v35, v10, v22, vcc
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[220:223], v[108:115], v[84:91], a[220:223], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	v_cndmask_b32_e32 v32, v11, v22, vcc
	buffer_load_dwordx4 v36, s[16:19], 0 offen lds
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[216:219], v[116:123], v[84:91], a[216:219], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	s_mov_b32 m0, s15
	v_cndmask_b32_e32 v33, v12, v22, vcc
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	v_cndmask_b32_e32 v30, v5, v22, vcc
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[212:215], v[124:131], v[84:91], a[212:215], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	v_cndmask_b32_e32 v28, v13, v22, vcc
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	buffer_load_dwordx4 v34, s[16:19], 0 offen lds
	s_mov_b32 m0, s24
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	v_cndmask_b32_e32 v29, v14, v22, vcc
	v_cndmask_b32_e32 v27, v15, v22, vcc
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[208:211], v[132:139], v[84:91], a[208:211], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	buffer_load_dwordx4 v37, s[16:19], 0 offen lds
	s_mov_b32 m0, s25
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[204:207], v[108:115], v[76:83], a[204:207], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[200:203], v[116:123], v[76:83], a[200:203], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	buffer_load_dwordx4 v35, s[16:19], 0 offen lds
	s_mov_b32 m0, s26
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[196:199], v[124:131], v[76:83], a[196:199], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[192:195], v[132:139], v[76:83], a[192:195], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	buffer_load_dwordx4 v32, s[16:19], 0 offen lds
	s_mov_b32 m0, s27
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[188:191], v[108:115], v[68:75], a[188:191], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[184:187], v[116:123], v[68:75], a[184:187], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2236 71                       ; matmul_kernel.py:2236:71
	buffer_load_dwordx4 v33, s[16:19], 0 offen lds
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	s_mov_b32 m0, s28
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[180:183], v[124:131], v[68:75], a[180:183], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	s_and_b32 s17, s50, 0xffff
	s_mov_b32 s16, s49
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[176:179], v[132:139], v[68:75], a[176:179], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	buffer_load_dwordx4 v30, s[16:19], 0 offen lds
	s_mov_b32 m0, s29
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[172:175], v[108:115], v[60:67], a[172:175], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[168:171], v[116:123], v[60:67], a[168:171], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	buffer_load_dwordx4 v28, s[16:19], 0 offen lds
	s_mov_b32 m0, s30
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[164:167], v[124:131], v[60:67], a[164:167], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[160:163], v[132:139], v[60:67], a[160:163], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	buffer_load_dwordx4 v29, s[16:19], 0 offen lds
	s_mov_b32 m0, s31
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[156:159], v[108:115], v[52:59], a[156:159], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[152:155], v[116:123], v[52:59], a[152:155], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2237 72                       ; matmul_kernel.py:2237:72
	buffer_load_dwordx4 v27, s[16:19], 0 offen lds
	.loc	1 2233 75                       ; matmul_kernel.py:2233:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[148:151], v[124:131], v[52:59], a[148:151], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[144:147], v[132:139], v[52:59], a[144:147], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[140:143], v[108:115], v[44:51], a[140:143], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[136:139], v[116:123], v[44:51], a[136:139], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[132:135], v[124:131], v[44:51], a[132:135], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[128:131], v[132:139], v[44:51], a[128:131], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	; sched_barrier mask(0x00000000)
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	s_waitcnt lgkmcnt(6)
	v_mfma_scale_f32_16x16x128_f8f6f4 a[64:67], v[180:187], v[100:107], a[64:67], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	s_mov_b32 m0, s39
	.loc	1 2248 36                       ; matmul_kernel.py:2248:36
	s_waitcnt vmcnt(16) lgkmcnt(0)
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[124:127], v[188:195], v[100:107], a[124:127], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2248 36                       ; matmul_kernel.py:2248:36
	s_barrier
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	s_waitcnt lgkmcnt(0)
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[116:119], v20 offset:33792
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[104:107], v[196:203], v[100:107], a[104:107], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[120:123], v20 offset:33808
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	s_add_u32 s16, s49, 0x80
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[112:115], v20 offset:33936
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[112:115], v[204:211], v[100:107], a[112:115], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[108:111], v20 offset:33920
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	s_addc_u32 s0, s50, 0
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[136:139], v20 offset:34320
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[100:103], v[180:187], v[92:99], a[100:103], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[132:135], v20 offset:34304
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	s_and_b32 s17, s0, 0xffff
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[176:179], v20 offset:34448
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[108:111], v[188:195], v[92:99], a[108:111], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[172:175], v20 offset:34432
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	v_cndmask_b32_e32 v41, v16, v22, vcc
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[168:171], v20 offset:50704
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[116:119], v[196:203], v[92:99], a[116:119], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[164:167], v20 offset:50688
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	buffer_load_dwordx4 v41, s[16:19], 0 offen lds
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[120:123], v[204:211], v[92:99], a[120:123], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	s_mov_b32 m0, s40
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[160:163], v20 offset:50832
	ds_read_b128 v[156:159], v20 offset:50816
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[68:71], v[180:187], v[84:91], a[68:71], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	v_cndmask_b32_e32 v42, v17, v22, vcc
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[152:155], v20 offset:51216
	ds_read_b128 v[148:151], v20 offset:51200
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[52:55], v[188:195], v[84:91], a[52:55], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	buffer_load_dwordx4 v42, s[16:19], 0 offen lds
	s_mov_b32 m0, s41
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[32:35], v[196:203], v[84:91], a[32:35], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2250 65                       ; matmul_kernel.py:2250:65
	ds_read_b128 v[144:147], v20 offset:51344
	ds_read_b128 v[140:143], v20 offset:51328
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	v_cndmask_b32_e32 v39, v18, v22, vcc
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[36:39], v[204:211], v[84:91], a[36:39], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2251 67                       ; matmul_kernel.py:2251:67
	ds_read_b128 v[92:95], v25
	ds_read_b128 v[96:99], v25 offset:16
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	buffer_load_dwordx4 v39, s[16:19], 0 offen lds
	.loc	1 2251 67                       ; matmul_kernel.py:2251:67
	ds_read_b128 v[104:107], v25 offset:144
	ds_read_b128 v[100:103], v25 offset:128
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	v_cndmask_b32_e32 v40, v19, v22, vcc
	s_mov_b32 m0, s38
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[40:43], v[180:187], v[76:83], a[40:43], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2251 67                       ; matmul_kernel.py:2251:67
	ds_read_b128 v[128:131], v25 offset:528
	ds_read_b128 v[124:127], v25 offset:512
	.loc	1 2253 72                       ; matmul_kernel.py:2253:72
	buffer_load_dwordx4 v40, s[16:19], 0 offen lds
	.loc	1 2251 67                       ; matmul_kernel.py:2251:67
	ds_read_b128 v[88:91], v25 offset:656
	ds_read_b128 v[84:87], v25 offset:640
	.loc	1 2249 75                       ; matmul_kernel.py:2249:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[44:47], v[188:195], v[76:83], a[44:47], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[60:63], v[196:203], v[76:83], a[60:63], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[56:59], v[204:211], v[76:83], a[56:59], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[12:15], v[180:187], v[68:75], a[12:15], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[8:11], v[188:195], v[68:75], a[8:11], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[0:3], v[196:203], v[68:75], a[0:3], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[4:7], v[204:211], v[68:75], a[4:7], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[16:19], v[180:187], v[60:67], a[16:19], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[24:27], v[188:195], v[60:67], a[24:27], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[28:31], v[196:203], v[60:67], a[28:31], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[48:51], v[204:211], v[60:67], a[48:51], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[20:23], v[180:187], v[52:59], a[20:23], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[96:99], v[188:195], v[52:59], a[96:99], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[92:95], v[196:203], v[52:59], a[92:95], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[88:91], v[204:211], v[52:59], a[88:91], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[84:87], v[180:187], v[44:51], a[84:87], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[80:83], v[188:195], v[44:51], a[80:83], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[76:79], v[196:203], v[44:51], a[76:79], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[72:75], v[204:211], v[44:51], a[72:75], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	; sched_barrier mask(0x00000000)
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	s_waitcnt lgkmcnt(6)
	v_mfma_scale_f32_16x16x128_f8f6f4 a[252:255], v[92:99], v[116:123], a[252:255], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	s_mov_b32 m0, s42
	.loc	1 2264 36                       ; matmul_kernel.py:2264:36
	s_waitcnt vmcnt(16) lgkmcnt(0)
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[248:251], v[100:107], v[116:123], a[248:251], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2264 36                       ; matmul_kernel.py:2264:36
	s_barrier
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	s_waitcnt lgkmcnt(0)
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[180:183], v26
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[244:247], v[124:131], v[116:123], a[244:247], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[184:187], v26 offset:16
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	s_and_b32 s1, s56, 0xffff
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[192:195], v26 offset:144
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[240:243], v[84:91], v[116:123], a[240:243], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[188:191], v26 offset:128
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	s_mov_b32 s0, s55
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[200:203], v26 offset:528
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[236:239], v[92:99], v[108:115], a[236:239], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[196:199], v26 offset:512
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	s_mov_b32 s2, s18
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[208:211], v26 offset:656
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[232:235], v[100:107], v[108:115], a[232:235], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2266 67                       ; matmul_kernel.py:2266:67
	ds_read_b128 v[204:207], v26 offset:640
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	s_mov_b32 s3, s19
	buffer_load_dwordx4 v31, s[0:3], 0 offen lds
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[228:231], v[124:131], v[108:115], a[228:231], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	s_mov_b32 m0, s44
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[224:227], v[84:91], v[108:115], a[224:227], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	buffer_load_dwordx4 v38, s[0:3], 0 offen lds
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[220:223], v[92:99], v[132:139], a[220:223], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	s_mov_b32 m0, s43
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[216:219], v[100:107], v[132:139], a[216:219], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	buffer_load_dwordx4 v36, s[0:3], 0 offen lds
	s_mov_b32 m0, s45
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[212:215], v[124:131], v[132:139], a[212:215], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[208:211], v[84:91], v[132:139], a[208:211], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	buffer_load_dwordx4 v34, s[0:3], 0 offen lds
	s_mov_b32 m0, s46
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[204:207], v[92:99], v[172:179], a[204:207], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[200:203], v[100:107], v[172:179], a[200:203], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	buffer_load_dwordx4 v37, s[0:3], 0 offen lds
	s_mov_b32 m0, s47
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[196:199], v[124:131], v[172:179], a[196:199], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[192:195], v[84:91], v[172:179], a[192:195], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	buffer_load_dwordx4 v35, s[0:3], 0 offen lds
	s_mov_b32 m0, s48
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[188:191], v[92:99], v[164:171], a[188:191], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[184:187], v[100:107], v[164:171], a[184:187], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	buffer_load_dwordx4 v32, s[0:3], 0 offen lds
	s_mov_b32 m0, s36
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[180:183], v[124:131], v[164:171], a[180:183], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[176:179], v[84:91], v[164:171], a[176:179], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2268 71                       ; matmul_kernel.py:2268:71
	buffer_load_dwordx4 v33, s[0:3], 0 offen lds
	.loc	1 2269 72                       ; matmul_kernel.py:2269:72
	s_mov_b32 m0, s34
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[172:175], v[92:99], v[156:163], a[172:175], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[168:171], v[100:107], v[156:163], a[168:171], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2269 72                       ; matmul_kernel.py:2269:72
	buffer_load_dwordx4 v30, s[16:19], 0 offen lds
	s_mov_b32 m0, s35
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[164:167], v[124:131], v[156:163], a[164:167], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[160:163], v[84:91], v[156:163], a[160:163], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2269 72                       ; matmul_kernel.py:2269:72
	buffer_load_dwordx4 v28, s[16:19], 0 offen lds
	s_mov_b32 m0, s37
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[156:159], v[92:99], v[148:155], a[156:159], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[152:155], v[100:107], v[148:155], a[152:155], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2269 72                       ; matmul_kernel.py:2269:72
	buffer_load_dwordx4 v29, s[16:19], 0 offen lds
	s_mov_b32 m0, s33
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[148:151], v[124:131], v[148:155], a[148:151], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[144:147], v[84:91], v[148:155], a[144:147], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2269 72                       ; matmul_kernel.py:2269:72
	buffer_load_dwordx4 v27, s[16:19], 0 offen lds
	.loc	1 2265 75                       ; matmul_kernel.py:2265:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[140:143], v[92:99], v[140:147], a[140:143], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[136:139], v[100:107], v[140:147], a[136:139], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[132:135], v[124:131], v[140:147], a[132:135], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[128:131], v[84:91], v[140:147], a[128:131], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	; sched_barrier mask(0x00000000)
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	s_waitcnt lgkmcnt(6)
	v_mfma_scale_f32_16x16x128_f8f6f4 a[64:67], v[180:187], v[116:123], a[64:67], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	s_mov_b32 m0, s52
	.loc	1 2280 36                       ; matmul_kernel.py:2280:36
	s_waitcnt vmcnt(16) lgkmcnt(0)
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[124:127], v[188:195], v[116:123], a[124:127], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2280 36                       ; matmul_kernel.py:2280:36
	s_barrier
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	s_waitcnt lgkmcnt(0)
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[100:103], v20
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[104:107], v[196:203], v[116:123], a[104:107], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[104:107], v20 offset:16
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	s_add_u32 s49, s49, 0x100
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[96:99], v20 offset:144
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[112:115], v[204:211], v[116:123], a[112:115], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[92:95], v20 offset:128
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	s_addc_u32 s50, s50, 0
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[88:91], v20 offset:528
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[100:103], v[180:187], v[108:115], a[100:103], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[84:87], v20 offset:512
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	s_and_b32 s17, s50, 0xffff
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[80:83], v20 offset:656
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[108:111], v[188:195], v[108:115], a[108:111], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[76:79], v20 offset:640
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	s_mov_b32 s16, s49
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[72:75], v20 offset:16912
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[116:119], v[196:203], v[108:115], a[116:119], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[68:71], v20 offset:16896
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	buffer_load_dwordx4 v41, s[16:19], 0 offen lds
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[120:123], v[204:211], v[108:115], a[120:123], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	s_mov_b32 m0, s54
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[64:67], v20 offset:17040
	ds_read_b128 v[60:63], v20 offset:17024
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[68:71], v[180:187], v[132:139], a[68:71], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[56:59], v20 offset:17424
	ds_read_b128 v[52:55], v20 offset:17408
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[52:55], v[188:195], v[132:139], a[52:55], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	buffer_load_dwordx4 v42, s[16:19], 0 offen lds
	s_mov_b32 m0, s53
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[32:35], v[196:203], v[132:139], a[32:35], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2282 65                       ; matmul_kernel.py:2282:65
	ds_read_b128 v[48:51], v20 offset:17552
	ds_read_b128 v[44:47], v20 offset:17536
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[36:39], v[204:211], v[132:139], a[36:39], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2283 67                       ; matmul_kernel.py:2283:67
	ds_read_b128 v[108:111], v23
	ds_read_b128 v[112:115], v23 offset:16
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	buffer_load_dwordx4 v39, s[16:19], 0 offen lds
	.loc	1 2283 67                       ; matmul_kernel.py:2283:67
	ds_read_b128 v[120:123], v23 offset:144
	ds_read_b128 v[116:119], v23 offset:128
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	s_mov_b32 m0, s51
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[40:43], v[180:187], v[172:179], a[40:43], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2283 67                       ; matmul_kernel.py:2283:67
	ds_read_b128 v[128:131], v23 offset:528
	ds_read_b128 v[124:127], v23 offset:512
	.loc	1 2285 72                       ; matmul_kernel.py:2285:72
	buffer_load_dwordx4 v40, s[16:19], 0 offen lds
	.loc	1 2283 67                       ; matmul_kernel.py:2283:67
	ds_read_b128 v[136:139], v23 offset:656
	ds_read_b128 v[132:135], v23 offset:640
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[44:47], v[188:195], v[172:179], a[44:47], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2288 36                       ; matmul_kernel.py:2288:36
	s_waitcnt vmcnt(16) lgkmcnt(0)
	s_barrier
	.loc	1 2281 75                       ; matmul_kernel.py:2281:75
	v_mfma_scale_f32_16x16x128_f8f6f4 a[60:63], v[196:203], v[172:179], a[60:63], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[56:59], v[204:211], v[172:179], a[56:59], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[12:15], v[180:187], v[164:171], a[12:15], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[8:11], v[188:195], v[164:171], a[8:11], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[0:3], v[196:203], v[164:171], a[0:3], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[4:7], v[204:211], v[164:171], a[4:7], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[16:19], v[180:187], v[156:163], a[16:19], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[24:27], v[188:195], v[156:163], a[24:27], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[28:31], v[196:203], v[156:163], a[28:31], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[48:51], v[204:211], v[156:163], a[48:51], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[20:23], v[180:187], v[148:155], a[20:23], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[96:99], v[188:195], v[148:155], a[96:99], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[92:95], v[196:203], v[148:155], a[92:95], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[88:91], v[204:211], v[148:155], a[88:91], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[84:87], v[180:187], v[140:147], a[84:87], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[80:83], v[188:195], v[140:147], a[80:83], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[76:79], v[196:203], v[140:147], a[76:79], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	v_mfma_scale_f32_16x16x128_f8f6f4 a[72:75], v[204:211], v[140:147], a[72:75], v21, v21 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	; sched_barrier mask(0x00000000)
	.loc	1 2226 35                       ; matmul_kernel.py:2226:35
	s_add_u32 s55, s55, 0x100
	s_addc_u32 s56, s56, 0
	s_add_i32 s10, s10, 2
	s_cmp_lt_u32 s10, 29
	s_cbranch_scc1 .LBB0_1
; %bb.2:
	.loc	1 2291 32                       ; matmul_kernel.py:2291:32
	s_waitcnt vmcnt(0) lgkmcnt(0)
	s_barrier
	.loc	1 2296 47                       ; matmul_kernel.py:2296:47
	v_lshrrev_b32_e32 v2, 4, v4
	.loc	1 2302 41                       ; matmul_kernel.py:2302:41
	s_mul_i32 s0, s9, s12
	.loc	1 2302 23 is_stmt 0             ; matmul_kernel.py:2302:23
	s_ashr_i32 s1, s0, 31
	s_lshl_b64 s[0:1], s[0:1], 1
	s_add_u32 s2, s6, s0
	s_addc_u32 s3, s7, s1
	.loc	1 2302 53                       ; matmul_kernel.py:2302:53
	s_ashr_i32 s9, s8, 31
	s_lshl_b64 s[0:1], s[8:9], 1
	s_add_u32 s4, s2, s0
	s_addc_u32 s6, s3, s1
	.loc	1 2303 31 is_stmt 1             ; matmul_kernel.py:2303:31
	s_lshl_b32 s0, s12, 6
	.loc	1 2303 26 is_stmt 0             ; matmul_kernel.py:2303:26
	s_ashr_i32 s1, s0, 31
	s_lshl_b64 s[0:1], s[0:1], 1
	s_add_u32 s28, s4, s0
	s_addc_u32 s14, s6, s1
	.loc	1 2304 26 is_stmt 1             ; matmul_kernel.py:2304:26
	s_add_u32 s24, s28, s0
	s_addc_u32 s11, s14, s1
	.loc	1 2305 26                       ; matmul_kernel.py:2305:26
	s_add_u32 s20, s24, s0
	s_addc_u32 s10, s11, s1
	.loc	1 2306 34                       ; matmul_kernel.py:2306:34
	v_mul_lo_u32 v2, v2, s12
	s_lshl_b32 s15, s12, 4
	.loc	1 2306 59 is_stmt 0             ; matmul_kernel.py:2306:59
	v_lshl_add_u32 v23, v3, 3, v2
	v_add_u32_e32 v24, s15, v23
	v_add_u32_e32 v25, s15, v24
	.loc	1 2308 26 is_stmt 1             ; matmul_kernel.py:2308:26
	s_add_u32 s16, s4, 0x100
	s_addc_u32 s9, s6, 0
	.loc	1 2309 26                       ; matmul_kernel.py:2309:26
	s_add_u32 s12, s28, 0x100
	s_addc_u32 s3, s14, 0
	.loc	1 2310 26                       ; matmul_kernel.py:2310:26
	s_add_u32 s8, s24, 0x100
	s_addc_u32 s2, s11, 0
	.loc	1 2311 26                       ; matmul_kernel.py:2311:26
	s_add_u32 s0, s20, 0x100
	s_addc_u32 s1, s10, 0
	v_mov_b32_e32 v2, 0x7f
	.loc	1 2322 28                       ; matmul_kernel.py:2322:28
	v_lshlrev_b32_e32 v5, 8, v0
	v_lshlrev_b32_e32 v26, 3, v0
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[252:255], v[108:115], v[100:107], a[252:255], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2322 28                       ; matmul_kernel.py:2322:28
	v_and_b32_e32 v27, 0x70, v26
	s_lshr_b32 s5, s5, 1
	s_and_b32 s7, s13, 0x80
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[248:251], v[116:123], v[100:107], a[248:251], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	s_movk_i32 s13, 0x2e00
	.loc	1 2322 28                       ; matmul_kernel.py:2322:28
	v_and_b32_e32 v4, 0xe0, v4
	.loc	1 2331 62                       ; matmul_kernel.py:2331:62
	s_and_b32 s29, s14, 0xffff
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[244:247], v[124:131], v[100:107], a[244:247], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2321 19                       ; matmul_kernel.py:2321:19
	v_accvgpr_read_b32 v6, a252
	v_accvgpr_read_b32 v3, a253
	v_cvt_pk_f16_f32 v6, v6, v3
	v_accvgpr_read_b32 v8, a254
	v_accvgpr_read_b32 v3, a255
	v_cvt_pk_f16_f32 v7, v8, v3
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[240:243], v[132:139], v[100:107], a[240:243], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2321 19                       ; matmul_kernel.py:2321:19
	v_accvgpr_read_b32 v8, a248
	v_accvgpr_read_b32 v3, a249
	v_cvt_pk_f16_f32 v10, v8, v3
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[236:239], v[108:115], v[92:99], a[236:239], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2321 19                       ; matmul_kernel.py:2321:19
	v_accvgpr_read_b32 v8, a250
	v_accvgpr_read_b32 v3, a251
	v_cvt_pk_f16_f32 v11, v8, v3
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[232:235], v[116:123], v[92:99], a[232:235], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2321 19                       ; matmul_kernel.py:2321:19
	v_accvgpr_read_b32 v8, a244
	v_accvgpr_read_b32 v3, a245
	v_cvt_pk_f16_f32 v14, v8, v3
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[228:231], v[124:131], v[92:99], a[228:231], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2321 19                       ; matmul_kernel.py:2321:19
	v_accvgpr_read_b32 v8, a246
	v_accvgpr_read_b32 v3, a247
	v_cvt_pk_f16_f32 v15, v8, v3
	.loc	1 2320 73                       ; matmul_kernel.py:2320:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[224:227], v[132:139], v[92:99], a[224:227], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2321 19                       ; matmul_kernel.py:2321:19
	v_accvgpr_read_b32 v8, a240
	v_accvgpr_read_b32 v3, a241
	v_cvt_pk_f16_f32 v18, v8, v3
	v_accvgpr_read_b32 v8, a242
	v_accvgpr_read_b32 v3, a243
	v_cvt_pk_f16_f32 v19, v8, v3
	v_accvgpr_read_b32 v8, a236
	v_accvgpr_read_b32 v3, a237
	v_cvt_pk_f16_f32 v8, v8, v3
	v_accvgpr_read_b32 v12, a238
	v_accvgpr_read_b32 v3, a239
	v_cvt_pk_f16_f32 v9, v12, v3
	v_accvgpr_read_b32 v12, a232
	v_accvgpr_read_b32 v3, a233
	v_cvt_pk_f16_f32 v12, v12, v3
	v_accvgpr_read_b32 v16, a234
	v_accvgpr_read_b32 v3, a235
	v_cvt_pk_f16_f32 v13, v16, v3
	v_accvgpr_read_b32 v16, a228
	v_accvgpr_read_b32 v3, a229
	v_cvt_pk_f16_f32 v16, v16, v3
	v_accvgpr_read_b32 v20, a230
	v_accvgpr_read_b32 v3, a231
	v_cvt_pk_f16_f32 v17, v20, v3
	v_accvgpr_read_b32 v20, a224
	v_accvgpr_read_b32 v3, a225
	v_cvt_pk_f16_f32 v20, v20, v3
	v_accvgpr_read_b32 v22, a226
	v_accvgpr_read_b32 v3, a227
	v_cvt_pk_f16_f32 v21, v22, v3
	.loc	1 2322 28                       ; matmul_kernel.py:2322:28
	v_and_b32_e32 v22, 1, v0
	v_lshlrev_b32_e32 v3, 12, v22
	v_and_b32_e32 v0, 16, v0
	v_lshlrev_b32_e32 v28, 4, v0
	v_and_or_b32 v3, v5, s13, v3
	v_or3_b32 v28, s7, v28, v3
	v_mov_b32_e32 v3, 0x70
	v_bitop3_b32 v26, s5, v26, v3 bitop3:0x78
	v_or_b32_e32 v5, v28, v26
	v_add_u32_e32 v3, 0, v5
	ds_write_b128 v3, v[6:9]
	v_xad_u32 v6, v5, 16, 0
	ds_write_b128 v6, v[10:13]
	v_xad_u32 v5, v5, 64, 0
	ds_write_b128 v5, v[14:17]
	s_movk_i32 s5, 0x50
	v_bitop3_b32 v7, v28, s5, v26 bitop3:0x36
	v_add_u32_e32 v7, 0, v7
	ds_write_b128 v7, v[18:21]
	s_waitcnt lgkmcnt(0)
	s_barrier
	v_lshlrev_b32_e32 v8, 4, v4
	v_lshrrev_b32_e32 v4, 1, v4
	v_lshlrev_b32_e32 v0, 8, v0
	v_bitop3_b32 v4, v8, v4, v27 bitop3:0x36
	v_lshl_add_u32 v8, v22, 13, 0
	v_add3_u32 v9, v8, v0, v4
	ds_read_b128 v[10:13], v9
	ds_read_b128 v[14:17], v9 offset:256
	.loc	1 2323 62                       ; matmul_kernel.py:2323:62
	s_and_b32 s5, s6, 0xffff
	s_mov_b32 s7, 0x27000
	.loc	1 2322 28                       ; matmul_kernel.py:2322:28
	ds_read_b128 v[18:21], v9 offset:128
	ds_read_b128 v[26:29], v9 offset:384
	s_mov_b32 s6, 0x7ffffffe
	.loc	1 2323 62                       ; matmul_kernel.py:2323:62
	s_waitcnt lgkmcnt(3)
	v_mov_b32_e32 v30, v10
	v_mov_b32_e32 v31, v11
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v32, v14
	v_mov_b32_e32 v33, v15
	v_lshlrev_b32_e32 v0, 1, v23
	buffer_store_dwordx4 v[30:33], v0, s[4:7], 0 offen
	v_mov_b32_e32 v14, v12
	v_mov_b32_e32 v15, v13
	v_lshlrev_b32_e32 v4, 1, v24
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v30, v18
	v_mov_b32_e32 v31, v19
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v32, v26
	buffer_store_dwordx4 v[14:17], v4, s[4:7], 0 offen
	v_mov_b32_e32 v33, v27
	v_lshlrev_b32_e32 v8, 1, v25
	v_mov_b32_e32 v26, v20
	v_mov_b32_e32 v27, v21
	v_add_lshl_u32 v10, v25, s15, 1
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[220:223], v[108:115], v[84:91], a[220:223], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2323 62                       ; matmul_kernel.py:2323:62
	buffer_store_dwordx4 v[30:33], v8, s[4:7], 0 offen
	.loc	1 2331 62                       ; matmul_kernel.py:2331:62
	s_mov_b32 s30, s6
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[216:219], v[116:123], v[84:91], a[216:219], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2331 62                       ; matmul_kernel.py:2331:62
	s_mov_b32 s31, s7
	.loc	1 2339 62                       ; matmul_kernel.py:2339:62
	s_and_b32 s25, s11, 0xffff
	s_mov_b32 s26, s6
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[212:215], v[124:131], v[84:91], a[212:215], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2329 19                       ; matmul_kernel.py:2329:19
	s_nop 0
	v_accvgpr_read_b32 v12, a220
	v_accvgpr_read_b32 v11, a221
	v_cvt_pk_f16_f32 v12, v12, v11
	.loc	1 2323 62                       ; matmul_kernel.py:2323:62
	buffer_store_dwordx4 v[26:29], v10, s[4:7], 0 offen
	.loc	1 2329 19                       ; matmul_kernel.py:2329:19
	v_accvgpr_read_b32 v14, a222
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[208:211], v[132:139], v[84:91], a[208:211], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2329 19                       ; matmul_kernel.py:2329:19
	v_accvgpr_read_b32 v11, a223
	v_cvt_pk_f16_f32 v13, v14, v11
	v_accvgpr_read_b32 v14, a216
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[204:207], v[108:115], v[76:83], a[204:207], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2329 19                       ; matmul_kernel.py:2329:19
	v_accvgpr_read_b32 v11, a217
	v_cvt_pk_f16_f32 v16, v14, v11
	v_accvgpr_read_b32 v14, a218
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[200:203], v[116:123], v[76:83], a[200:203], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2329 19                       ; matmul_kernel.py:2329:19
	v_accvgpr_read_b32 v11, a219
	v_cvt_pk_f16_f32 v17, v14, v11
	v_accvgpr_read_b32 v14, a212
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[196:199], v[124:131], v[76:83], a[196:199], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2329 19                       ; matmul_kernel.py:2329:19
	v_accvgpr_read_b32 v11, a213
	v_cvt_pk_f16_f32 v20, v14, v11
	v_accvgpr_read_b32 v14, a214
	.loc	1 2328 73                       ; matmul_kernel.py:2328:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[192:195], v[132:139], v[76:83], a[192:195], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2329 19                       ; matmul_kernel.py:2329:19
	v_accvgpr_read_b32 v11, a215
	v_cvt_pk_f16_f32 v21, v14, v11
	v_accvgpr_read_b32 v14, a208
	v_accvgpr_read_b32 v11, a209
	v_cvt_pk_f16_f32 v24, v14, v11
	v_accvgpr_read_b32 v14, a210
	v_accvgpr_read_b32 v11, a211
	v_cvt_pk_f16_f32 v25, v14, v11
	v_accvgpr_read_b32 v14, a204
	v_accvgpr_read_b32 v11, a205
	v_cvt_pk_f16_f32 v14, v14, v11
	v_accvgpr_read_b32 v18, a206
	v_accvgpr_read_b32 v11, a207
	v_cvt_pk_f16_f32 v15, v18, v11
	v_accvgpr_read_b32 v18, a200
	v_accvgpr_read_b32 v11, a201
	v_cvt_pk_f16_f32 v18, v18, v11
	v_accvgpr_read_b32 v22, a202
	v_accvgpr_read_b32 v11, a203
	v_cvt_pk_f16_f32 v19, v22, v11
	v_accvgpr_read_b32 v22, a196
	v_accvgpr_read_b32 v11, a197
	v_cvt_pk_f16_f32 v22, v22, v11
	v_accvgpr_read_b32 v26, a198
	v_accvgpr_read_b32 v11, a199
	v_cvt_pk_f16_f32 v23, v26, v11
	v_accvgpr_read_b32 v26, a192
	v_accvgpr_read_b32 v11, a193
	v_cvt_pk_f16_f32 v26, v26, v11
	v_accvgpr_read_b32 v28, a194
	v_accvgpr_read_b32 v11, a195
	v_cvt_pk_f16_f32 v27, v28, v11
	.loc	1 2330 28                       ; matmul_kernel.py:2330:28
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_write_b128 v3, v[12:15]
	ds_write_b128 v6, v[16:19]
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[188:191], v[108:115], v[68:75], a[188:191], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2339 62                       ; matmul_kernel.py:2339:62
	s_mov_b32 s27, s7
	.loc	1 2330 28                       ; matmul_kernel.py:2330:28
	ds_write_b128 v5, v[20:23]
	ds_write_b128 v7, v[24:27]
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_read_b128 v[12:15], v9
	ds_read_b128 v[16:19], v9 offset:256
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[184:187], v[116:123], v[68:75], a[184:187], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v11, a189
	.loc	1 2330 28                       ; matmul_kernel.py:2330:28
	ds_read_b128 v[20:23], v9 offset:128
	ds_read_b128 v[24:27], v9 offset:384
	.loc	1 2331 62                       ; matmul_kernel.py:2331:62
	s_waitcnt lgkmcnt(3)
	v_mov_b32_e32 v28, v12
	v_mov_b32_e32 v29, v13
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v30, v16
	v_mov_b32_e32 v31, v17
	buffer_store_dwordx4 v[28:31], v0, s[28:31], 0 offen
	v_mov_b32_e32 v16, v14
	v_mov_b32_e32 v17, v15
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v28, v20
	v_mov_b32_e32 v29, v21
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v30, v24
	v_mov_b32_e32 v31, v25
	buffer_store_dwordx4 v[16:19], v4, s[28:31], 0 offen
	v_mov_b32_e32 v24, v22
	v_mov_b32_e32 v25, v23
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v12, a188
	v_cvt_pk_f16_f32 v12, v12, v11
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[180:183], v[124:131], v[68:75], a[180:183], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v14, a190
	.loc	1 2331 62                       ; matmul_kernel.py:2331:62
	buffer_store_dwordx4 v[28:31], v8, s[28:31], 0 offen
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v11, a191
	v_cvt_pk_f16_f32 v13, v14, v11
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[176:179], v[132:139], v[68:75], a[176:179], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v14, a184
	v_accvgpr_read_b32 v11, a185
	v_cvt_pk_f16_f32 v16, v14, v11
	.loc	1 2331 62                       ; matmul_kernel.py:2331:62
	buffer_store_dwordx4 v[24:27], v10, s[28:31], 0 offen
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[172:175], v[108:115], v[60:67], a[172:175], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v14, a186
	v_accvgpr_read_b32 v11, a187
	v_cvt_pk_f16_f32 v17, v14, v11
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[168:171], v[116:123], v[60:67], a[168:171], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v14, a180
	v_accvgpr_read_b32 v11, a181
	v_cvt_pk_f16_f32 v20, v14, v11
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[164:167], v[124:131], v[60:67], a[164:167], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v14, a182
	v_accvgpr_read_b32 v11, a183
	v_cvt_pk_f16_f32 v21, v14, v11
	.loc	1 2336 73                       ; matmul_kernel.py:2336:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[160:163], v[132:139], v[60:67], a[160:163], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2337 19                       ; matmul_kernel.py:2337:19
	v_accvgpr_read_b32 v14, a176
	v_accvgpr_read_b32 v11, a177
	v_cvt_pk_f16_f32 v24, v14, v11
	v_accvgpr_read_b32 v14, a178
	v_accvgpr_read_b32 v11, a179
	v_cvt_pk_f16_f32 v25, v14, v11
	v_accvgpr_read_b32 v14, a172
	v_accvgpr_read_b32 v11, a173
	v_cvt_pk_f16_f32 v14, v14, v11
	v_accvgpr_read_b32 v18, a174
	v_accvgpr_read_b32 v11, a175
	v_cvt_pk_f16_f32 v15, v18, v11
	v_accvgpr_read_b32 v18, a168
	v_accvgpr_read_b32 v11, a169
	v_cvt_pk_f16_f32 v18, v18, v11
	v_accvgpr_read_b32 v22, a170
	v_accvgpr_read_b32 v11, a171
	v_cvt_pk_f16_f32 v19, v22, v11
	v_accvgpr_read_b32 v22, a164
	v_accvgpr_read_b32 v11, a165
	v_cvt_pk_f16_f32 v22, v22, v11
	v_accvgpr_read_b32 v26, a166
	v_accvgpr_read_b32 v11, a167
	v_cvt_pk_f16_f32 v23, v26, v11
	v_accvgpr_read_b32 v26, a160
	v_accvgpr_read_b32 v11, a161
	v_cvt_pk_f16_f32 v26, v26, v11
	v_accvgpr_read_b32 v28, a162
	v_accvgpr_read_b32 v11, a163
	v_cvt_pk_f16_f32 v27, v28, v11
	.loc	1 2338 28                       ; matmul_kernel.py:2338:28
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_write_b128 v3, v[12:15]
	ds_write_b128 v6, v[16:19]
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[156:159], v[108:115], v[52:59], a[156:159], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2347 62                       ; matmul_kernel.py:2347:62
	s_and_b32 s21, s10, 0xffff
	.loc	1 2338 28                       ; matmul_kernel.py:2338:28
	ds_write_b128 v5, v[20:23]
	ds_write_b128 v7, v[24:27]
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_read_b128 v[12:15], v9
	ds_read_b128 v[16:19], v9 offset:256
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[152:155], v[116:123], v[52:59], a[152:155], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v11, a157
	.loc	1 2338 28                       ; matmul_kernel.py:2338:28
	ds_read_b128 v[20:23], v9 offset:128
	ds_read_b128 v[24:27], v9 offset:384
	.loc	1 2339 62                       ; matmul_kernel.py:2339:62
	s_waitcnt lgkmcnt(3)
	v_mov_b32_e32 v28, v12
	v_mov_b32_e32 v29, v13
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v30, v16
	v_mov_b32_e32 v31, v17
	buffer_store_dwordx4 v[28:31], v0, s[24:27], 0 offen
	v_mov_b32_e32 v16, v14
	v_mov_b32_e32 v17, v15
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v28, v20
	v_mov_b32_e32 v29, v21
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v30, v24
	v_mov_b32_e32 v31, v25
	buffer_store_dwordx4 v[16:19], v4, s[24:27], 0 offen
	v_mov_b32_e32 v24, v22
	v_mov_b32_e32 v25, v23
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v12, a156
	v_cvt_pk_f16_f32 v12, v12, v11
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[148:151], v[124:131], v[52:59], a[148:151], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v14, a158
	.loc	1 2339 62                       ; matmul_kernel.py:2339:62
	buffer_store_dwordx4 v[28:31], v8, s[24:27], 0 offen
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v11, a159
	v_cvt_pk_f16_f32 v13, v14, v11
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[144:147], v[132:139], v[52:59], a[144:147], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v14, a152
	v_accvgpr_read_b32 v11, a153
	v_cvt_pk_f16_f32 v16, v14, v11
	.loc	1 2339 62                       ; matmul_kernel.py:2339:62
	buffer_store_dwordx4 v[24:27], v10, s[24:27], 0 offen
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[140:143], v[108:115], v[44:51], a[140:143], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v14, a154
	v_accvgpr_read_b32 v11, a155
	v_cvt_pk_f16_f32 v17, v14, v11
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[136:139], v[116:123], v[44:51], a[136:139], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v14, a148
	v_accvgpr_read_b32 v11, a149
	v_cvt_pk_f16_f32 v20, v14, v11
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[132:135], v[124:131], v[44:51], a[132:135], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v14, a150
	v_accvgpr_read_b32 v11, a151
	v_cvt_pk_f16_f32 v21, v14, v11
	.loc	1 2344 73                       ; matmul_kernel.py:2344:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[128:131], v[132:139], v[44:51], a[128:131], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2345 19                       ; matmul_kernel.py:2345:19
	v_accvgpr_read_b32 v14, a144
	v_accvgpr_read_b32 v11, a145
	v_cvt_pk_f16_f32 v24, v14, v11
	v_accvgpr_read_b32 v14, a146
	v_accvgpr_read_b32 v11, a147
	v_cvt_pk_f16_f32 v25, v14, v11
	v_accvgpr_read_b32 v14, a140
	v_accvgpr_read_b32 v11, a141
	v_cvt_pk_f16_f32 v14, v14, v11
	v_accvgpr_read_b32 v18, a142
	v_accvgpr_read_b32 v11, a143
	v_cvt_pk_f16_f32 v15, v18, v11
	v_accvgpr_read_b32 v18, a136
	v_accvgpr_read_b32 v11, a137
	v_cvt_pk_f16_f32 v18, v18, v11
	v_accvgpr_read_b32 v22, a138
	v_accvgpr_read_b32 v11, a139
	v_cvt_pk_f16_f32 v19, v22, v11
	v_accvgpr_read_b32 v22, a132
	v_accvgpr_read_b32 v11, a133
	v_cvt_pk_f16_f32 v22, v22, v11
	v_accvgpr_read_b32 v26, a134
	v_accvgpr_read_b32 v11, a135
	v_cvt_pk_f16_f32 v23, v26, v11
	v_accvgpr_read_b32 v26, a128
	v_accvgpr_read_b32 v11, a129
	v_cvt_pk_f16_f32 v26, v26, v11
	v_accvgpr_read_b32 v28, a130
	v_accvgpr_read_b32 v11, a131
	v_cvt_pk_f16_f32 v27, v28, v11
	.loc	1 2346 28                       ; matmul_kernel.py:2346:28
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_write_b128 v3, v[12:15]
	ds_write_b128 v6, v[16:19]
	.loc	1 2347 62                       ; matmul_kernel.py:2347:62
	s_mov_b32 s22, s6
	s_mov_b32 s23, s7
	.loc	1 2346 28                       ; matmul_kernel.py:2346:28
	ds_write_b128 v5, v[20:23]
	ds_write_b128 v7, v[24:27]
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_read_b128 v[12:15], v9
	ds_read_b128 v[16:19], v9 offset:256
	.loc	1 2350 67                       ; matmul_kernel.py:2350:67
	v_add_u32_e32 v1, 0x1cda0, v1
	.loc	1 2362 62                       ; matmul_kernel.py:2362:62
	s_and_b32 s17, s9, 0xffff
	.loc	1 2346 28                       ; matmul_kernel.py:2346:28
	ds_read_b128 v[20:23], v9 offset:128
	ds_read_b128 v[28:31], v9 offset:384
	.loc	1 2347 62                       ; matmul_kernel.py:2347:62
	s_waitcnt lgkmcnt(3)
	v_mov_b32_e32 v24, v12
	v_mov_b32_e32 v25, v13
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v26, v16
	v_mov_b32_e32 v27, v17
	buffer_store_dwordx4 v[24:27], v0, s[20:23], 0 offen
	v_mov_b32_e32 v16, v14
	v_mov_b32_e32 v17, v15
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v24, v20
	v_mov_b32_e32 v25, v21
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v26, v28
	v_mov_b32_e32 v27, v29
	buffer_store_dwordx4 v[16:19], v4, s[20:23], 0 offen
	v_mov_b32_e32 v28, v22
	v_mov_b32_e32 v29, v23
	.loc	1 2350 67                       ; matmul_kernel.py:2350:67
	ds_read_b128 v[12:15], v1
	ds_read_b128 v[16:19], v1 offset:16
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	s_waitcnt lgkmcnt(0)
	v_mfma_scale_f32_16x16x128_f8f6f4 a[64:67], v[12:19], v[100:107], a[64:67], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2347 62                       ; matmul_kernel.py:2347:62
	buffer_store_dwordx4 v[24:27], v8, s[20:23], 0 offen
	.loc	1 2350 67                       ; matmul_kernel.py:2350:67
	ds_read_b128 v[24:27], v1 offset:144
	ds_read_b128 v[20:23], v1 offset:128
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	s_waitcnt lgkmcnt(0)
	v_mfma_scale_f32_16x16x128_f8f6f4 a[124:127], v[20:27], v[100:107], a[124:127], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2347 62                       ; matmul_kernel.py:2347:62
	buffer_store_dwordx4 v[28:31], v10, s[20:23], 0 offen
	.loc	1 2350 67                       ; matmul_kernel.py:2350:67
	ds_read_b128 v[112:115], v1 offset:528
	ds_read_b128 v[108:111], v1 offset:512
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	s_waitcnt lgkmcnt(0)
	v_mfma_scale_f32_16x16x128_f8f6f4 a[104:107], v[108:115], v[100:107], a[104:107], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2350 67                       ; matmul_kernel.py:2350:67
	ds_read_b128 v[120:123], v1 offset:656
	ds_read_b128 v[116:119], v1 offset:640
	.loc	1 2360 19                       ; matmul_kernel.py:2360:19
	v_accvgpr_read_b32 v28, a64
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	s_waitcnt lgkmcnt(0)
	v_mfma_scale_f32_16x16x128_f8f6f4 a[112:115], v[116:123], v[100:107], a[112:115], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2360 19                       ; matmul_kernel.py:2360:19
	v_accvgpr_read_b32 v1, a65
	v_cvt_pk_f16_f32 v28, v28, v1
	v_accvgpr_read_b32 v30, a66
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[100:103], v[12:19], v[92:99], a[100:103], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2360 19                       ; matmul_kernel.py:2360:19
	v_accvgpr_read_b32 v1, a67
	v_cvt_pk_f16_f32 v29, v30, v1
	v_accvgpr_read_b32 v30, a124
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[108:111], v[20:27], v[92:99], a[108:111], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2360 19                       ; matmul_kernel.py:2360:19
	v_accvgpr_read_b32 v1, a125
	v_cvt_pk_f16_f32 v32, v30, v1
	v_accvgpr_read_b32 v30, a126
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[116:119], v[108:115], v[92:99], a[116:119], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2360 19                       ; matmul_kernel.py:2360:19
	v_accvgpr_read_b32 v1, a127
	v_cvt_pk_f16_f32 v33, v30, v1
	v_accvgpr_read_b32 v30, a104
	.loc	1 2359 73                       ; matmul_kernel.py:2359:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[120:123], v[116:123], v[92:99], a[120:123], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2360 19                       ; matmul_kernel.py:2360:19
	v_accvgpr_read_b32 v1, a105
	v_cvt_pk_f16_f32 v36, v30, v1
	v_accvgpr_read_b32 v30, a106
	v_accvgpr_read_b32 v1, a107
	v_cvt_pk_f16_f32 v37, v30, v1
	v_accvgpr_read_b32 v30, a112
	v_accvgpr_read_b32 v1, a113
	v_cvt_pk_f16_f32 v40, v30, v1
	v_accvgpr_read_b32 v30, a114
	v_accvgpr_read_b32 v1, a115
	v_cvt_pk_f16_f32 v41, v30, v1
	v_accvgpr_read_b32 v30, a100
	v_accvgpr_read_b32 v1, a101
	v_cvt_pk_f16_f32 v30, v30, v1
	v_accvgpr_read_b32 v34, a102
	v_accvgpr_read_b32 v1, a103
	v_cvt_pk_f16_f32 v31, v34, v1
	v_accvgpr_read_b32 v34, a108
	v_accvgpr_read_b32 v1, a109
	v_cvt_pk_f16_f32 v34, v34, v1
	v_accvgpr_read_b32 v38, a110
	v_accvgpr_read_b32 v1, a111
	v_cvt_pk_f16_f32 v35, v38, v1
	v_accvgpr_read_b32 v38, a116
	v_accvgpr_read_b32 v1, a117
	v_cvt_pk_f16_f32 v38, v38, v1
	v_accvgpr_read_b32 v42, a118
	v_accvgpr_read_b32 v1, a119
	v_cvt_pk_f16_f32 v39, v42, v1
	v_accvgpr_read_b32 v42, a120
	v_accvgpr_read_b32 v1, a121
	v_cvt_pk_f16_f32 v42, v42, v1
	v_accvgpr_read_b32 v92, a122
	v_accvgpr_read_b32 v1, a123
	v_cvt_pk_f16_f32 v43, v92, v1
	.loc	1 2361 28                       ; matmul_kernel.py:2361:28
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_write_b128 v3, v[28:31]
	ds_write_b128 v6, v[32:35]
	.loc	1 2362 62                       ; matmul_kernel.py:2362:62
	s_mov_b32 s18, s6
	s_mov_b32 s19, s7
	.loc	1 2361 28                       ; matmul_kernel.py:2361:28
	ds_write_b128 v5, v[36:39]
	ds_write_b128 v7, v[40:43]
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_read_b128 v[28:31], v9
	ds_read_b128 v[32:35], v9 offset:256
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[68:71], v[12:19], v[84:91], a[68:71], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2370 62                       ; matmul_kernel.py:2370:62
	s_and_b32 s13, s3, 0xffff
	.loc	1 2361 28                       ; matmul_kernel.py:2361:28
	ds_read_b128 v[36:39], v9 offset:128
	ds_read_b128 v[40:43], v9 offset:384
	.loc	1 2362 62                       ; matmul_kernel.py:2362:62
	s_waitcnt lgkmcnt(3)
	v_mov_b32_e32 v92, v28
	v_mov_b32_e32 v93, v29
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v94, v32
	v_mov_b32_e32 v95, v33
	buffer_store_dwordx4 v[92:95], v0, s[16:19], 0 offen
	v_mov_b32_e32 v32, v30
	v_mov_b32_e32 v33, v31
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v92, v36
	v_mov_b32_e32 v93, v37
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v94, v40
	v_mov_b32_e32 v95, v41
	buffer_store_dwordx4 v[32:35], v4, s[16:19], 0 offen
	v_mov_b32_e32 v40, v38
	v_mov_b32_e32 v41, v39
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[52:55], v[20:27], v[84:91], a[52:55], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2368 19                       ; matmul_kernel.py:2368:19
	v_accvgpr_read_b32 v28, a68
	v_accvgpr_read_b32 v1, a69
	v_cvt_pk_f16_f32 v28, v28, v1
	.loc	1 2362 62                       ; matmul_kernel.py:2362:62
	buffer_store_dwordx4 v[92:95], v8, s[16:19], 0 offen
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[32:35], v[108:115], v[84:91], a[32:35], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2368 19                       ; matmul_kernel.py:2368:19
	v_accvgpr_read_b32 v30, a70
	v_accvgpr_read_b32 v1, a71
	v_cvt_pk_f16_f32 v29, v30, v1
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[36:39], v[116:123], v[84:91], a[36:39], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2368 19                       ; matmul_kernel.py:2368:19
	v_accvgpr_read_b32 v30, a52
	.loc	1 2362 62                       ; matmul_kernel.py:2362:62
	buffer_store_dwordx4 v[40:43], v10, s[16:19], 0 offen
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[40:43], v[12:19], v[76:83], a[40:43], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2368 19                       ; matmul_kernel.py:2368:19
	v_accvgpr_read_b32 v1, a53
	v_cvt_pk_f16_f32 v32, v30, v1
	v_accvgpr_read_b32 v30, a54
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[44:47], v[20:27], v[76:83], a[44:47], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2368 19                       ; matmul_kernel.py:2368:19
	v_accvgpr_read_b32 v1, a55
	v_cvt_pk_f16_f32 v33, v30, v1
	v_accvgpr_read_b32 v30, a32
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[60:63], v[108:115], v[76:83], a[60:63], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2368 19                       ; matmul_kernel.py:2368:19
	v_accvgpr_read_b32 v1, a33
	v_cvt_pk_f16_f32 v36, v30, v1
	v_accvgpr_read_b32 v30, a34
	.loc	1 2367 73                       ; matmul_kernel.py:2367:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[56:59], v[116:123], v[76:83], a[56:59], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2368 19                       ; matmul_kernel.py:2368:19
	v_accvgpr_read_b32 v1, a35
	v_cvt_pk_f16_f32 v37, v30, v1
	v_accvgpr_read_b32 v30, a36
	v_accvgpr_read_b32 v1, a37
	v_cvt_pk_f16_f32 v40, v30, v1
	v_accvgpr_read_b32 v30, a38
	v_accvgpr_read_b32 v1, a39
	v_cvt_pk_f16_f32 v41, v30, v1
	v_accvgpr_read_b32 v30, a40
	v_accvgpr_read_b32 v1, a41
	v_cvt_pk_f16_f32 v30, v30, v1
	v_accvgpr_read_b32 v34, a42
	v_accvgpr_read_b32 v1, a43
	v_cvt_pk_f16_f32 v31, v34, v1
	v_accvgpr_read_b32 v34, a44
	v_accvgpr_read_b32 v1, a45
	v_cvt_pk_f16_f32 v34, v34, v1
	v_accvgpr_read_b32 v38, a46
	v_accvgpr_read_b32 v1, a47
	v_cvt_pk_f16_f32 v35, v38, v1
	v_accvgpr_read_b32 v38, a60
	v_accvgpr_read_b32 v1, a61
	v_cvt_pk_f16_f32 v38, v38, v1
	v_accvgpr_read_b32 v42, a62
	v_accvgpr_read_b32 v1, a63
	v_cvt_pk_f16_f32 v39, v42, v1
	v_accvgpr_read_b32 v42, a56
	v_accvgpr_read_b32 v1, a57
	v_cvt_pk_f16_f32 v42, v42, v1
	v_accvgpr_read_b32 v76, a58
	v_accvgpr_read_b32 v1, a59
	v_cvt_pk_f16_f32 v43, v76, v1
	.loc	1 2369 28                       ; matmul_kernel.py:2369:28
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_write_b128 v3, v[28:31]
	ds_write_b128 v6, v[32:35]
	.loc	1 2370 62                       ; matmul_kernel.py:2370:62
	s_mov_b32 s14, s6
	s_mov_b32 s15, s7
	.loc	1 2369 28                       ; matmul_kernel.py:2369:28
	ds_write_b128 v5, v[36:39]
	ds_write_b128 v7, v[40:43]
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_read_b128 v[28:31], v9
	ds_read_b128 v[32:35], v9 offset:256
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[12:15], v[12:19], v[68:75], a[12:15], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2378 62                       ; matmul_kernel.py:2378:62
	s_and_b32 s9, s2, 0xffff
	.loc	1 2369 28                       ; matmul_kernel.py:2369:28
	ds_read_b128 v[36:39], v9 offset:128
	ds_read_b128 v[40:43], v9 offset:384
	.loc	1 2370 62                       ; matmul_kernel.py:2370:62
	s_waitcnt lgkmcnt(3)
	v_mov_b32_e32 v76, v28
	v_mov_b32_e32 v77, v29
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v78, v32
	v_mov_b32_e32 v79, v33
	buffer_store_dwordx4 v[76:79], v0, s[12:15], 0 offen
	v_mov_b32_e32 v32, v30
	v_mov_b32_e32 v33, v31
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v76, v36
	v_mov_b32_e32 v77, v37
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v78, v40
	v_mov_b32_e32 v79, v41
	buffer_store_dwordx4 v[32:35], v4, s[12:15], 0 offen
	v_mov_b32_e32 v40, v38
	v_mov_b32_e32 v41, v39
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[8:11], v[20:27], v[68:75], a[8:11], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2376 19                       ; matmul_kernel.py:2376:19
	v_accvgpr_read_b32 v28, a12
	v_accvgpr_read_b32 v1, a13
	v_cvt_pk_f16_f32 v28, v28, v1
	.loc	1 2370 62                       ; matmul_kernel.py:2370:62
	buffer_store_dwordx4 v[76:79], v8, s[12:15], 0 offen
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[0:3], v[108:115], v[68:75], a[0:3], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2376 19                       ; matmul_kernel.py:2376:19
	v_accvgpr_read_b32 v30, a14
	v_accvgpr_read_b32 v1, a15
	v_cvt_pk_f16_f32 v29, v30, v1
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[4:7], v[116:123], v[68:75], a[4:7], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2376 19                       ; matmul_kernel.py:2376:19
	v_accvgpr_read_b32 v30, a8
	.loc	1 2370 62                       ; matmul_kernel.py:2370:62
	buffer_store_dwordx4 v[40:43], v10, s[12:15], 0 offen
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[16:19], v[12:19], v[60:67], a[16:19], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2376 19                       ; matmul_kernel.py:2376:19
	v_accvgpr_read_b32 v1, a9
	v_cvt_pk_f16_f32 v32, v30, v1
	v_accvgpr_read_b32 v30, a10
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[24:27], v[20:27], v[60:67], a[24:27], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2376 19                       ; matmul_kernel.py:2376:19
	v_accvgpr_read_b32 v1, a11
	v_cvt_pk_f16_f32 v33, v30, v1
	v_accvgpr_read_b32 v30, a0
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[28:31], v[108:115], v[60:67], a[28:31], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2376 19                       ; matmul_kernel.py:2376:19
	v_accvgpr_read_b32 v1, a1
	v_cvt_pk_f16_f32 v36, v30, v1
	v_accvgpr_read_b32 v30, a2
	.loc	1 2375 73                       ; matmul_kernel.py:2375:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[48:51], v[116:123], v[60:67], a[48:51], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2376 19                       ; matmul_kernel.py:2376:19
	v_accvgpr_read_b32 v1, a3
	v_cvt_pk_f16_f32 v37, v30, v1
	v_accvgpr_read_b32 v30, a4
	v_accvgpr_read_b32 v1, a5
	v_cvt_pk_f16_f32 v40, v30, v1
	v_accvgpr_read_b32 v30, a6
	v_accvgpr_read_b32 v1, a7
	v_cvt_pk_f16_f32 v41, v30, v1
	v_accvgpr_read_b32 v30, a16
	v_accvgpr_read_b32 v1, a17
	v_cvt_pk_f16_f32 v30, v30, v1
	v_accvgpr_read_b32 v34, a18
	v_accvgpr_read_b32 v1, a19
	v_cvt_pk_f16_f32 v31, v34, v1
	v_accvgpr_read_b32 v34, a24
	v_accvgpr_read_b32 v1, a25
	v_cvt_pk_f16_f32 v34, v34, v1
	v_accvgpr_read_b32 v38, a26
	v_accvgpr_read_b32 v1, a27
	v_cvt_pk_f16_f32 v35, v38, v1
	v_accvgpr_read_b32 v38, a28
	v_accvgpr_read_b32 v1, a29
	v_cvt_pk_f16_f32 v38, v38, v1
	v_accvgpr_read_b32 v42, a30
	v_accvgpr_read_b32 v1, a31
	v_cvt_pk_f16_f32 v39, v42, v1
	v_accvgpr_read_b32 v42, a48
	v_accvgpr_read_b32 v1, a49
	v_cvt_pk_f16_f32 v42, v42, v1
	v_accvgpr_read_b32 v60, a50
	v_accvgpr_read_b32 v1, a51
	v_cvt_pk_f16_f32 v43, v60, v1
	.loc	1 2377 28                       ; matmul_kernel.py:2377:28
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_write_b128 v3, v[28:31]
	ds_write_b128 v6, v[32:35]
	.loc	1 2378 62                       ; matmul_kernel.py:2378:62
	s_mov_b32 s10, s6
	s_mov_b32 s11, s7
	.loc	1 2377 28                       ; matmul_kernel.py:2377:28
	ds_write_b128 v5, v[36:39]
	ds_write_b128 v7, v[40:43]
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_read_b128 v[28:31], v9
	ds_read_b128 v[32:35], v9 offset:256
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[20:23], v[12:19], v[52:59], a[20:23], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2386 62                       ; matmul_kernel.py:2386:62
	s_and_b32 s1, s1, 0xffff
	.loc	1 2377 28                       ; matmul_kernel.py:2377:28
	ds_read_b128 v[36:39], v9 offset:128
	ds_read_b128 v[40:43], v9 offset:384
	.loc	1 2378 62                       ; matmul_kernel.py:2378:62
	s_waitcnt lgkmcnt(3)
	v_mov_b32_e32 v60, v28
	v_mov_b32_e32 v61, v29
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v62, v32
	v_mov_b32_e32 v63, v33
	buffer_store_dwordx4 v[60:63], v0, s[8:11], 0 offen
	v_mov_b32_e32 v32, v30
	v_mov_b32_e32 v33, v31
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v60, v36
	v_mov_b32_e32 v61, v37
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v62, v40
	v_mov_b32_e32 v63, v41
	buffer_store_dwordx4 v[32:35], v4, s[8:11], 0 offen
	v_mov_b32_e32 v40, v38
	v_mov_b32_e32 v41, v39
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[96:99], v[20:27], v[52:59], a[96:99], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2384 19                       ; matmul_kernel.py:2384:19
	v_accvgpr_read_b32 v28, a20
	v_accvgpr_read_b32 v1, a21
	v_cvt_pk_f16_f32 v28, v28, v1
	.loc	1 2378 62                       ; matmul_kernel.py:2378:62
	buffer_store_dwordx4 v[60:63], v8, s[8:11], 0 offen
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[92:95], v[108:115], v[52:59], a[92:95], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2384 19                       ; matmul_kernel.py:2384:19
	v_accvgpr_read_b32 v30, a22
	v_accvgpr_read_b32 v1, a23
	v_cvt_pk_f16_f32 v29, v30, v1
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[88:91], v[116:123], v[52:59], a[88:91], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2384 19                       ; matmul_kernel.py:2384:19
	v_accvgpr_read_b32 v30, a96
	.loc	1 2378 62                       ; matmul_kernel.py:2378:62
	buffer_store_dwordx4 v[40:43], v10, s[8:11], 0 offen
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[84:87], v[12:19], v[44:51], a[84:87], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2384 19                       ; matmul_kernel.py:2384:19
	v_accvgpr_read_b32 v1, a97
	v_cvt_pk_f16_f32 v12, v30, v1
	v_accvgpr_read_b32 v14, a98
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[80:83], v[20:27], v[44:51], a[80:83], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2384 19                       ; matmul_kernel.py:2384:19
	v_accvgpr_read_b32 v1, a99
	v_cvt_pk_f16_f32 v13, v14, v1
	v_accvgpr_read_b32 v14, a92
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[76:79], v[108:115], v[44:51], a[76:79], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2384 19                       ; matmul_kernel.py:2384:19
	v_accvgpr_read_b32 v1, a93
	v_cvt_pk_f16_f32 v16, v14, v1
	v_accvgpr_read_b32 v14, a94
	.loc	1 2383 73                       ; matmul_kernel.py:2383:73
	v_mfma_scale_f32_16x16x128_f8f6f4 a[72:75], v[116:123], v[44:51], a[72:75], v2, v2 op_sel_hi:[0,0,0] cbsz:1 blgp:1
	.loc	1 2384 19                       ; matmul_kernel.py:2384:19
	v_accvgpr_read_b32 v1, a95
	v_cvt_pk_f16_f32 v17, v14, v1
	v_accvgpr_read_b32 v2, a88
	v_accvgpr_read_b32 v1, a89
	v_cvt_pk_f16_f32 v20, v2, v1
	v_accvgpr_read_b32 v2, a90
	v_accvgpr_read_b32 v1, a91
	v_cvt_pk_f16_f32 v21, v2, v1
	v_accvgpr_read_b32 v2, a84
	v_accvgpr_read_b32 v1, a85
	v_cvt_pk_f16_f32 v30, v2, v1
	v_accvgpr_read_b32 v2, a86
	v_accvgpr_read_b32 v1, a87
	v_cvt_pk_f16_f32 v31, v2, v1
	v_accvgpr_read_b32 v2, a80
	v_accvgpr_read_b32 v1, a81
	v_cvt_pk_f16_f32 v14, v2, v1
	v_accvgpr_read_b32 v2, a82
	v_accvgpr_read_b32 v1, a83
	v_cvt_pk_f16_f32 v15, v2, v1
	v_accvgpr_read_b32 v2, a76
	v_accvgpr_read_b32 v1, a77
	v_cvt_pk_f16_f32 v18, v2, v1
	v_accvgpr_read_b32 v2, a78
	v_accvgpr_read_b32 v1, a79
	v_cvt_pk_f16_f32 v19, v2, v1
	v_accvgpr_read_b32 v2, a72
	v_accvgpr_read_b32 v1, a73
	v_cvt_pk_f16_f32 v22, v2, v1
	v_accvgpr_read_b32 v2, a74
	v_accvgpr_read_b32 v1, a75
	v_cvt_pk_f16_f32 v23, v2, v1
	.loc	1 2385 28                       ; matmul_kernel.py:2385:28
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_write_b128 v3, v[28:31]
	ds_write_b128 v6, v[12:15]
	.loc	1 2386 62                       ; matmul_kernel.py:2386:62
	s_mov_b32 s2, s6
	s_mov_b32 s3, s7
	.loc	1 2385 28                       ; matmul_kernel.py:2385:28
	ds_write_b128 v5, v[16:19]
	ds_write_b128 v7, v[20:23]
	s_waitcnt lgkmcnt(0)
	s_barrier
	ds_read_b128 v[12:15], v9
	ds_read_b128 v[16:19], v9 offset:256
	.loc	1 2386 62                       ; matmul_kernel.py:2386:62
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v20, v12
	.loc	1 2385 28                       ; matmul_kernel.py:2385:28
	ds_read_b128 v[24:27], v9 offset:128
	ds_read_b128 v[28:31], v9 offset:384
	.loc	1 2386 62                       ; matmul_kernel.py:2386:62
	v_mov_b32_e32 v21, v13
	s_waitcnt lgkmcnt(2)
	v_mov_b32_e32 v22, v16
	v_mov_b32_e32 v23, v17
	buffer_store_dwordx4 v[20:23], v0, s[0:3], 0 offen
	v_mov_b32_e32 v16, v14
	v_mov_b32_e32 v17, v15
	s_waitcnt lgkmcnt(1)
	v_mov_b32_e32 v12, v24
	v_mov_b32_e32 v13, v25
	s_waitcnt lgkmcnt(0)
	v_mov_b32_e32 v14, v28
	v_mov_b32_e32 v15, v29
	buffer_store_dwordx4 v[16:19], v4, s[0:3], 0 offen
	v_mov_b32_e32 v28, v26
	v_mov_b32_e32 v29, v27
	buffer_store_dwordx4 v[12:15], v8, s[0:3], 0 offen
	buffer_store_dwordx4 v[28:31], v10, s[0:3], 0 offen
	.loc	1 2387 62                       ; matmul_kernel.py:2387:62
	buffer_store_dwordx4 v[20:23], v0, s[0:3], 0 offen
	buffer_store_dwordx4 v[16:19], v4, s[0:3], 0 offen
	buffer_store_dwordx4 v[12:15], v8, s[0:3], 0 offen
	buffer_store_dwordx4 v[28:31], v10, s[0:3], 0 offen
	.loc	1 2387 4 is_stmt 0              ; matmul_kernel.py:2387:4
	s_endpgm
.Ltmp18:
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel v10_f8
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 0
		.amdhsa_kernarg_size 64
		.amdhsa_user_sgpr_count 16
		.amdhsa_user_sgpr_dispatch_ptr 0
		.amdhsa_user_sgpr_queue_ptr 0
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 0
		.amdhsa_user_sgpr_kernarg_preload_length 14
		.amdhsa_user_sgpr_kernarg_preload_offset 0
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 0
		.amdhsa_enable_private_segment 0
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 0
		.amdhsa_system_sgpr_workgroup_id_z 0
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 0
		.amdhsa_next_free_vgpr 468
		.amdhsa_next_free_sgpr 57
		.amdhsa_accum_offset 212
		.amdhsa_reserve_vcc 1
		.amdhsa_reserve_xnack_mask 1
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_tg_split 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end0:
	.size	v10_f8, .Lfunc_end0-v10_f8
	.cfi_endproc
                                        ; -- End function
	.set v10_f8.num_vgpr, 212
	.set v10_f8.num_agpr, 256
	.set v10_f8.numbered_sgpr, 57
	.set v10_f8.num_named_barrier, 0
	.set v10_f8.private_seg_size, 0
	.set v10_f8.uses_vcc, 1
	.set v10_f8.uses_flat_scratch, 0
	.set v10_f8.has_dyn_sized_stack, 0
	.set v10_f8.has_recursion, 0
	.set v10_f8.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 13276
; TotalNumSgprs: 63
; NumVgprs: 212
; NumAgprs: 256
; TotalNumVgprs: 468
; ScratchSize: 0
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 7
; VGPRBlocks: 58
; NumSGPRsForWavesPerEU: 63
; NumVGPRsForWavesPerEU: 468
; AccumOffset: 212
; Occupancy: 1
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 0
; COMPUTE_PGM_RSRC2:USER_SGPR: 16
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 0
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 0
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 0
; COMPUTE_PGM_RSRC3_GFX90A:ACCUM_OFFSET: 52
; COMPUTE_PGM_RSRC3_GFX90A:TG_SPLIT: 0
	.text
	.p2alignl 6, 3212836864
	.fill 256, 4, 3212836864
	.section	.AMDGPU.gpr_maximums,"",@progbits
	.set amdgpu.max_num_vgpr, 0
	.set amdgpu.max_num_agpr, 0
	.set amdgpu.max_num_sgpr, 0
	.set amdgpu.max_num_named_barrier, 0
	.text
	.section	.debug_abbrev,"",@progbits
	.byte	1                               ; Abbreviation Code
	.byte	17                              ; DW_TAG_compile_unit
	.byte	1                               ; DW_CHILDREN_yes
	.byte	37                              ; DW_AT_producer
	.byte	14                              ; DW_FORM_strp
	.byte	19                              ; DW_AT_language
	.byte	5                               ; DW_FORM_data2
	.byte	3                               ; DW_AT_name
	.byte	14                              ; DW_FORM_strp
	.byte	16                              ; DW_AT_stmt_list
	.byte	23                              ; DW_FORM_sec_offset
	.byte	27                              ; DW_AT_comp_dir
	.byte	14                              ; DW_FORM_strp
	.byte	17                              ; DW_AT_low_pc
	.byte	1                               ; DW_FORM_addr
	.byte	18                              ; DW_AT_high_pc
	.byte	6                               ; DW_FORM_data4
	.byte	0                               ; EOM(1)
	.byte	0                               ; EOM(2)
	.byte	2                               ; Abbreviation Code
	.byte	46                              ; DW_TAG_subprogram
	.byte	0                               ; DW_CHILDREN_no
	.byte	3                               ; DW_AT_name
	.byte	14                              ; DW_FORM_strp
	.byte	32                              ; DW_AT_inline
	.byte	11                              ; DW_FORM_data1
	.byte	0                               ; EOM(1)
	.byte	0                               ; EOM(2)
	.byte	3                               ; Abbreviation Code
	.byte	46                              ; DW_TAG_subprogram
	.byte	1                               ; DW_CHILDREN_yes
	.byte	17                              ; DW_AT_low_pc
	.byte	1                               ; DW_FORM_addr
	.byte	18                              ; DW_AT_high_pc
	.byte	6                               ; DW_FORM_data4
	.byte	49                              ; DW_AT_abstract_origin
	.byte	19                              ; DW_FORM_ref4
	.byte	0                               ; EOM(1)
	.byte	0                               ; EOM(2)
	.byte	4                               ; Abbreviation Code
	.byte	29                              ; DW_TAG_inlined_subroutine
	.byte	1                               ; DW_CHILDREN_yes
	.byte	49                              ; DW_AT_abstract_origin
	.byte	19                              ; DW_FORM_ref4
	.byte	85                              ; DW_AT_ranges
	.byte	23                              ; DW_FORM_sec_offset
	.byte	88                              ; DW_AT_call_file
	.byte	11                              ; DW_FORM_data1
	.byte	89                              ; DW_AT_call_line
	.byte	5                               ; DW_FORM_data2
	.byte	87                              ; DW_AT_call_column
	.byte	11                              ; DW_FORM_data1
	.byte	0                               ; EOM(1)
	.byte	0                               ; EOM(2)
	.byte	5                               ; Abbreviation Code
	.byte	29                              ; DW_TAG_inlined_subroutine
	.byte	0                               ; DW_CHILDREN_no
	.byte	49                              ; DW_AT_abstract_origin
	.byte	19                              ; DW_FORM_ref4
	.byte	17                              ; DW_AT_low_pc
	.byte	1                               ; DW_FORM_addr
	.byte	18                              ; DW_AT_high_pc
	.byte	6                               ; DW_FORM_data4
	.byte	88                              ; DW_AT_call_file
	.byte	11                              ; DW_FORM_data1
	.byte	89                              ; DW_AT_call_line
	.byte	11                              ; DW_FORM_data1
	.byte	87                              ; DW_AT_call_column
	.byte	11                              ; DW_FORM_data1
	.byte	0                               ; EOM(1)
	.byte	0                               ; EOM(2)
	.byte	0                               ; EOM(3)
	.section	.debug_info,"",@progbits
.Lcu_begin0:
	.long	.Ldebug_info_end0-.Ldebug_info_start0 ; Length of Unit
.Ldebug_info_start0:
	.short	4                               ; DWARF version number
	.long	.debug_abbrev                   ; Offset Into Abbrev. Section
	.byte	8                               ; Address Size (in bytes)
	.byte	1                               ; Abbrev [1] 0xb:0x6e DW_TAG_compile_unit
	.long	.Linfo_string0                  ; DW_AT_producer
	.short	2                               ; DW_AT_language
	.long	.Linfo_string1                  ; DW_AT_name
	.long	.Lline_table_start0             ; DW_AT_stmt_list
	.long	.Linfo_string2                  ; DW_AT_comp_dir
	.quad	.Lfunc_begin0                   ; DW_AT_low_pc
	.long	.Lfunc_end0-.Lfunc_begin0       ; DW_AT_high_pc
	.byte	2                               ; Abbrev [2] 0x2a:0x6 DW_TAG_subprogram
	.long	.Linfo_string3                  ; DW_AT_name
	.byte	1                               ; DW_AT_inline
	.byte	3                               ; Abbrev [3] 0x30:0x48 DW_TAG_subprogram
	.quad	.Lfunc_begin0                   ; DW_AT_low_pc
	.long	.Lfunc_end0-.Lfunc_begin0       ; DW_AT_high_pc
	.long	42                              ; DW_AT_abstract_origin
	.byte	4                               ; Abbrev [4] 0x41:0x36 DW_TAG_inlined_subroutine
	.long	42                              ; DW_AT_abstract_origin
	.long	.Ldebug_ranges0                 ; DW_AT_ranges
	.byte	1                               ; DW_AT_call_file
	.short	2121                            ; DW_AT_call_line
	.byte	71                              ; DW_AT_call_column
	.byte	5                               ; Abbrev [5] 0x4e:0x14 DW_TAG_inlined_subroutine
	.long	42                              ; DW_AT_abstract_origin
	.quad	.Ltmp2                          ; DW_AT_low_pc
	.long	.Ltmp3-.Ltmp2                   ; DW_AT_high_pc
	.byte	1                               ; DW_AT_call_file
	.byte	13                              ; DW_AT_call_line
	.byte	27                              ; DW_AT_call_column
	.byte	5                               ; Abbrev [5] 0x62:0x14 DW_TAG_inlined_subroutine
	.long	42                              ; DW_AT_abstract_origin
	.quad	.Ltmp3                          ; DW_AT_low_pc
	.long	.Ltmp4-.Ltmp3                   ; DW_AT_high_pc
	.byte	1                               ; DW_AT_call_file
	.byte	14                              ; DW_AT_call_line
	.byte	27                              ; DW_AT_call_column
	.byte	0                               ; End Of Children Mark
	.byte	0                               ; End Of Children Mark
	.byte	0                               ; End Of Children Mark
.Ldebug_info_end0:
	.section	.debug_ranges,"",@progbits
.Ldebug_ranges0:
	.quad	.Ltmp2-.Lfunc_begin0
	.quad	.Ltmp5-.Lfunc_begin0
	.quad	.Ltmp6-.Lfunc_begin0
	.quad	.Ltmp7-.Lfunc_begin0
	.quad	.Ltmp8-.Lfunc_begin0
	.quad	.Ltmp9-.Lfunc_begin0
	.quad	.Ltmp10-.Lfunc_begin0
	.quad	.Ltmp11-.Lfunc_begin0
	.quad	.Ltmp12-.Lfunc_begin0
	.quad	.Ltmp13-.Lfunc_begin0
	.quad	.Ltmp14-.Lfunc_begin0
	.quad	.Ltmp15-.Lfunc_begin0
	.quad	.Ltmp16-.Lfunc_begin0
	.quad	.Ltmp17-.Lfunc_begin0
	.quad	0
	.quad	0
	.section	.debug_str,"MS",@progbits,1
.Linfo_string0:
	.asciz	"triton"                        ; string offset=0
.Linfo_string1:
	.asciz	"matmul_kernel.py"              ; string offset=7
.Linfo_string2:
	.asciz	"/home/jinpli/home/development/triton_03/study_matmul/gluon/matmul_kernels" ; string offset=24
.Linfo_string3:
	.asciz	"v10_f8"                        ; string offset=98
	.section	".note.GNU-stack","",@progbits
	.amdgpu_metadata
---
amdhsa.kernels:
  - .agpr_count:     256
    .args:
      - .address_space:  global
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         8
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         16
        .size:           8
        .value_kind:     global_buffer
      - .offset:         24
        .size:           4
        .value_kind:     by_value
      - .offset:         28
        .size:           4
        .value_kind:     by_value
      - .offset:         32
        .size:           4
        .value_kind:     by_value
      - .offset:         36
        .size:           4
        .value_kind:     by_value
      - .offset:         40
        .size:           4
        .value_kind:     by_value
      - .address_space:  global
        .offset:         48
        .size:           8
        .value_kind:     global_buffer
      - .address_space:  global
        .offset:         56
        .size:           8
        .value_kind:     global_buffer
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 64
    .max_flat_workgroup_size: 256
    .name:           v10_f8
    .private_segment_fixed_size: 0
    .sgpr_count:     63
    .sgpr_spill_count: 0
    .symbol:         v10_f8.kd
    .uniform_work_group_size: 1
    .uses_dynamic_stack: false
    .vgpr_count:     468
    .vgpr_spill_count: 0
    .wavefront_size: 64
amdhsa.target:   amdgcn-amd-amdhsa--gfx950
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
	.section	.debug_line,"",@progbits
.Lline_table_start0:
