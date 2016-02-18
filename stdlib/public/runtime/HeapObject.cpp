//===--- HeapObject.cpp - Swift Language ABI Allocation Support -----------===//
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
//
// Allocation ABI Shims While the Language is Bootstrapped
//
//===----------------------------------------------------------------------===//

#include "swift/Basic/Lazy.h"
#include "swift/Runtime/HeapObject.h"
#include "swift/Runtime/Heap.h"
#include "swift/Runtime/Metadata.h"
#include "swift/ABI/System.h"
#include "llvm/Support/MathExtras.h"
#include "MetadataCache.h"
#include "Private.h"
#include "swift/Runtime/Debug.h"
#include <algorithm>
#include <cassert>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include "../SwiftShims/RuntimeShims.h"
#if SWIFT_OBJC_INTEROP
# include <objc/NSObject.h>
# include <objc/runtime.h>
# include <objc/message.h>
# include <objc/objc.h>
#include "swift/Runtime/ObjCBridge.h"
#endif
#include "Leaks.h"

using namespace swift;

RT_ENTRY_VISIBILITY
HeapObject *
swift::swift_allocObject(HeapMetadata const *metadata,
                         size_t requiredSize,
                         size_t requiredAlignmentMask)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  assert(isAlignmentMask(requiredAlignmentMask));
  auto object = reinterpret_cast<HeapObject *>(
      RT_ENTRY_CALL(swift_slowAlloc)(requiredSize, requiredAlignmentMask));
  // FIXME: this should be a placement new but that adds a null check
  object->metadata = metadata;
  object->refCount.init();
  object->weakRefCount.init();

  // If leak tracking is enabled, start tracking this object.
  SWIFT_LEAKS_START_TRACKING_OBJECT(object);

  return object;
}

HeapObject *
swift::swift_initStackObject(HeapMetadata const *metadata,
                             HeapObject *object) {
  object->metadata = metadata;
  object->refCount.init();
  object->weakRefCount.initForNotDeallocating();

  return object;

}

void
swift::swift_verifyEndOfLifetime(HeapObject *object) {
  if (object->refCount.getCount() != 0)
    swift::fatalError(/* flags = */ 0,
                      "fatal error: stack object escaped\n");
  
  if (object->weakRefCount.getCount() != 1)
    swift::fatalError(/* flags = */ 0,
                      "fatal error: weak/unowned reference to stack object\n");
}

/// \brief Allocate a reference-counted object on the heap that
/// occupies <size> bytes of maximally-aligned storage.  The object is
/// uninitialized except for its header.
SWIFT_RUNTIME_EXPORT
extern "C" HeapObject* swift_bufferAllocate(
  HeapMetadata const* bufferType, size_t size, size_t alignMask)
{
  return swift::RT_ENTRY_CALL(swift_allocObject)(bufferType, size, alignMask);
}

/// \brief Another entrypoint for swift_bufferAllocate.
/// It is generated by the compiler in some corner cases, e.g. if a serialized
/// optimized module is imported into a non-optimized main module.
/// TODO: This is only a workaround. Remove this function as soon as we can
/// get rid of the llvm SwiftStackPromotion pass.
SWIFT_RUNTIME_EXPORT
extern "C" HeapObject* swift_bufferAllocateOnStack(
  HeapMetadata const* bufferType, size_t size, size_t alignMask) {
  return swift::RT_ENTRY_CALL(swift_allocObject)(bufferType, size, alignMask);
}

/// \brief Called at the end of the lifetime of an object returned by
/// swift_bufferAllocateOnStack.
/// It is generated by the compiler in some corner cases, e.g. if a serialized
/// optimized module is imported into a non-optimized main module.
/// TODO: This is only a workaround. Remove this function as soon as we can
/// get rid of the llvm SwiftStackPromotion pass.
SWIFT_RUNTIME_EXPORT
extern "C" void swift_bufferDeallocateFromStack(HeapObject *) {
}

SWIFT_RUNTIME_EXPORT
extern "C" intptr_t swift_bufferHeaderSize() { return sizeof(HeapObject); }

