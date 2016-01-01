//===--- SILGenProlog.cpp - Function prologue emission --------------------===//
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

#include "SILGenFunction.h"
#include "Initialization.h"
#include "ManagedValue.h"
#include "Scope.h"
#include "swift/SIL/SILArgument.h"
#include "swift/AST/Parameter.h"
#include "swift/Basic/Fallthrough.h"

using namespace swift;
using namespace Lowering;

SILValue SILGenFunction::emitSelfDecl(VarDecl *selfDecl) {
  // Emit the implicit 'self' argument.
  SILType selfType = getLoweredLoadableType(selfDecl->getType());
  SILValue selfValue = new (SGM.M) SILArgument(F.begin(), selfType, selfDecl);
  VarLocs[selfDecl] = VarLoc::get(selfValue);
  SILLocation PrologueLoc(selfDecl);
  PrologueLoc.markAsPrologue();
  unsigned ArgNo = 1; // Hardcoded for destructors.
  B.createDebugValue(PrologueLoc, selfValue, {selfDecl->isLet(), ArgNo});
  return selfValue;
}

namespace {

/// Cleanup that writes back to an inout argument on function exit.
class CleanupWriteBackToInOut : public Cleanup {
  VarDecl *var;
  SILValue inoutAddr;

public:
  CleanupWriteBackToInOut(VarDecl *var, SILValue inoutAddr)
    : var(var), inoutAddr(inoutAddr) {}

  void emit(SILGenFunction &gen, CleanupLocation l) override {
    // Assign from the local variable to the inout address with an
    // 'autogenerated' copyaddr.
    l.markAutoGenerated();
    gen.B.createCopyAddr(l, gen.VarLocs[var].value, inoutAddr,
                         IsNotTake, IsNotInitialization);
  }
};
} // end anonymous namespace

  
namespace {
class StrongReleaseCleanup : public Cleanup {
  SILValue box;
public:
  StrongReleaseCleanup(SILValue box) : box(box) {}
  void emit(SILGenFunction &gen, CleanupLocation l) override {
    gen.B.emitStrongReleaseAndFold(l, box);
  }
};
} // end anonymous namespace


