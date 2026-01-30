#!/usr/bin/env bash
llc -O3 -mtriple=amdgcn-amd-amdhsa -mcpu=gfx950 v10_f8.llir -o 2.s --misched-prera-direction=topdown --misched-postra-direction=topdown