namespace {
/// Heap metadata for a box, which may have been generated statically by the
/// compiler or by the runtime.
struct BoxHeapMetadata : public HeapMetadata {
  /// The offset from the beginning of a box to its value.
  unsigned Offset;

  constexpr BoxHeapMetadata(MetadataKind kind,
                            unsigned offset)
    : HeapMetadata{kind}, Offset(offset)
  {}


};

/// Heap metadata for runtime-instantiated generic boxes.
struct GenericBoxHeapMetadata : public BoxHeapMetadata {
  /// The type inside the box.
  const Metadata *BoxedType;

  constexpr GenericBoxHeapMetadata(MetadataKind kind,
                                   unsigned offset,
                                   const Metadata *boxedType)
    : BoxHeapMetadata{kind, offset},
      BoxedType(boxedType)
  {}

  static unsigned getHeaderOffset(const Metadata *boxedType) {
    // Round up the header size to alignment.
    unsigned alignMask = boxedType->getValueWitnesses()->getAlignmentMask();
    return (sizeof(HeapObject) + alignMask) & ~alignMask;
  }

  /// Project the value out of a box of this type.
  OpaqueValue *project(HeapObject *box) const {
    auto bytes = reinterpret_cast<char*>(box);
    return reinterpret_cast<OpaqueValue *>(bytes + Offset);
  }

  /// Get the allocation size of this box.
  unsigned getAllocSize() const {
    return Offset + BoxedType->getValueWitnesses()->getSize();
  }

  /// Get the allocation alignment of this box.
  unsigned getAllocAlignMask() const {
    // Heap allocations are at least pointer aligned.
    return BoxedType->getValueWitnesses()->getAlignmentMask()
      | (alignof(void*) - 1);
  }
};

/// Heap object destructor for a generic box allocated with swift_allocBox.
static void destroyGenericBox(HeapObject *o) {
  auto metadata = static_cast<const GenericBoxHeapMetadata *>(o->metadata);
  // Destroy the object inside.
  auto *value = metadata->project(o);
  metadata->BoxedType->vw_destroy(value);

  // Deallocate the box.
  RT_ENTRY_CALL(swift_deallocObject) (o, metadata->getAllocSize(),
                                      metadata->getAllocAlignMask());
}

class BoxCacheEntry : public CacheEntry<BoxCacheEntry> {
public:
  FullMetadata<GenericBoxHeapMetadata> Metadata;

  BoxCacheEntry(size_t numArguments)
    : Metadata{HeapMetadataHeader{{destroyGenericBox}, {nullptr}},
               GenericBoxHeapMetadata{MetadataKind::HeapGenericLocalVariable, 0,
                                       nullptr}} {
    assert(numArguments == 1);
  }

  size_t getNumArguments() const {
    return 1;
  }

  static const char *getName() {
    return "BoxCache";
  }

  FullMetadata<GenericBoxHeapMetadata> *getData() {
    return &Metadata;
  }
  const FullMetadata<GenericBoxHeapMetadata> *getData() const {
    return &Metadata;
  }
};

} // end anonymous namespace

static Lazy<MetadataCache<BoxCacheEntry>> Boxes;

SWIFT_RUNTIME_EXPORT
BoxPair::Return
swift::swift_allocBox(const Metadata *type) {
  return RT_ENTRY_REF(swift_allocBox)(type);
}

RT_ENTRY_IMPL_VISIBILITY
extern "C"
BoxPair::Return RT_ENTRY_IMPL(swift_allocBox)(const Metadata *type) {
  // Get the heap metadata for the box.
  auto &B = Boxes.get();
  const void *typeArg = type;
  auto entry = B.findOrAdd(&typeArg, 1, [&]() -> BoxCacheEntry* {
    // Create a new entry for the box.
    auto entry = BoxCacheEntry::allocate(B.getAllocator(), &typeArg, 1, 0);

    auto metadata = entry->getData();
    metadata->Offset = GenericBoxHeapMetadata::getHeaderOffset(type);
    metadata->BoxedType = type;

    return entry;
  });

  auto metadata = entry->getData();

  // Allocate and project the box.
  auto allocation = RT_ENTRY_CALL(swift_allocObject)(
      metadata, metadata->getAllocSize(), metadata->getAllocAlignMask());
  auto projection = metadata->project(allocation);

  return BoxPair{allocation, projection};
}