namespace {
class EmitBBArguments : public CanTypeVisitor<EmitBBArguments,
                                              /*RetTy*/ ManagedValue>
{
public:
  SILGenFunction &gen;
  SILBasicBlock *parent;
  SILLocation loc;
  bool functionArgs;
  ArrayRef<SILParameterInfo> &parameters;

  EmitBBArguments(SILGenFunction &gen, SILBasicBlock *parent,
                  SILLocation l, bool functionArgs,
                  ArrayRef<SILParameterInfo> &parameters)
    : gen(gen), parent(parent), loc(l), functionArgs(functionArgs),
      parameters(parameters) {}

  ManagedValue getManagedValue(SILValue arg, CanType t,
                                 SILParameterInfo parameterInfo) const {
    switch (parameterInfo.getConvention()) {
    case ParameterConvention::Direct_Deallocating:
      // If we have a deallocating parameter, it is passed in at +0 and will not
      // be deallocated since we do not allow for resurrection.
      return ManagedValue::forUnmanaged(arg);

    case ParameterConvention::Direct_Guaranteed:
    case ParameterConvention::Indirect_In_Guaranteed:
      // If we have a guaranteed parameter, it is passed in at +0, and its
      // lifetime is guaranteed. We can potentially use the argument as-is
      // if the parameter is bound as a 'let' without cleaning up.
      return ManagedValue::forUnmanaged(arg);

    case ParameterConvention::Direct_Unowned:
      // An unowned parameter is passed at +0, like guaranteed, but it isn't
      // kept alive by the caller, so we need to retain and manage it
      // regardless.
      return gen.emitManagedRetain(loc, arg);

    case ParameterConvention::Indirect_Inout:
    case ParameterConvention::Indirect_InoutAliasable:
      // An inout parameter is +0 and guaranteed, but represents an lvalue.
      return ManagedValue::forLValue(arg);

    case ParameterConvention::Direct_Owned:
    case ParameterConvention::Indirect_In:
      // An owned or 'in' parameter is passed in at +1. We can claim ownership
      // of the parameter and clean it up when it goes out of scope.
      return gen.emitManagedRValueWithCleanup(arg);

    case ParameterConvention::Indirect_Out:
      llvm_unreachable("should not emit @out parameters here");
    }
  }

  ManagedValue visitType(CanType t) {
    auto argType = gen.getLoweredType(t);
    // Pop the next parameter info.
    auto parameterInfo = parameters.front();
    parameters = parameters.slice(1);
    assert(argType == parent->getParent()
                            ->mapTypeIntoContext(parameterInfo.getSILType()) &&
           "argument does not have same type as specified by parameter info");

    SILValue arg = new (gen.SGM.M)
      SILArgument(parent, argType, loc.getAsASTNode<ValueDecl>());
    ManagedValue mv = getManagedValue(arg, t, parameterInfo);

    // If the value is a (possibly optional) ObjC block passed into the entry
    // point of the function, then copy it so we can treat the value reliably
    // as a heap object. Escape analysis can eliminate this copy if it's
    // unneeded during optimization.
    CanType objectType = t;
    if (auto theObjTy = t.getAnyOptionalObjectType())
      objectType = theObjTy;
    if (functionArgs
        && isa<FunctionType>(objectType)
        && cast<FunctionType>(objectType)->getRepresentation()
              == FunctionType::Representation::Block) {
      SILValue blockCopy = gen.B.createCopyBlock(loc, mv.getValue());
      mv = gen.emitManagedRValueWithCleanup(blockCopy);
    }
    return mv;
  }

  ManagedValue visitTupleType(CanTupleType t) {
    SmallVector<ManagedValue, 4> elements;

    auto &tl = gen.getTypeLowering(t);
    bool canBeGuaranteed = tl.isLoadable();

    // Collect the exploded elements.
    for (auto fieldType : t.getElementTypes()) {
      auto elt = visit(fieldType);
      // If we can't borrow one of the elements as a guaranteed parameter, then
      // we have to +1 the tuple.
      if (elt.hasCleanup())
        canBeGuaranteed = false;
      elements.push_back(elt);
    }

    if (tl.isLoadable()) {
      SmallVector<SILValue, 4> elementValues;
      if (canBeGuaranteed) {
        // If all of the elements were guaranteed, we can form a guaranteed tuple.
        for (auto element : elements)
          elementValues.push_back(element.getUnmanagedValue());
      } else {
        // Otherwise, we need to move or copy values into a +1 tuple.
        for (auto element : elements) {
          SILValue value = element.hasCleanup()
            ? element.forward(gen)
            : element.copyUnmanaged(gen, loc).forward(gen);
          elementValues.push_back(value);
        }
      }
      auto tupleValue = gen.B.createTuple(loc, tl.getLoweredType(),
                                          elementValues);
      return canBeGuaranteed
        ? ManagedValue::forUnmanaged(tupleValue)
        : gen.emitManagedRValueWithCleanup(tupleValue);
    } else {
      // If the type is address-only, we need to move or copy the elements into
      // a tuple in memory.
      // TODO: It would be a bit more efficient to use a preallocated buffer
      // in this case.
      auto buffer = gen.emitTemporaryAllocation(loc, tl.getLoweredType());
      for (auto i : indices(elements)) {
        auto element = elements[i];
        auto elementBuffer = gen.B.createTupleElementAddr(loc, buffer,
                                        i, element.getType().getAddressType());
        if (element.hasCleanup())
          element.forwardInto(gen, loc, elementBuffer);
        else
          element.copyInto(gen, elementBuffer, loc);
      }
      return gen.emitManagedRValueWithCleanup(buffer);
    }
  }
};
} // end anonymous namespace

  
namespace {

/// A helper for creating SILArguments and binding variables to the argument
/// names.
struct ArgumentInitHelper {
  SILGenFunction &gen;
  SILFunction &f;
  SILGenBuilder &initB;

  /// An ArrayRef that we use in our SILParameterList queue. Parameters are
  /// sliced off of the front as they're emitted.
  ArrayRef<SILParameterInfo> parameters;
  unsigned ArgNo = 0;

  ArgumentInitHelper(SILGenFunction &gen, SILFunction &f)
    : gen(gen), f(f), initB(gen.B),
      parameters(f.getLoweredFunctionType()->getParameters()) {
    // If we have an out parameter, skip it.
    if (parameters.size() && parameters[0].isIndirectResult())
      parameters = parameters.slice(1);
  }

  unsigned getNumArgs() const { return ArgNo; }

  ManagedValue makeArgument(Type ty, SILBasicBlock *parent, SILLocation l) {
    assert(ty && "no type?!");

    // Create an RValue by emitting destructured arguments into a basic block.
    CanType canTy = ty->getCanonicalType();
    return EmitBBArguments(gen, parent, l, /*functionArgs*/ true,
                           parameters).visit(canTy);
  }

