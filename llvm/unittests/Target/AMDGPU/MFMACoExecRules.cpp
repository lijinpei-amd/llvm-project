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
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/ADT/StringSwitch.h"
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
      {V_SMFMAC_F32_16X16X64_BF16_e64, 3, 7},
      {V_SMFMAC_F32_32X32X32_BF16_e64, 3, 11},
      {V_SMFMAC_F32_16X16X128_FP8_FP8_e64, 3, 7},
      {V_SMFMAC_F32_32X32X64_FP8_FP8_e64, 3, 11},
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

namespace {
// The co-execution rules a group of MFMAs share.
struct CoExecTableGroup {
  // Opcode names without the _e64, _vgprcd_e64 or _mac*_e64 suffix.
  std::vector<StringRef> MFMAs;
  // One row per line: a cycle, then the instruction kinds the same wave may
  // issue from that cycle until the next row's.
  StringRef Rows;
};
} // namespace

// Returns the classes \p Table allows in each cycle up to its last row. LDS is
// DS, TEX is VMEM and ALU0 or ALU0/1 is VALU; other kinds are not checked.
static SmallVector<CoExecMaskT> parseRows(StringRef Table) {
  SmallVector<CoExecMaskT> Cycles;
  SmallVector<StringRef> Rows;
  Table.split(Rows, '\n', /*MaxSplit=*/-1, /*KeepEmpty=*/false);
  for (StringRef Row : Rows) {
    StringRef Cell = Row.ltrim();
    unsigned Cycle;
    if (Cell.consumeInteger(10, Cycle) || Cycle < Cycles.size()) {
      ADD_FAILURE() << "bad row: " << Row;
      continue;
    }
    SmallVector<StringRef> Kinds;
    SplitString(Cell, Kinds, ", ");
    CoExecMaskT Mask = CoExecMask::None;
    for (StringRef Kind : Kinds)
      Mask |= StringSwitch<CoExecMaskT>(Kind)
                  .Case("LDS", CoExecMask::DS)
                  .Case("TEX", CoExecMask::VMEM)
                  .Cases({"ALU0", "ALU0/1"}, CoExecMask::VALU)
                  .Case("PK_F32", CoExecMask::PK_F32)
                  .Default(CoExecMask::None);
    CoExecMaskT Previous = Cycles.empty() ? CoExecMask::None : Cycles.back();
    Cycles.resize(Cycle, Previous);
    Cycles.push_back(Mask);
  }
  return Cycles;
}

// Checks the DS, VMEM, VALU and PK_F32 bits of every cycle up to the last row
// of each group, and returns the names of the checked opcodes.
static StringSet<> checkTableGroups(MFMACoExecTest &Test,
                                    ArrayRef<CoExecTableGroup> Groups) {
  const SIInstrInfo &TII = Test.getInstrInfo();
  StringMap<unsigned> Opcodes;
  for (unsigned Op = 0; Op < TII.getNumOpcodes(); ++Op)
    if (TII.isMFMA(Op))
      Opcodes[TII.getName(Op)] = Op;

  StringSet<> Checked;
  for (const CoExecTableGroup &G : Groups) {
    SmallVector<CoExecMaskT> Cycles = parseRows(G.Rows);
    for (StringRef Base : G.MFMAs) {
      unsigned NumForms = 0;
      for (StringRef Suffix :
           {"_e64", "_vgprcd_e64", "_mac_e64", "_mac_vgprcd_e64"}) {
        auto It = Opcodes.find((Base + Suffix).str());
        if (It == Opcodes.end())
          continue;
        ++NumForms;
        Checked.insert(It->getKey());
        CoExecInfo Info = getMFMACoExecInfo(It->second, Test.getSubtarget());
        for (CoExecMask Class : {CoExecMask::DS, CoExecMask::VMEM,
                                 CoExecMask::VALU, CoExecMask::PK_F32}) {
          // One character per cycle: 'x' if the class may issue, '.' if not.
          std::string Expected, Actual;
          for (auto [Cycle, Mask] : enumerate(Cycles)) {
            Expected += any(Mask & Class) ? 'x' : '.';
            Actual += Info.canCoExec(Class, Cycle) ? 'x' : '.';
          }
          EXPECT_EQ(Actual, Expected)
              << It->getKey() << ' ' << getCoExecMaskName(Class);
        }
      }
      EXPECT_GT(NumForms, 0u) << Base;
    }
  }
  return Checked;
}