void swift::swift_deallocBox(HeapObject *o) {
  auto metadata = static_cast<const GenericBoxHeapMetadata *>(o->metadata);
  RT_ENTRY_CALL(swift_deallocObject)(o, metadata->getAllocSize(),
                                     metadata->getAllocAlignMask());
}

OpaqueValue *swift::swift_projectBox(HeapObject *o) {
  // The compiler will use a nil reference as a way to avoid allocating memory
  // for boxes of empty type. The address of an empty value is always undefined,
  // so we can just return nil back in this case.
  if (!o)
    return reinterpret_cast<OpaqueValue*>(o);
  auto metadata = static_cast<const GenericBoxHeapMetadata *>(o->metadata);
  return metadata->project(o);
}

// Forward-declare this, but define it after swift_release.
extern "C" LLVM_LIBRARY_VISIBILITY
void _swift_release_dealloc(HeapObject *object)
  CALLING_CONVENTION(RegisterPreservingCC_IMPL)
  __attribute__((noinline,used));


RT_ENTRY_VISIBILITY
extern "C"
void swift::swift_retain(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  RT_ENTRY_REF(swift_retain)(object);
}

RT_ENTRY_IMPL_VISIBILITY
extern "C"
void RT_ENTRY_IMPL(swift_retain)(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  _swift_retain_inlined(object);
}

RT_ENTRY_VISIBILITY
extern "C"
void swift::swift_retain_n(HeapObject *object, uint32_t n)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  RT_ENTRY_REF(swift_retain_n)(object, n);
}

RT_ENTRY_IMPL_VISIBILITY
extern "C"
void RT_ENTRY_IMPL(swift_retain_n)(HeapObject *object, uint32_t n)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (object) {
    object->refCount.increment(n);
  }
}

RT_ENTRY_VISIBILITY
extern "C"
void swift::swift_release(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  RT_ENTRY_REF(swift_release)(object);
}

RT_ENTRY_IMPL_VISIBILITY
extern "C"
void RT_ENTRY_IMPL(swift_release)(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (object  &&  object->refCount.decrementShouldDeallocate()) {
    _swift_release_dealloc(object);
  }
}

RT_ENTRY_VISIBILITY
void swift::swift_release_n(HeapObject *object, uint32_t n)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  return RT_ENTRY_REF(swift_release_n)(object, n);
}

RT_ENTRY_IMPL_VISIBILITY
extern "C"
void RT_ENTRY_IMPL(swift_release_n)(HeapObject *object, uint32_t n)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (object && object->refCount.decrementShouldDeallocateN(n)) {
    _swift_release_dealloc(object);
  }
}

size_t swift::swift_retainCount(HeapObject *object) {
  return object->refCount.getCount();
}

size_t swift::swift_unownedRetainCount(HeapObject *object) {
  return object->weakRefCount.getCount();
}

RT_ENTRY_VISIBILITY
void swift::swift_unownedRetain(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  object->weakRefCount.increment();
}

RT_ENTRY_VISIBILITY
void swift::swift_unownedRelease(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  if (object->weakRefCount.decrementShouldDeallocate()) {
    // Only class objects can be weak-retained and weak-released.
    auto metadata = object->metadata;
    assert(metadata->isClassObject());
    auto classMetadata = static_cast<const ClassMetadata*>(metadata);
    assert(classMetadata->isTypeMetadata());
    RT_ENTRY_CALL(swift_slowDealloc) (object, classMetadata->getInstanceSize(),
                                      classMetadata->getInstanceAlignMask());
  }
}

RT_ENTRY_VISIBILITY
extern "C"
void swift::swift_unownedRetain_n(HeapObject *object, int n)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  object->weakRefCount.increment(n);
}