  /// Create a SILArgument and store its value into the given Initialization,
  /// if not null.
  void makeArgumentIntoBinding(Type ty, SILBasicBlock *parent, VarDecl *vd) {
    SILLocation loc(vd);
    loc.markAsPrologue();

    ManagedValue argrv = makeArgument(ty, parent, loc);

    // Create a shadow copy of inout parameters so they can be captured
    // by closures. The InOutDeshadowing guaranteed optimization will
    // eliminate the variable if it is not needed.
    if (auto inOutTy = vd->getType()->getAs<InOutType>()) {

      SILValue address = argrv.getUnmanagedValue();

      CanType objectType = inOutTy->getObjectType()->getCanonicalType();

      // As a special case, don't introduce a local variable for
      // Builtin.UnsafeValueBuffer, which is not copyable.
      if (isa<BuiltinUnsafeValueBufferType>(objectType)) {
        // FIXME: mark a debug location?
        gen.VarLocs[vd] = SILGenFunction::VarLoc::get(address);
        gen.B.createDebugValueAddr(loc, address, {vd->isLet(), ArgNo});
        return;
      }

      // Allocate the local variable for the inout.
      auto initVar = gen.emitLocalVariableWithCleanup(vd, false, ArgNo);

      // Initialize with the value from the inout with an "autogenerated"
      // copyaddr.
      loc.markAutoGenerated();
      gen.B.createCopyAddr(loc, address, initVar->getAddress(),
                           IsNotTake, IsInitialization);
      initVar->finishInitialization(gen);

      // Set up a cleanup to write back to the inout.
      gen.Cleanups.pushCleanup<CleanupWriteBackToInOut>(vd, address);
    } else if (vd->isLet()) {
      // If the variable is immutable, we can bind the value as is.
      // Leave the cleanup on the argument, if any, in place to consume the
      // argument if we're responsible for it.
      gen.VarLocs[vd] = SILGenFunction::VarLoc::get(argrv.getValue());
      if (argrv.getType().isAddress())
        gen.B.createDebugValueAddr(loc, argrv.getValue(), {vd->isLet(), ArgNo});
      else
        gen.B.createDebugValue(loc, argrv.getValue(), {vd->isLet(), ArgNo});
    } else {
      // If the variable is mutable, we need to copy or move the argument
      // value to local mutable memory.

      auto initVar = gen.emitLocalVariableWithCleanup(vd, false, ArgNo);

      // If we have a cleanup on the value, we can move it into the variable.
      if (argrv.hasCleanup())
        argrv.forwardInto(gen, loc, initVar->getAddress());
      // Otherwise, we need an independently-owned copy.
      else
        argrv.copyInto(gen, initVar->getAddress(), loc);

      initVar->finishInitialization(gen);
    }
  }

  void emitParam(Parameter &param) {
    ++ArgNo;
    auto PD = param.decl;
    if (PD->hasName()) {
      makeArgumentIntoBinding(PD->getType(), &*f.begin(), PD);
      return;
    }
    
    ManagedValue argrv = makeArgument(PD->getType(), &*f.begin(), PD);
    // Emit debug information for the argument.
    SILLocation loc(PD);
    loc.markAsPrologue();
    if (argrv.getType().isAddress())
      gen.B.createDebugValueAddr(loc, argrv.getValue(), {PD->isLet(), ArgNo});
    else
      gen.B.createDebugValue(loc, argrv.getValue(), {PD->isLet(), ArgNo});

    // A value bound to _ is unused and can be immediately released.
    Scope discardScope(gen.Cleanups, CleanupLocation(PD));
    // Popping the scope destroys the value.
  }
};
} // end anonymous namespace

  
static void makeArgument(Type ty, ParamDecl *decl,
                         SmallVectorImpl<SILValue> &args, SILGenFunction &gen) {
  assert(ty && "no type?!");
  
  // Destructure tuple arguments.
  if (TupleType *tupleTy = ty->getAs<TupleType>()) {
    for (auto fieldType : tupleTy->getElementTypes())
      makeArgument(fieldType, decl, args, gen);
  } else {
    auto arg = new (gen.F.getModule()) SILArgument(gen.F.begin(),
                                                   gen.getLoweredType(ty),decl);
    args.push_back(arg);
  }
}


void SILGenFunction::bindParametersForForwarding(const ParameterList *params,
                                     SmallVectorImpl<SILValue> &parameters) {
  for (auto &param : *params) {
    makeArgument(param.decl->getType(), param.decl, parameters, *this);
  }
}

