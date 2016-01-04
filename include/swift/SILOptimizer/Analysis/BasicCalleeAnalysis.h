//===- BasicCalleeAnalysis.h - Determine callees per call site --*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_SILOPTIMIZER_ANALYSIS_BASICCALLEEANALYSIS_H
#define SWIFT_SILOPTIMIZER_ANALYSIS_BASICCALLEEANALYSIS_H

#include "swift/SILOptimizer/Analysis/Analysis.h"
#include "swift/SIL/SILFunction.h"
#include "swift/SIL/SILInstruction.h"
#include "swift/SIL/SILModule.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/PointerIntPair.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/TinyPtrVector.h"

namespace swift {
class ClassDecl;
class SILFunction;
class SILModule;
class SILWitnessTable;

/// CalleeList is a data structure representing the list of potential
/// callees at a particular apply site. It also has a query that
/// allows a client to determine whether the list is incomplete in the
/// sense that there may be unrepresented callees.
class CalleeList {
  llvm::TinyPtrVector<SILFunction *> CalleeFunctions;
  bool IsIncomplete;

public:
  /// Constructor for when we know nothing about the callees and must
  /// assume the worst.
  CalleeList() : IsIncomplete(true) {}

  /// Constructor for the case where we know an apply can target only
  /// a single function.
  CalleeList(SILFunction *F) : CalleeFunctions(F), IsIncomplete(false) {}

  /// Constructor for arbitrary lists of callees.
  CalleeList(llvm::SmallVectorImpl<SILFunction *> &List, bool IsIncomplete)
      : CalleeFunctions(llvm::makeArrayRef(List.begin(), List.end())),
        IsIncomplete(IsIncomplete) {}

  /// Return an iterator for the beginning of the list.
  ArrayRef<SILFunction *>::iterator begin() const {
    return CalleeFunctions.begin();
  }

  /// Return an iterator for the end of the list.
  ArrayRef<SILFunction *>::iterator end() const {
    return CalleeFunctions.end();
  }

  bool isIncomplete() const { return IsIncomplete; }

  /// Returns true if all callees are known and not external.
  bool allCalleesVisible();
};

/// CalleeCache is a helper class that builds lists of potential
/// callees for class and witness method applications, and provides an
/// interface for retrieving a (possibly incomplete) CalleeList for
/// any function application site (including those that are simple
/// function_ref, thin_to_thick, or partial_apply callees).
class CalleeCache {
  typedef llvm::SmallVector<SILFunction *, 4> Callees;
  typedef llvm::PointerIntPair<Callees *, 1> CalleesAndCanCallUnknown;
  typedef llvm::DenseMap<AbstractFunctionDecl *, CalleesAndCanCallUnknown>
      CacheType;

  SILModule &M;

  // The cache of precomputed callee lists for function decls appearing
  // in class virtual dispatch tables and witness tables.
  CacheType TheCache;

public:
  CalleeCache(SILModule &M) : M(M) {
    computeMethodCallees();
    sortAndUniqueCallees();
  }

  ~CalleeCache() {
    for (auto &Pair : TheCache) {
      auto *Callees = Pair.second.getPointer();
      delete Callees;
    }
  }

  /// Return the list of callees that can potentially be called at the
  /// given apply site.
  CalleeList getCalleeList(FullApplySite FAS) const;

private:
  void enumerateFunctionsInModule();
  void sortAndUniqueCallees();
  CalleesAndCanCallUnknown &getOrCreateCalleesForMethod(SILDeclRef Decl);
  void computeClassMethodCalleesForClass(ClassDecl *CD);
  void computeWitnessMethodCalleesForWitnessTable(SILWitnessTable &WT);
  void computeMethodCallees();
  SILFunction *getSingleCalleeForWitnessMethod(WitnessMethodInst *WMI) const;
  CalleeList getCalleeList(AbstractFunctionDecl *Decl) const;
  CalleeList getCalleeList(WitnessMethodInst *WMI) const;
  CalleeList getCalleeList(ClassMethodInst *CMI) const;
  CalleeList getCalleeListForCalleeKind(SILValue Callee) const;
};

class BasicCalleeAnalysis : public SILAnalysis {
  SILModule &M;
  CalleeCache *Cache;

public:
  BasicCalleeAnalysis(SILModule *M)
      : SILAnalysis(AnalysisKind::BasicCallee), M(*M), Cache(nullptr) {}

  static bool classof(const SILAnalysis *S) {
    return S->getKind() == AnalysisKind::BasicCallee;
  }

  virtual void invalidate(SILAnalysis::InvalidationKind K) {
    if (K & InvalidationKind::Functions) {
      delete Cache;
      Cache = nullptr;
    }
  }

  virtual void invalidate(SILFunction *F, InvalidationKind K) { invalidate(K); }

  CalleeList getCalleeList(FullApplySite FAS) {
    if (!Cache)
      Cache = new CalleeCache(M);

    return Cache->getCalleeList(FAS);
  }
};

} // end namespace swift

#endif