RT_ENTRY_VISIBILITY
extern "C"
void swift::swift_unownedRelease_n(HeapObject *object, int n)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  if (object->weakRefCount.decrementShouldDeallocateN(n)) {
    // Only class objects can be weak-retained and weak-released.
    auto metadata = object->metadata;
    assert(metadata->isClassObject());
    auto classMetadata = static_cast<const ClassMetadata*>(metadata);
    assert(classMetadata->isTypeMetadata());
    RT_ENTRY_CALL(swift_slowDealloc)(object, classMetadata->getInstanceSize(),
                                     classMetadata->getInstanceAlignMask());
  }
}

RT_ENTRY_VISIBILITY
HeapObject *swift::swift_tryPin(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  assert(object);

  // Try to set the flag.  If this succeeds, the caller will be
  // responsible for clearing it.
  if (object->refCount.tryIncrementAndPin()) {
    return object;
  }

  // If setting the flag failed, it's because it was already set.
  // Return nil so that the object will be deallocated later.
  return nullptr;
}

RT_ENTRY_VISIBILITY
void swift::swift_unpin(HeapObject *object)
  CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (object && object->refCount.decrementAndUnpinShouldDeallocate()) {
    _swift_release_dealloc(object);
  }
}

RT_ENTRY_VISIBILITY
HeapObject *swift::swift_tryRetain(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  return RT_ENTRY_REF(swift_tryRetain)(object);
}

RT_ENTRY_IMPL_VISIBILITY
extern "C"
HeapObject *RT_ENTRY_IMPL(swift_tryRetain)(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (!object)
    return nullptr;

  if (object->refCount.tryIncrement()) return object;
  else return nullptr;
}

SWIFT_RUNTIME_EXPORT
extern "C"
bool swift_isDeallocating(HeapObject *object) {
  return RT_ENTRY_REF(swift_isDeallocating)(object);
}

RT_ENTRY_IMPL_VISIBILITY
extern "C"
bool RT_ENTRY_IMPL(swift_isDeallocating)(HeapObject *object) {
  if (!object) return false;
  return object->refCount.isDeallocating();
}

RT_ENTRY_VISIBILITY
void swift::swift_unownedRetainStrong(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (!object)
    return;
  assert(object->weakRefCount.getCount() &&
         "object is not currently weakly retained");

  if (! object->refCount.tryIncrement())
    _swift_abortRetainUnowned(object);
}

RT_ENTRY_VISIBILITY
void
swift::swift_unownedRetainStrongAndRelease(HeapObject *object)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  if (!object)
    return;
  assert(object->weakRefCount.getCount() &&
         "object is not currently weakly retained");

  if (! object->refCount.tryIncrement())
    _swift_abortRetainUnowned(object);

  // This should never cause a deallocation.
  bool dealloc = object->weakRefCount.decrementShouldDeallocate();
  assert(!dealloc && "retain-strong-and-release caused dealloc?");
  (void) dealloc;
}

void swift::swift_unownedCheck(HeapObject *object) {
  if (!object) return;
  assert(object->weakRefCount.getCount() &&
         "object is not currently weakly retained");

  if (object->refCount.isDeallocating())
    _swift_abortRetainUnowned(object);
}

// Declared extern "C" LLVM_LIBRARY_VISIBILITY above.
void _swift_release_dealloc(HeapObject *object)
  CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  asFullMetadata(object->metadata)->destroy(object);
}

#if SWIFT_OBJC_INTEROP
/// Perform the root -dealloc operation for a class instance.
void swift::swift_rootObjCDealloc(HeapObject *self) {
  auto metadata = self->metadata;
  assert(metadata->isClassObject());
  auto classMetadata = static_cast<const ClassMetadata*>(metadata);
  assert(classMetadata->isTypeMetadata());
  swift_deallocClassInstance(self, classMetadata->getInstanceSize(),
                             classMetadata->getInstanceAlignMask());
}
#endif

