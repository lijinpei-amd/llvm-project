//===- unittests/AST/EvaluateAsRValueTest.cpp -----------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// \file
// \brief Unit tests for evaluation of constant initializers.
//
//===----------------------------------------------------------------------===//

#include "clang/AST/ASTConsumer.h"
#include "clang/AST/ASTContext.h"
#include "clang/AST/DynamicRecursiveASTVisitor.h"
#include "clang/Tooling/Tooling.h"
#include "gtest/gtest.h"
#include <map>
#include <string>

using namespace clang::tooling;

namespace {
// For each variable name encountered, whether its initializer was a
// constant.
typedef std::map<std::string, bool> VarInfoMap;

/// \brief Records information on variable initializers to a map.
class EvaluateConstantInitializersVisitor
    : public clang::DynamicRecursiveASTVisitor {
public:
  explicit EvaluateConstantInitializersVisitor(VarInfoMap &VarInfo)
      : VarInfo(VarInfo) {}

  /// \brief Checks that isConstantInitializer and EvaluateAsRValue agree
  /// and don't crash.
  ///
  /// For each VarDecl with an initializer this also records in VarInfo
  /// whether the initializer could be evaluated as a constant.
  bool VisitVarDecl(clang::VarDecl *VD) override {
    if (const clang::Expr *Init = VD->getInit()) {
      clang::Expr::EvalResult Result;
      bool WasEvaluated = Init->EvaluateAsRValue(Result, VD->getASTContext());
      VarInfo[VD->getNameAsString()] = WasEvaluated;
      EXPECT_EQ(WasEvaluated, Init->isConstantInitializer(VD->getASTContext(),
                                                          false /*ForRef*/));
    }
    return true;
  }

 private:
  VarInfoMap &VarInfo;
};

class EvaluateConstantInitializersAction : public clang::ASTFrontendAction {
 public:
   std::unique_ptr<clang::ASTConsumer>
   CreateASTConsumer(clang::CompilerInstance &Compiler,
                     llvm::StringRef FilePath) override {
     return std::make_unique<Consumer>();
  }

 private:
  class Consumer : public clang::ASTConsumer {
   public:
    ~Consumer() override {}

    void HandleTranslationUnit(clang::ASTContext &Ctx) override {
      VarInfoMap VarInfo;
      EvaluateConstantInitializersVisitor Evaluator(VarInfo);
      Evaluator.TraverseDecl(Ctx.getTranslationUnitDecl());
      EXPECT_EQ(2u, VarInfo.size());
      EXPECT_FALSE(VarInfo["Dependent"]);
      EXPECT_TRUE(VarInfo["Constant"]);
      EXPECT_EQ(2u, VarInfo.size());
    }
  };
};
}

TEST(EvaluateAsRValue, FailsGracefullyForUnknownTypes) {
  // This is a regression test; the AST library used to trigger assertion
  // failures because it assumed that the type of initializers was always
  // known (which is true only after template instantiation).
  std::string ModesToTest[] = {"-std=c++03", "-std=c++11", "-std=c++1y"};
  for (std::string const &Mode : ModesToTest) {
    std::vector<std::string> Args(1, Mode);
    Args.push_back("-fno-delayed-template-parsing");
    ASSERT_TRUE(runToolOnCodeWithArgs(
        std::make_unique<EvaluateConstantInitializersAction>(),
        "template <typename T>"
        "struct vector {"
        "  explicit vector(int size);"
        "};"
        "template <typename R>"
        "struct S {"
        "  vector<R> intervals() const {"
        "    vector<R> Dependent(2);"
        "    return Dependent;"
        "  }"
        "};"
        "void doSomething() {"
        "  int Constant = 2 + 2;"
        "  (void) Constant;"
        "}",
        Args));
  }
}

class CheckLValueToRValueConversionVisitor
    : public clang::DynamicRecursiveASTVisitor {
public:
  bool VisitDeclRefExpr(clang::DeclRefExpr *E) override {
    clang::Expr::EvalResult Result;
    E->EvaluateAsRValue(Result, E->getDecl()->getASTContext(), true);

    EXPECT_TRUE(Result.Val.hasValue());
    // Since EvaluateAsRValue does an implicit lvalue-to-rvalue conversion,
    // the result cannot be a LValue.
    EXPECT_FALSE(Result.Val.isLValue());

    return true;
  }
};

class CheckConversionAction : public clang::ASTFrontendAction {
public:
  std::unique_ptr<clang::ASTConsumer>
  CreateASTConsumer(clang::CompilerInstance &Compiler,
                    llvm::StringRef FilePath) override {
    return std::make_unique<Consumer>();
  }

private:
  class Consumer : public clang::ASTConsumer {
  public:
    ~Consumer() override {}

    void HandleTranslationUnit(clang::ASTContext &Ctx) override {
      CheckLValueToRValueConversionVisitor Evaluator;
      Evaluator.TraverseDecl(Ctx.getTranslationUnitDecl());
    }
  };
};

