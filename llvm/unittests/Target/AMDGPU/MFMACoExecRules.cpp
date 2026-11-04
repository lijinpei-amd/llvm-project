//===- llvm/unittests/Target/AMDGPU/MFMACoExecRules.cpp -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
/// \file
/// Test MFMA co-exec rules.
//
//===----------------------------------------------------------------------===//

#include "AMDGPUUnitTests.h"
#include "gtest/gtest.h"

#include "AMDGPUCoExecInfo.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/TargetParser/SubtargetFeature.h"

#include "GCNSubtarget.h"
#include "SIInstrInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineModuleInfo.h"

#define GET_AVAILABLE_OPCODE_CHECKER
#include "AMDGPUGenInstrInfo.inc"

using namespace llvm;
using namespace llvm::AMDGPU;

class AMDGPUMFMACoExecRules : public AMDGPUTestBase {};

TEST_F(AMDGPUMFMACoExecRules, GFX950) {
  std::unique_ptr<GCNTargetMachine> TM =
      createAMDGPUTargetMachine(Triple("amdgpu-amd-amdhsa"), "gfx950", "");
  auto ST =
      std::make_unique<GCNSubtarget>(TM->getTargetTriple(), TM->getTargetCPU(),
                                     TM->getTargetFeatureString(), *TM);

  const MCInstrInfo *MCII = TM->getMCInstrInfo();

  for (unsigned Op = 0; Op < MCII->getNumOpcodes(); ++Op) {
    if (!ST->getInstrInfo()->isMFMAorWMMA(Op))
      continue;

    // Filter out pre-gfx950 MFMA instructions
    FeatureBitset Required = AMDGPU_MC::computeRequiredFeatures(Op);
    if (!Required.test(AMDGPU_MC::Feature_HasGFX950InstsBit))
      continue;

    CoExecInfo Info = getMFMACoExecInfo(Op, *ST);
    // None of gfx950 MFMAs can co-execute anything in their issue slot and our
    // fallback for unrecognized MFMA instructions is to allow everything in
    // every slot, so here we check that we did not encounter the fallback
    // definition of co-exec rules.
    EXPECT_EQ(Info.Slots[0].Mask, CoExecMask::None) << MCII->getName(Op);
  }
}

namespace {
class MFMACoExecTest {
public:
  explicit MFMACoExecTest(std::unique_ptr<GCNTargetMachine> TheTM)
      : TM(std::move(TheTM)),
        ST(TM->getTargetTriple(), std::string(TM->getTargetCPU()),
           std::string(TM->getTargetFeatureString()), *TM),
        Mod("Module", Ctx), MMI(TM.get()) {
    Mod.setDataLayout(TM->getTargetTriple().computeDataLayout());
    auto *F = Function::Create(FunctionType::get(Type::getVoidTy(Ctx), false),
                               GlobalValue::ExternalLinkage, "Test", &Mod);
    MF = std::make_unique<MachineFunction>(*F, *TM, ST, MMI.getContext(), 0);
  }

  const GCNSubtarget &getSubtarget() const { return ST; }
  const SIInstrInfo &getInstrInfo() const { return *ST.getInstrInfo(); }

  // Builds an instruction with placeholder operands.
  MachineInstr &buildMI(unsigned Opc) {
    const MCInstrDesc &Desc = getInstrInfo().get(Opc);
    MachineInstr *MI = MF->CreateMachineInstr(Desc, DebugLoc());
    for (auto [Idx, Info] : enumerate(Desc.operands())) {
      if (Info.RegClass == -1)
        MI->addOperand(*MF, MachineOperand::CreateImm(0));
      else
        MI->addOperand(*MF, MachineOperand::CreateReg(Register(), Idx < 1));
    }
    return *MI;
  }

  // First stage at which an instruction with opcode Opc can issue after an
  // MFMA with opcode MFMAOpc.
  unsigned getIssueStage(unsigned MFMAOpc, unsigned Opc) {
    return getMFMACoExecInfo(MFMAOpc, ST)
        .getFirstAllowedStage(getCoExecMaskForMI(buildMI(Opc), getInstrInfo()));
  }

private:
  std::unique_ptr<GCNTargetMachine> TM;
  GCNSubtarget ST;
  LLVMContext Ctx;
  Module Mod;
  MachineModuleInfo MMI;
  std::unique_ptr<MachineFunction> MF;
};
} // namespace