void swift::swift_deallocClassInstance(HeapObject *object,
                                       size_t allocatedSize,
                                       size_t allocatedAlignMask) {
#if SWIFT_OBJC_INTEROP
  // We need to let the ObjC runtime clean up any associated objects or weak
  // references associated with this object.
  objc_destructInstance((id)object);
#endif
  RT_ENTRY_CALL(swift_deallocObject)(object, allocatedSize, allocatedAlignMask);
}

/// Variant of the above used in constructor failure paths.
SWIFT_RUNTIME_EXPORT
extern "C" void swift_deallocPartialClassInstance(HeapObject *object,
                                                  HeapMetadata const *metadata,
                                                  size_t allocatedSize,
                                                  size_t allocatedAlignMask) {
  if (!object)
    return;

  // Destroy ivars
  auto *objectMetadata = _swift_getClassOfAllocated(object);
  while (objectMetadata != metadata) {
    auto classMetadata = objectMetadata->getClassObject();
    assert(classMetadata && "Not a class?");
    if (auto fn = classMetadata->getIVarDestroyer())
      fn(object);
    objectMetadata = classMetadata->SuperClass;
    assert(objectMetadata && "Given metatype not a superclass of object type?");
  }

  // The strong reference count should be +1 -- tear down the object
  bool shouldDeallocate = object->refCount.decrementShouldDeallocate();
  assert(shouldDeallocate);
  (void) shouldDeallocate;
  swift_deallocClassInstance(object, allocatedSize, allocatedAlignMask);
}

#if !defined(__APPLE__)
static inline void memset_pattern8(void *b, const void *pattern8, size_t len) {
  char *ptr = static_cast<char *>(b);
  while (len >= 8) {
    memcpy(ptr, pattern8, 8);
    ptr += 8;
    len -= 8;
  }
  memcpy(ptr, pattern8, len);
}
#endif

RT_ENTRY_VISIBILITY
void swift::swift_deallocObject(HeapObject *object,
                                size_t allocatedSize,
                                size_t allocatedAlignMask)
    CALLING_CONVENTION(RegisterPreservingCC_IMPL) {
  assert(isAlignmentMask(allocatedAlignMask));
  assert(object->refCount.isDeallocating());
#ifdef SWIFT_RUNTIME_CLOBBER_FREED_OBJECTS
  memset_pattern8((uint8_t *)object + sizeof(HeapObject),
                  "\xAB\xAD\x1D\xEA\xF4\xEE\xD0\bB9",
                  allocatedSize - sizeof(HeapObject));
#endif

  // If we are tracking leaks, stop tracking this object.
  SWIFT_LEAKS_STOP_TRACKING_OBJECT(object);

  // Drop the initial weak retain of the object.
  //
  // If the outstanding weak retain count is 1 (i.e. only the initial
  // weak retain), we can immediately call swift_slowDealloc.  This is
  // useful both as a way to eliminate an unnecessary atomic
  // operation, and as a way to avoid calling swift_unownedRelease on an
  // object that might be a class object, which simplifies the logic
  // required in swift_unownedRelease for determining the size of the
  // object.
  //
  // If we see that there is an outstanding weak retain of the object,
  // we need to fall back on swift_release, because it's possible for
  // us to race against a weak retain or a weak release.  But if the
  // outstanding weak retain count is 1, then anyone attempting to
  // increase the weak reference count is inherently racing against
  // deallocation and thus in undefined-behavior territory.  And
  // we can even do this with a normal load!  Here's why:
  //
  // 1. There is an invariant that, if the strong reference count
  // is > 0, then the weak reference count is > 1.
  //
  // 2. The above lets us say simply that, in the absence of
  // races, once a reference count reaches 0, there are no points
  // which happen-after where the reference count is > 0.
  //
  // 3. To not race, a strong retain must happen-before a point
  // where the strong reference count is > 0, and a weak retain
  // must happen-before a point where the weak reference count
  // is > 0.
  //
  // 4. Changes to either the strong and weak reference counts occur
  // in a total order with respect to each other.  This can
  // potentially be done with a weaker memory ordering than
  // sequentially consistent if the architecture provides stronger
  // ordering for memory guaranteed to be co-allocated on a cache
  // line (which the reference count fields are).
  //
  // 5. This function happens-after a point where the strong
  // reference count was 0.
  //
  // 6. Therefore, if a normal load in this function sees a weak
  // reference count of 1, it cannot be racing with a weak retain
  // that is not racing with deallocation:
  //
  //   - A weak retain must happen-before a point where the weak
  //     reference count is > 0.
  //
  //   - This function logically decrements the weak reference
  //     count.  If it is possible for it to see a weak reference
  //     count of 1, then at the end of this function, the
  //     weak reference count will logically be 0.
  //
  //   - There can be no points after that point where the
  //     weak reference count will be > 0.
  //
  //   - Therefore either the weak retain must happen-before this
  //     function, or this function cannot see a weak reference
  //     count of 1, or there is a race.
  //
  // Note that it is okay for there to be a race involving a weak
  // *release* which happens after the strong reference count drops to
  // 0.  However, this is harmless: if our load fails to see the
  // release, we will fall back on swift_unownedRelease, which does an
  // atomic decrement (and has the ability to reconstruct
  // allocatedSize and allocatedAlignMask).
  if (object->weakRefCount.getCount() == 1) {
    RT_ENTRY_CALL(swift_slowDealloc)(object, allocatedSize, allocatedAlignMask);
  } else {
    RT_ENTRY_CALL(swift_unownedRelease)(object);
  }
}