// MFMAs that gfx942 and gfx950 both run.
static const CoExecTableGroup SharedGroups[] = {
    // MFMA_F32_4X4X4F16, MFMA_ F32_4X4X4BF16, MFMA_ I32_4X4X4I8
    {{"V_MFMA_F32_4X4X4F16", "V_MFMA_F32_4X4X4BF16_1K", "V_MFMA_I32_4X4X4I8"},
     R"(
 0  none
 1  EXP, TEX, LDS, ALU0
 2  EXP, TEX, LDS, ALU0, XDL, LD_SCALE
 3  EXP, TEX, LDS, ALU0, XDL, XDL2x, LD_SCALE
 4  EXP, TEX, LDS, ALU0/1, XDL, XDL2x, LD_SCALE, S/DGEMM, DLops, PK_F32
)"},
    // MFMA_F32_16X16X4F16, MFMA_F32_16X16X4BF16, MFMA_I32_16X16X4I8
    {{"V_MFMA_F32_16X16X4F16", "V_MFMA_F32_16X16X4BF16_1K",
      "V_MFMA_I32_16X16X4I8"},
     R"(
 0  none
 1  EXP, TEX, LDS, ALU0
 7  EXP, TEX, LDS, ALU0
 8  EXP, TEX, LDS, ALU0, XDL LD_SCALE
 9  EXP, TEX, LDS, ALU0, XDL XDL2x, LD_SCALE
10  EXP, TEX, LDS, ALU0/1, XDL, XDL2x, LD_SCALE S/DGEMM, DLops, PK_F32
)"},
    // MFMA_F32_16X16X16F16, MFMA_F32_16X16X16BF16, MFMA_I32_16X16X32I8,
    // MFMA_F32_16X16X32_(BF8,F8),
    {{"V_MFMA_F32_16X16X16F16", "V_MFMA_F32_16X16X16BF16_1K",
      "V_MFMA_I32_16X16X32I8", "V_MFMA_F32_16X16X32_BF8_BF8",
      "V_MFMA_F32_16X16X32_BF8_FP8", "V_MFMA_F32_16X16X32_FP8_BF8",
      "V_MFMA_F32_16X16X32_FP8_FP8"},
     R"(
 0  none
 1  EXP, TEX, LDS, ALU0
 2  EXP, TEX, LDS, ALU0
 3  EXP, TEX, LDS, ALU0
 4  EXP, TEX, LDS, ALU0, XDL LD_SCALE
 5  EXP, TEX, LDS, ALU0, XDL XDL2x, LD_SCALE
 6  EXP, TEX, LDS, ALU0/1, XDL, XDL2x, LD_SCALE S/DGEMM, DLops, PK_F32
)"},
    // SMFMAC_F32_16X16X32F16, SMFMAC_F32_16X16X32BF16, SMFMAC_I32_16X16X64I8,
    // SMFMAC_F32_16X16X64_(BF8/F8)
    {{"V_SMFMAC_F32_16X16X32_F16", "V_SMFMAC_F32_16X16X32_BF16",
      "V_SMFMAC_I32_16X16X64_I8", "V_SMFMAC_F32_16X16X64_BF8_BF8",
      "V_SMFMAC_F32_16X16X64_BF8_FP8", "V_SMFMAC_F32_16X16X64_FP8_BF8",
      "V_SMFMAC_F32_16X16X64_FP8_FP8"},
     R"(
 0  none
 1  none
 2  EXP, TEX, LDS, ALU0
 3  EXP, TEX, LDS, ALU0
 4  EXP, TEX, LDS, ALU0, XDL, LD_SCALE
 5  EXP, TEX, LDS, ALU0, XDL XDL2x, LD_SCALE
 6  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, Dlops, PK_F32
)"},
    // MFMA_F32_32X32X4F16, MFMA_F32_32X32X4BF16, MFMA_I32_32X32X4I8
    {{"V_MFMA_F32_32X32X4F16", "V_MFMA_F32_32X32X4BF16_1K",
      "V_MFMA_I32_32X32X4I8"},
     R"(
 0  none
 1  EXP, TEX, LDS, ALU0
15  EXP, TEX, LDS, ALU0
16  EXP, TEX, LDS, ALU0, XDL, LD_SCALE
17  EXP, TEX, LDS, ALU0, XDL XDL2x, LD_SCALE
18  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32
)"},
    // MFMA_F32_32X32X8F16, MFMA_F32_32X32X8BF16, MFMA_I32_32X32X16I8,
    // MFMA_F32_32X32X16_(F8/BF8)
    {{"V_MFMA_F32_32X32X8F16", "V_MFMA_F32_32X32X8BF16_1K",
      "V_MFMA_I32_32X32X16I8", "V_MFMA_F32_32X32X16_BF8_BF8",
      "V_MFMA_F32_32X32X16_BF8_FP8", "V_MFMA_F32_32X32X16_FP8_BF8",
      "V_MFMA_F32_32X32X16_FP8_FP8"},
     R"(
 0  none
 1  EXP, TEX, LDS, ALU0
 7  EXP, TEX, LDS, ALU0,
 8  EXP, TEX, LDS, ALU0, XDL LD_SCALE
 9  EXP, TEX, LDS, ALU0, XDL XDL2x, LD_SCALE
10  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, XDL2x, LD_SCALE
)"},
    // SMFMAC_I32_32X32X16F16, SMFMAC_I32_32X32X16BF16 ,SMFMAC_I32_32X32X32I8,
    // SMFMAC_F32_32X32X32_(FP8/BF8)
    {{"V_SMFMAC_F32_32X32X16_F16", "V_SMFMAC_F32_32X32X16_BF16",
      "V_SMFMAC_I32_32X32X32_I8", "V_SMFMAC_F32_32X32X32_BF8_BF8",
      "V_SMFMAC_F32_32X32X32_BF8_FP8", "V_SMFMAC_F32_32X32X32_FP8_BF8",
      "V_SMFMAC_F32_32X32X32_FP8_FP8"},
     R"(
 0  none
 1  none
 2  EXP, TEX, LDS, ALU0
 7  EXP, TEX, LDS, ALU0
 8  EXP, TEX, LDS, ALU0, XDL, LD_SCALE
 9  EXP, TEX, LDS, ALU0, XDL XDL2x, LD_SCALE
10  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, XDL2x, LD_SCALE
)"},
    // 4x4x1F32
    {{"V_MFMA_F32_4X4X1F32"},
     R"(
 0  none
 1  EXP, TEX, LDS
 2  EXP, TEX, LDS, SGEMM
 3  EXP, TEX, LDS, SGEMM , LD_SCALE
 4  EXP, TEX, LDS, DLops, SGEMM, DGEMM, XDL, XDL2x, ALU0/1, PK_F32
)"},
    // 16x16x1F32
    {{"V_MFMA_F32_16X16X1F32"},
     R"(
 0  none
 1  EXP, TEX, LDS
 8  EXP, TEX, LDS, SGEMM
 9  EXP, TEX, LDS, SGEMM, LD_SCALE
10  EXP, TEX, LDS, DLops, SGEMM, DGEMM, XDL, XDL2x, ALU0/1, PK_F32
)"},
    // 16x16x4F32
    {{"V_MFMA_F32_16X16X4F32"},
     R"(
 0  none
 1  EXP, TEX, LDS
 2  EXP, TEX, LDS
 5  EXP, TEX, LDS
 6  EXP, TEX, LDS
 8  EXP, TEX, LDS, SGEMM
 9  EXP, TEX, LDS, SGEMM, LD_SCALE
10  EXP, TEX, LDS, DLops, SGEMM, DGEMM, XDL, XDL2x, ALU0/1, PK_F32
)"},
    // 32x32x1F32
    {{"V_MFMA_F32_32X32X1F32"},
     R"(
 0  none
 1  EXP, TEX, LDS
16  EXP, TEX, LDS, SGEMM
17  EXP, TEX, LDS, SGEMM LD_SCALE
18  EXP, TEX, LDS, DLops, SGEMM, DGEMM, XDL, XDL2x, ALU0/1, PK_F32
)"},
    // 32x32x2F32
    {{"V_MFMA_F32_32X32X2F32"},
     R"(
 0  none
 1  EXP, TEX, LDS
 2  EXP, TEX, LDS
 3  EXP, TEX, LDS
 4  EXP, TEX, LDS
 5  EXP, TEX, LDS
 6  EXP, TEX, LDS
 7  EXP, TEX, LDS
 8  EXP, TEX, LDS
 9  EXP, TEX, LDS
10  EXP, TEX, LDS
11  EXP, TEX, LDS
12  EXP, TEX, LDS
13  EXP, TEX, LDS
14  EXP, TEX, LDS
15  EXP, TEX, LDS
16  EXP, TEX, LDS, SGEMM
17  EXP, TEX, LDS, SGEMM LD_SCALE
18  EXP, TEX, LDS, DLops, SGEMM, DGEMM, XDL, XDL2x, ALU0/1, PK_F32
)"},
    // 4X4X4F64
    {{"V_MFMA_F64_4X4X4F64"},
     R"(
 0  none
 1  EXP, TEX, LDS
 2  EXP, TEX, LDS
 4  EXP, TEX, LDS, DGEMM
 5  EXP, TEX, LDS, DGEMM LD_SCALE
 6  EXP, TEX, LDS, DLops, SGEMM, DGEMM, XDL, XDL2x, ALU0/1, PK_F32
)"},
};