TEST(EvaluateAsRValue, LValueToRValueConversionWorks) {
  std::string ModesToTest[] = {"", "-fexperimental-new-constant-interpreter"};
  for (std::string const &Mode : ModesToTest) {
    std::vector<std::string> Args(1, Mode);
    ASSERT_TRUE(runToolOnCodeWithArgs(std::make_unique<CheckConversionAction>(),
                                      "constexpr int a = 20;\n"
                                      "static_assert(a == 20, \"\");\n",
                                      Args));
  }
}

class EvaluateBoundMemberFunctionVisitor
    : public clang::DynamicRecursiveASTVisitor {
public:
  explicit EvaluateBoundMemberFunctionVisitor(clang::ASTContext &Ctx)
      : Ctx(Ctx) {}

  bool VisitMemberExpr(clang::MemberExpr *E) override {
    if (llvm::isa<clang::CXXMethodDecl>(E->getMemberDecl())) {
      clang::Expr::EvalResult Result;
      bool EvalSucceeded = E->EvaluateAsRValue(Result, Ctx, true);
      EXPECT_FALSE(EvalSucceeded);
    }
    return true;
  }

private:
  clang::ASTContext &Ctx;
};

class EvaluateBoundMemberFunctionAction : public clang::ASTFrontendAction {
public:
  std::unique_ptr<clang::ASTConsumer>
  CreateASTConsumer(clang::CompilerInstance &Compiler,
                    llvm::StringRef FilePath) override {
    return std::make_unique<Consumer>();
  }

private:
  class Consumer : public clang::ASTConsumer {
  public:
    ~Consumer() override {}
    void HandleTranslationUnit(clang::ASTContext &Ctx) override {
      EvaluateBoundMemberFunctionVisitor Evaluator(Ctx);
      Evaluator.TraverseDecl(Ctx.getTranslationUnitDecl());
    }
  };
};

TEST(EvaluateAsRValue, FailsGracefullyOnBoundMemberExpr) {
  std::string ModesToTest[] = {"", "-fexperimental-new-constant-interpreter"};
  for (std::string const &Mode : ModesToTest) {
    std::vector<std::string> Args(1, Mode);
    Args.push_back("-std=c++23");
    ASSERT_TRUE(runToolOnCodeWithArgs(
        std::make_unique<EvaluateBoundMemberFunctionAction>(),
        "struct S { void f(); };\n"
        "void g() { S s; s.f(); }\n",
        Args));
  }
}

// Mirrors what clangd does when computing hover information: skip
// value-dependent expressions and then try to constant-evaluate the rest. An
// error-recovery DeclRefExpr can be `contains-errors` (and hence is not
// constant-foldable) without being value-dependent, so the evaluator must not
// assume that a value-dependent variable initializer implies the variable is
// unusable in constant expressions.
class EvaluateNonDependentExprVisitor
    : public clang::DynamicRecursiveASTVisitor {
public:
  explicit EvaluateNonDependentExprVisitor(clang::ASTContext &Ctx) : Ctx(Ctx) {}

  bool VisitDeclRefExpr(clang::DeclRefExpr *E) override {
    if (E->isValueDependent())
      return true;
    clang::Expr::EvalResult Result;
    // Should not crash regardless of whether evaluation succeeds.
    E->EvaluateAsRValue(Result, Ctx);
    return true;
  }

private:
  clang::ASTContext &Ctx;
};

class EvaluateNonDependentExprAction : public clang::ASTFrontendAction {
public:
  std::unique_ptr<clang::ASTConsumer>
  CreateASTConsumer(clang::CompilerInstance &Compiler,
                    llvm::StringRef FilePath) override {
    return std::make_unique<Consumer>();
  }

private:
  class Consumer : public clang::ASTConsumer {
  public:
    ~Consumer() override {}
    void HandleTranslationUnit(clang::ASTContext &Ctx) override {
      EvaluateNonDependentExprVisitor Evaluator(Ctx);
      Evaluator.TraverseDecl(Ctx.getTranslationUnitDecl());
    }
  };
};

TEST(EvaluateAsRValue, FailsGracefullyOnErrorRecoveryReference) {
  // The initializer of `x` is an error-recovery expression, which makes the
  // initializer value-dependent. References to `x`, however, are only
  // `contains-errors` and not value-dependent. Evaluating such a reference used
  // to hit an assertion in LValueExprEvaluator::VisitVarDecl.
  std::vector<std::string> Args(1, "-std=c++23");
  runToolOnCodeWithArgs(std::make_unique<EvaluateNonDependentExprAction>(),
                        "struct A { virtual int foo(); };\n"
                        "void foo() {\n"
                        "  A &x = *x;\n"
                        "  (void)&x;\n"
                        "}\n",
                        Args);
}