// Expected PK_F32 stages were measured on MI350X; one stage is 4 clocks.
// Scaled MFMAs were measured issuing right behind another MFMA.
TEST_F(AMDGPUMFMACoExecRules, GFX950IssueStages) {
  auto TM =
      createAMDGPUTargetMachine(Triple("amdgcn-amd-amdhsa"), "gfx950", "");
  if (!TM)
    GTEST_SKIP();
  MFMACoExecTest Test(std::move(TM));
  const SIInstrInfo &TII = Test.getInstrInfo();
  for (unsigned PK : {V_PK_FMA_F32, V_PK_MUL_F32, V_PK_ADD_F32, V_PK_MOV_B32})
    EXPECT_EQ(Test.getIssueStage(V_MFMA_F32_16X16X32_BF16_vgprcd_e64, PK), 7u)
        << TII.getName(PK);

  struct {
    unsigned MFMAOpc;
    unsigned VALU, PackedF32;
  } Cases[] = {
      {V_MFMA_F32_16X16X32_BF16_vgprcd_e64, 2, 7},
      {V_MFMA_F32_16X16X32_BF16_e64, 2, 7},
      {V_MFMA_F32_16X16X32_F16_vgprcd_e64, 2, 7},
      {V_MFMA_I32_16X16X64_I8_vgprcd_e64, 2, 7},
      {V_MFMA_F32_32X32X16_BF16_vgprcd_e64, 2, 11},
      {V_MFMA_F32_32X32X16_F16_vgprcd_e64, 2, 11},
      {V_MFMA_I32_32X32X32_I8_vgprcd_e64, 2, 11},
      {V_MFMA_F32_16X16X128_F8F6F4_f4_f4_vgprcd_e64, 2, 7},
      {V_MFMA_F32_16X16X128_F8F6F4_f6_f6_vgprcd_e64, 2, 7},
      {V_MFMA_F32_16X16X128_F8F6F4_f8_f8_vgprcd_e64, 3, 11},
      {V_MFMA_F32_16X16X128_F8F6F4_f8_f4_vgprcd_e64, 3, 11},
      {V_MFMA_F32_32X32X64_F8F6F4_f4_f4_vgprcd_e64, 2, 11},
      {V_MFMA_F32_32X32X64_F8F6F4_f8_f8_vgprcd_e64, 3, 19},
      {V_MFMA_SCALE_F32_16X16X128_F8F6F4_f8_f8_vgprcd_e64, 3, 11},
      {V_MFMA_SCALE_F32_16X16X128_F8F6F4_f4_f4_vgprcd_e64, 2, 7},
      // The table holds VALU until 2 (16x16) or 4 (32x32); MI350X issues it
      // at 3.
      {V_SMFMAC_F32_16X16X64_BF16_e64, 2, 7},
      {V_SMFMAC_F32_32X32X32_BF16_e64, 4, 11},
      {V_SMFMAC_F32_16X16X128_FP8_FP8_e64, 2, 7},
      {V_SMFMAC_F32_32X32X64_FP8_FP8_e64, 4, 11},
      {V_MFMA_F64_16X16X4F64_vgprcd_e64, 18, 18},
  };
  for (const auto &C : Cases) {
    StringRef Name = TII.getName(C.MFMAOpc);
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, V_FMA_F32_e64), C.VALU) << Name;
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, V_PK_ADD_F16), C.VALU) << Name;
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, V_PK_FMA_F32), C.PackedF32) << Name;
  }
}

// Every MFMA gfx942 runs has an entry rather than the fallback, which allows
// everything in every slot.
TEST_F(AMDGPUMFMACoExecRules, GFX942) {
  auto TM =
      createAMDGPUTargetMachine(Triple("amdgcn-amd-amdhsa"), "gfx942", "");
  if (!TM)
    GTEST_SKIP();
  MFMACoExecTest Test(std::move(TM));
  const SIInstrInfo &TII = Test.getInstrInfo();
  unsigned NumMFMAs = 0;
  for (unsigned Op = 0; Op < TII.getNumOpcodes(); ++Op) {
    if (!TII.isMFMA(Op) || !TII.get(Op).isPseudo())
      continue;
    int MCOp = TII.pseudoToMCOpcode(Op);
    if (MCOp == -1)
      continue;
    FeatureBitset Required = AMDGPU_MC::computeRequiredFeatures(MCOp);
    if (!Required.test(AMDGPU_MC::Feature_isGFX940PlusBit) ||
        Required.test(AMDGPU_MC::Feature_HasGFX950InstsBit))
      continue;
    ++NumMFMAs;
    EXPECT_NE(getMFMACoExecInfo(Op, Test.getSubtarget()).Slots[0].Mask,
              CoExecMask::All)
        << TII.getName(Op);
  }
  EXPECT_GT(NumMFMAs, 0u);
}