void swift::swift_weakInit(WeakReference *ref, HeapObject *value) {
  ref->Value = value;
  RT_ENTRY_CALL(swift_unownedRetain)(value);
}

void swift::swift_weakAssign(WeakReference *ref, HeapObject *newValue) {
  RT_ENTRY_CALL(swift_unownedRetain)(newValue);
  auto oldValue = ref->Value;
  ref->Value = newValue;
  RT_ENTRY_CALL(swift_unownedRelease)(oldValue);
}

HeapObject *swift::swift_weakLoadStrong(WeakReference *ref) {
  auto object = ref->Value;
  if (object == nullptr) return nullptr;
  if (object->refCount.isDeallocating()) {
    RT_ENTRY_CALL(swift_unownedRelease)(object);
    ref->Value = nullptr;
    return nullptr;
  }
  return swift_tryRetain(object);
}

HeapObject *swift::swift_weakTakeStrong(WeakReference *ref) {
  auto result = swift_weakLoadStrong(ref);
  swift_weakDestroy(ref);
  return result;
}

void swift::swift_weakDestroy(WeakReference *ref) {
  auto tmp = ref->Value;
  ref->Value = nullptr;
  RT_ENTRY_CALL(swift_unownedRelease)(tmp);
}

void swift::swift_weakCopyInit(WeakReference *dest, WeakReference *src) {
  auto object = src->Value;
  if (object == nullptr) {
    dest->Value = nullptr;
  } else if (object->refCount.isDeallocating()) {
    src->Value = nullptr;
    dest->Value = nullptr;
    RT_ENTRY_CALL(swift_unownedRelease)(object);
  } else {
    dest->Value = object;
    RT_ENTRY_CALL(swift_unownedRetain)(object);
  }
}

void swift::swift_weakTakeInit(WeakReference *dest, WeakReference *src) {
  auto object = src->Value;
  dest->Value = object;
  if (object != nullptr && object->refCount.isDeallocating()) {
    dest->Value = nullptr;
    RT_ENTRY_CALL(swift_unownedRelease)(object);
  }
}

void swift::swift_weakCopyAssign(WeakReference *dest, WeakReference *src) {
  if (auto object = dest->Value) {
    RT_ENTRY_CALL(swift_unownedRelease)(object);
  }
  swift_weakCopyInit(dest, src);
}

void swift::swift_weakTakeAssign(WeakReference *dest, WeakReference *src) {
  if (auto object = dest->Value) {
    RT_ENTRY_CALL(swift_unownedRelease)(object);
  }
  swift_weakTakeInit(dest, src);
}

void swift::_swift_abortRetainUnowned(const void *object) {
  (void)object;
  swift::crash("attempted to retain deallocated object");
}
