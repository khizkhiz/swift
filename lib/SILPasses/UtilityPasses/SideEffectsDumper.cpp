//===------- SideEffectsDumper.cpp - Dumps the side effect analysis -------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "dump-sea"
#include "swift/SILPasses/Passes.h"
#include "swift/SILAnalysis/SideEffectAnalysis.h"
#include "swift/SILPasses/Transforms.h"

using namespace swift;

namespace {

/// Dumps the side-effect information of all functions in the module.
/// Only dumps if the compiler is built with assertions.
/// For details see SideEffectAnalysis.
class SideEffectsDumper : public SILModuleTransform {

  void run() override {

    DEBUG(llvm::dbgs() << "** SideEffectsDumper **\n");

    auto *SEA = PM->getAnalysis<SideEffectAnalysis>();

#ifndef NDEBUG
    llvm::outs() << "Side effects of module\n";
    for (auto &F : *getModule()) {
      llvm::outs() << "  sil @" << F.getName() << '\n';
      const auto &Effects = SEA->getEffects(&F);
      llvm::outs() << "    <" << Effects << ">\n";
    }
#endif
  }

  StringRef getName() override { return "SideEffectsDumper"; }
};

} // end anonymous namespace

SILTransform *swift::createSideEffectsDumper() {
  return new SideEffectsDumper();
}