// Expected stages were measured on MI300X; MI350X times these MFMAs the same,
// except for DGEMM 16x16x4, which takes twice as many passes there.
TEST_F(AMDGPUMFMACoExecRules, GFX942IssueStages) {
  auto TM =
      createAMDGPUTargetMachine(Triple("amdgcn-amd-amdhsa"), "gfx942", "");
  if (!TM)
    GTEST_SKIP();
  MFMACoExecTest Test(std::move(TM));
  const SIInstrInfo &TII = Test.getInstrInfo();
  for (unsigned PK : {V_PK_FMA_F32, V_PK_MUL_F32, V_PK_ADD_F32, V_PK_MOV_B32})
    EXPECT_EQ(Test.getIssueStage(V_MFMA_F32_16X16X16BF16_1K_vgprcd_e64, PK), 6u)
        << TII.getName(PK);

  struct {
    unsigned MFMAOpc;
    unsigned VALU, PackedF32, MFMA;
  } Cases[] = {
      {V_MFMA_F32_16X16X16BF16_1K_vgprcd_e64, 1, 6, 4},
      {V_MFMA_F32_16X16X16BF16_1K_e64, 1, 6, 4},
      {V_MFMA_F32_4X4X4BF16_1K_vgprcd_e64, 1, 4, 2},
      {V_MFMA_F32_32X32X8BF16_1K_vgprcd_e64, 1, 10, 8},
      {V_MFMA_F32_16X16X16F16_vgprcd_e64, 1, 6, 4},
      {V_MFMA_I32_16X16X32I8_vgprcd_e64, 1, 6, 4},
      {V_MFMA_F32_16X16X32_FP8_FP8_vgprcd_e64, 1, 6, 4},
      {V_MFMA_F32_16X16X8XF32_vgprcd_e64, 1, 6, 4},
      {V_SMFMAC_F32_16X16X32_F16_e64, 2, 6, 4},
      // Measured on MI350X only.
      {V_SMFMAC_F32_32X32X16_F16_e64, 2, 10, 8},
      {V_MFMA_F32_16X16X4F32_vgprcd_e64, 10, 10, 8},
      {V_MFMA_F64_16X16X4F64_vgprcd_e64, 10, 10, 8},
      {V_MFMA_F64_4X4X4F64_vgprcd_e64, 6, 6, 4},
  };
  for (const auto &C : Cases) {
    StringRef Name = TII.getName(C.MFMAOpc);
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, V_FMA_F32_e64), C.VALU) << Name;
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, V_EXP_F32_e32), C.VALU) << Name;
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, V_PK_ADD_F16), C.VALU) << Name;
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, V_PK_FMA_F32), C.PackedF32) << Name;
    EXPECT_EQ(Test.getIssueStage(C.MFMAOpc, C.MFMAOpc), C.MFMA) << Name;
  }
}

// PK_F32 extends the 32x32 entries' window from 8 to 12 cycles; nothing else
// waits past 8.
TEST_F(AMDGPUMFMACoExecRules, GFX950PackedF32ExtendsWindow) {
  auto TM =
      createAMDGPUTargetMachine(Triple("amdgcn-amd-amdhsa"), "gfx950", "");
  if (!TM)
    GTEST_SKIP();
  MFMACoExecTest Test(std::move(TM));
  CoExecInfo Info = getMFMACoExecInfo(V_MFMA_F32_32X32X16_BF16_vgprcd_e64,
                                      Test.getSubtarget());
  EXPECT_EQ(Info.TotalWindow, 12u);
  for (CoExecMask Mask :
       {CoExecMask::CTRL, CoExecMask::VALU, CoExecMask::TRANS, CoExecMask::SALU,
        CoExecMask::DS, CoExecMask::VMEM, CoExecMask::SMEM, CoExecMask::WMMA})
    EXPECT_TRUE(Info.canCoExec(Mask, 8)) << getCoExecMaskName(Mask);
  EXPECT_FALSE(Info.canCoExec(CoExecMask::PK_F32, 10));
  EXPECT_TRUE(Info.canCoExec(CoExecMask::PK_F32, 11));
}

TEST_F(AMDGPUMFMACoExecRules, CoExecMaskClasses) {
  auto TM =
      createAMDGPUTargetMachine(Triple("amdgcn-amd-amdhsa"), "gfx950", "");
  if (!TM)
    GTEST_SKIP();
  MFMACoExecTest Test(std::move(TM));
  const SIInstrInfo &TII = Test.getInstrInfo();
  auto Check = [&](ArrayRef<unsigned> Opcs, CoExecMaskT Expected) {
    for (unsigned Opc : Opcs)
      EXPECT_EQ(getCoExecMaskForMI(Test.buildMI(Opc), TII), Expected)
          << TII.getName(Opc);
  };
  Check({V_PK_ADD_F32, V_PK_FMA_F32, V_PK_MOV_B32, V_PK_MUL_F32},
        CoExecMask::PK_F32);
  Check({V_FMA_F32_e64, V_PK_ADD_F16}, CoExecMask::VALU);
}