// Every gfx950 MFMA appears in a group. The scaled MFMAs share the groups of
// their unscaled forms.
TEST_F(AMDGPUMFMACoExecRules, GFX950CoExecTable) {
  auto TM =
      createAMDGPUTargetMachine(Triple("amdgcn-amd-amdhsa"), "gfx950", "");
  if (!TM)
    GTEST_SKIP();
  MFMACoExecTest Test(std::move(TM));
  // MFMAs gfx950 added, and DGEMM 16x16x4, which takes 16 passes on gfx950.
  const CoExecTableGroup Groups[] = {
      // MFMA_16X16X128_F8F4F6 (MatrixA != F8 & MatrixB != F8 )
      // MFMA_16X16X32_BF16
      // MFMA_16X16X64_I8
      // MFMA_16X16X32_F16
      {{"V_MFMA_F32_16X16X128_F8F6F4_f4_f4",
        "V_MFMA_F32_16X16X128_F8F6F4_f4_f6",
        "V_MFMA_F32_16X16X128_F8F6F4_f6_f4",
        "V_MFMA_F32_16X16X128_F8F6F4_f6_f6",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f4_f4",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f4_f6",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f6_f4",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f6_f6", "V_MFMA_F32_16X16X32_BF16",
        "V_MFMA_I32_16X16X64_I8", "V_MFMA_F32_16X16X32_F16"},
       R"(
 0  none
 1  none
 2  EXP, TEX, LDS, ALU0
 3  EXP, TEX, LDS, ALU0, LD_SCALE
 4  EXP, TEX, LDS, ALU0, LD_SCALE , XDL2x
 5  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
 6  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
 7  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, LD_SCALE , XDL2x
)"},
      // 16X16X128_F8F4F6 (MatrixA or MatrixB = F8)
      {{"V_MFMA_F32_16X16X128_F8F6F4_f4_f8",
        "V_MFMA_F32_16X16X128_F8F6F4_f6_f8",
        "V_MFMA_F32_16X16X128_F8F6F4_f8_f4",
        "V_MFMA_F32_16X16X128_F8F6F4_f8_f6",
        "V_MFMA_F32_16X16X128_F8F6F4_f8_f8",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f4_f8",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f6_f8",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f8_f4",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f8_f6",
        "V_MFMA_SCALE_F32_16X16X128_F8F6F4_f8_f8"},
       R"(
 0  none
 1  none
 2  EXP, TEX, LDS
 3  EXP, TEX, LDS, ALU0
 4  EXP, TEX, LDS, ALU0
 5  EXP, TEX, LDS, ALU0
 6  EXP, TEX, LDS, ALU0
 7  EXP, TEX, LDS, ALU0 LD_SCALE
 8  EXP, TEX, LDS, ALU0, LD_SCALE , XDL2x
 9  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
10  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
11  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, LD_SCALE , XDL2x
)"},
      // 32X32X64_F8F4F6 (MatrixA != F8 & MatrixB != F8 )
      // MFMA_32X32X16_BF16
      // MFMA_32X32X32_I8
      // MFMA_32X32X16_F16
      {{"V_MFMA_F32_32X32X64_F8F6F4_f4_f4", "V_MFMA_F32_32X32X64_F8F6F4_f4_f6",
        "V_MFMA_F32_32X32X64_F8F6F4_f6_f4", "V_MFMA_F32_32X32X64_F8F6F4_f6_f6",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f4_f4",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f4_f6",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f6_f4",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f6_f6", "V_MFMA_F32_32X32X16_BF16",
        "V_MFMA_I32_32X32X32_I8", "V_MFMA_F32_32X32X16_F16"},
       R"(
 0  none
 1  none
 2  EXP, TEX, LDS, ALU0
 7  EXP, TEX, LDS, ALU0, LD_SCALE
 8  EXP, TEX, LDS, ALU0, LD_SCALE , XDL2x
 9  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
10  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
11  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, LD_SCALE , XDL2x
)"},
      // 32X32X64_F8F4F6 (MatrixA == F8 or MatrixB == F8 )
      {{"V_MFMA_F32_32X32X64_F8F6F4_f4_f8", "V_MFMA_F32_32X32X64_F8F6F4_f6_f8",
        "V_MFMA_F32_32X32X64_F8F6F4_f8_f4", "V_MFMA_F32_32X32X64_F8F6F4_f8_f6",
        "V_MFMA_F32_32X32X64_F8F6F4_f8_f8",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f4_f8",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f6_f8",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f8_f4",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f8_f6",
        "V_MFMA_SCALE_F32_32X32X64_F8F6F4_f8_f8"},
       R"(
 0  none
 1  none
 2  EXP, TEX, LDS
 3  EXP, TEX, LDS, ALU0
 4  EXP, TEX, LDS, ALU0
 5  EXP, TEX, LDS, ALU0
 6  EXP, TEX, LDS, ALU0
 7  EXP, TEX, LDS, ALU0
 8  EXP, TEX, LDS, ALU0
 9  EXP, TEX, LDS, ALU0
10  EXP, TEX, LDS, ALU0
11  EXP, TEX, LDS, ALU0
12  EXP, TEX, LDS, ALU0
13  EXP, TEX, LDS, ALU0
14  EXP, TEX, LDS, ALU0
15  EXP, TEX, LDS, ALU0, LD_SCALE
16  EXP, TEX, LDS, ALU0, LD_SCALE , XDL2x
17  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
18  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
19  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, LD_SCALE , XDL2x
)"},
      // SMFMAC_16X16X64_BF16
      // SMFMAC_16X16X128_I8
      // SMFMAC_16X16X128_(F8/BF8)
      // SMFMAC_16X16X64_F16
      {{"V_SMFMAC_F32_16X16X64_BF16", "V_SMFMAC_I32_16X16X128_I8",
        "V_SMFMAC_F32_16X16X128_BF8_BF8", "V_SMFMAC_F32_16X16X128_BF8_FP8",
        "V_SMFMAC_F32_16X16X128_FP8_BF8", "V_SMFMAC_F32_16X16X128_FP8_FP8",
        "V_SMFMAC_F32_16X16X64_F16"},
       R"(
 0  none
 1  none
 2  EXP, TEX, LDS
 3  EXP, TEX, LDS, ALU0, LD_SCALE
 4  EXP, TEX, LDS, ALU0, LD_SCALE , XDL2x
 5  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
 6  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
 7  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, LD_SCALE , XDL2x
)"},
      // SMFMAC_32X32X32_BF16
      // SMFMAC_32X32X64_I8
      // SMFMAC_32X32X64_(F8/BF8)
      // SMFMAC_32X32X32_F16
      {{"V_SMFMAC_F32_32X32X32_BF16", "V_SMFMAC_I32_32X32X64_I8",
        "V_SMFMAC_F32_32X32X64_BF8_BF8", "V_SMFMAC_F32_32X32X64_BF8_FP8",
        "V_SMFMAC_F32_32X32X64_FP8_BF8", "V_SMFMAC_F32_32X32X64_FP8_FP8",
        "V_SMFMAC_F32_32X32X32_F16"},
       R"(
 0  none
 1  none
 2  none
 3  EXP, TEX, LDS,ALU0
 7  EXP, TEX, LDS, ALU0, LD_SCALE
 8  EXP, TEX, LDS, ALU0, LD_SCALE , XDL2x
 9  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
10  EXP, TEX, LDS, ALU0, XDL, LD_SCALE , XDL2x
11  EXP, TEX, LDS, ALU0/1, XDL, S/DGEMM, DLops, PK_F32, LD_SCALE , XDL2x
)"},
      // 16X16X4F64
      {{"V_MFMA_F64_16X16X4F64"},
       R"(
 0  none
 1  EXP, TEX, LDS
 2  EXP, TEX, LDS
 3  EXP, TEX, LDS
 4  EXP, TEX, LDS
 5  EXP, TEX, LDS
 6  EXP, TEX, LDS
 7  EXP, TEX, LDS
 8  EXP, TEX, LDS
 9  EXP, TEX, LDS
10  EXP, TEX, LDS
11  EXP, TEX, LDS
12  EXP, TEX, LDS
13  EXP, TEX, LDS
14  EXP, TEX, LDS
15  EXP, TEX, LDS
16  EXP, TEX, LDS, DGEMM
17  EXP, TEX, LDS, DGEMM, LD_SCALE
18  EXP, TEX, LDS, DLops, SGEMM, DGEMM, XDL, XDL2x, LD_SCALE, ALU0/1, PK_F32
)"},
  };
  StringSet<> Checked = checkTableGroups(Test, Groups);
  Checked.insert_range(checkTableGroups(Test, SharedGroups).keys());

  const SIInstrInfo &TII = Test.getInstrInfo();
  for (unsigned Op = 0; Op < TII.getNumOpcodes(); ++Op) {
    if (!TII.isMFMA(Op) || !TII.get(Op).isPseudo())
      continue;
    int MCOp = TII.pseudoToMCOpcode(Op);
    if (MCOp != -1 && AMDGPU_MC::isOpcodeAvailable(
                          MCOp, Test.getSubtarget().getFeatureBits()))
      EXPECT_TRUE(Checked.contains(TII.getName(Op))) << TII.getName(Op);
  }
}

TEST_F(AMDGPUMFMACoExecRules, GFX942CoExecTable) {
  auto TM =
      createAMDGPUTargetMachine(Triple("amdgcn-amd-amdhsa"), "gfx942", "");
  if (!TM)
    GTEST_SKIP();
  MFMACoExecTest Test(std::move(TM));
  checkTableGroups(Test, SharedGroups);
}