static void emitCaptureArguments(SILGenFunction &gen, CapturedValue capture,
                                 unsigned ArgNo) {
  auto *VD = capture.getDecl();
  auto type = VD->getType();
  SILLocation Loc(VD);
  Loc.markAsPrologue();
  switch (gen.SGM.Types.getDeclCaptureKind(capture)) {
  case CaptureKind::None:
    break;

  case CaptureKind::Constant: {
    auto &lowering = gen.getTypeLowering(VD->getType());
    // Constant decls are captured by value.
    SILType ty = lowering.getLoweredType();
    SILValue val = new (gen.SGM.M) SILArgument(gen.F.begin(), ty, VD);

    // If the original variable was settable, then Sema will have treated the
    // VarDecl as an lvalue, even in the closure's use.  As such, we need to
    // allow formation of the address for this captured value.  Create a
    // temporary within the closure to provide this address.
    if (VD->isSettable(VD->getDeclContext())) {
      auto addr = gen.emitTemporaryAllocation(VD, ty);
      gen.B.createStore(VD, val, addr);
      val = addr;
    }

    gen.VarLocs[VD] = SILGenFunction::VarLoc::get(val);
    if (auto *AllocStack = dyn_cast<AllocStackInst>(val))
      AllocStack->setArgNo(ArgNo);
    else 
      gen.B.createDebugValue(Loc, val, {/*Constant*/true, ArgNo});

    // TODO: Closure contexts should always be guaranteed.
    if (!gen.SGM.M.getOptions().EnableGuaranteedClosureContexts
        && !lowering.isTrivial())
      gen.enterDestroyCleanup(val);
    break;
  }

  case CaptureKind::Box: {
    // LValues are captured as a retained @box that owns
    // the captured value.
    SILType ty = gen.getLoweredType(type).getAddressType();
    SILType boxTy = SILType::getPrimitiveObjectType(
      SILBoxType::get(ty.getSwiftRValueType()));
    SILValue box = new (gen.SGM.M) SILArgument(gen.F.begin(), boxTy, VD);
    SILValue addr = gen.B.createProjectBox(VD, box);
    gen.VarLocs[VD] = SILGenFunction::VarLoc::get(addr, box);
    gen.B.createDebugValueAddr(Loc, addr, {/*Constant*/false, ArgNo});
    if (!gen.SGM.M.getOptions().EnableGuaranteedClosureContexts)
      gen.Cleanups.pushCleanup<StrongReleaseCleanup>(box);
    break;
  }
  case CaptureKind::StorageAddress: {
    // Non-escaping stored decls are captured as the address of the value.
    SILType ty = gen.getLoweredType(type).getAddressType();
    SILValue addr = new (gen.SGM.M) SILArgument(gen.F.begin(), ty, VD);
    gen.VarLocs[VD] = SILGenFunction::VarLoc::get(addr);
    gen.B.createDebugValueAddr(Loc, addr, {/*Constant*/true, ArgNo});
    break;
  }
  }
}

void SILGenFunction::emitProlog(AnyFunctionRef TheClosure,
                                ArrayRef<ParameterList*> paramPatterns,
                                Type resultType) {
  unsigned ArgNo =
    emitProlog(paramPatterns, resultType, TheClosure.getAsDeclContext());

  // Emit the capture argument variables. These are placed last because they
  // become the first curry level of the SIL function.
  auto captureInfo = SGM.Types.getLoweredLocalCaptures(TheClosure);
  for (auto capture : captureInfo.getCaptures())
    emitCaptureArguments(*this, capture, ++ArgNo);
}

unsigned SILGenFunction::emitProlog(ArrayRef<ParameterList*> paramLists,
                                    Type resultType, DeclContext *DeclCtx) {
  // If the return type is address-only, emit the indirect return argument.
  const TypeLowering &returnTI = getTypeLowering(resultType);
  if (returnTI.isReturnedIndirectly()) {
    auto &AC = getASTContext();
    auto VD = new (AC) ParamDecl(/*IsLet*/ false, SourceLoc(),
                                 AC.getIdentifier("$return_value"), SourceLoc(),
                                 AC.getIdentifier("$return_value"), resultType,
                                 DeclCtx);
    IndirectReturnAddress = new (SGM.M)
      SILArgument(F.begin(), returnTI.getLoweredType(), VD);
  }

  // Emit the argument variables in calling convention order.
  ArgumentInitHelper emitter(*this, F);

  for (ParameterList *paramList : reversed(paramLists)) {
    // Add the SILArguments and use them to initialize the local argument
    // values.
    for (auto &param : *paramList)
      emitter.emitParam(param);
  }
  return emitter.getNumArgs();
}

