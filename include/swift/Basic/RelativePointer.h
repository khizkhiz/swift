//===-- RelativePointer.h - Relative Pointer Support ------------*- C++ -*-===//
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
//
// Some data structures emitted by the Swift compiler use relative indirect
// addresses in order to minimize startup cost for a process. By referring to
// the offset of the global offset table entry for a symbol, instead of directly
// referring to the symbol, compiler-emitted data structures avoid requiring
// unnecessary relocation at dynamic linking time. This header contains types
// to help dereference these relative addresses.
//
//===----------------------------------------------------------------------===//

#include <cstdint>

namespace swift {

/// A relative reference to an object stored in memory. The reference may be
/// direct or indirect, and uses the low bit of the (assumed at least
/// 2-byte-aligned) pointer to differentiate.
template<typename ValueTy, bool Nullable = false>
class RelativeIndirectablePointer {
private:
  /// The relative offset of the pointer's memory from the `this` pointer.
  /// If the low bit is clear, this is a direct reference; otherwise, it is
  /// an indirect reference.
  int32_t RelativeOffset;

  /// RelativePointers should appear in statically-generated metadata. They
  /// shouldn't be constructed or copied.
  RelativeIndirectablePointer() = delete;
  RelativeIndirectablePointer(RelativeIndirectablePointer &&) = delete;
  RelativeIndirectablePointer(const RelativeIndirectablePointer &) = delete;
  RelativeIndirectablePointer &operator=(RelativeIndirectablePointer &&)
    = delete;
  RelativeIndirectablePointer &operator=(const RelativeIndirectablePointer &)
    = delete;

public:
  const ValueTy *get() const & {
    // Check for null.
    if (Nullable && RelativeOffset == 0)
      return nullptr;
    
    // The pointer is offset relative to `this`.
    auto base = reinterpret_cast<intptr_t>(this);
    intptr_t address = base + (RelativeOffset & ~1);

    // If the low bit is set, then this is an indirect address. Otherwise,
    // it's direct.
    if (RelativeOffset & 1) {
      return *reinterpret_cast<const ValueTy * const *>(address);
    } else {
      return reinterpret_cast<const ValueTy *>(address);
    }
  }
  
  operator const ValueTy* () const & {
    return get();
  }

  const ValueTy &operator*() const & {
    return *get();
  }

  const ValueTy *operator->() const & {
    return get();
  }
};

/// A relative reference to a function, intended to reference private metadata
/// functions for the current executable or dynamic library image from
/// position-independent constant data.
template<typename T, bool Nullable>
class RelativeDirectPointerImpl {
private:
  /// The relative offset of the function's entry point from *this.
  int32_t RelativeOffset;

  /// RelativePointers should appear in statically-generated metadata. They
  /// shouldn't be constructed or copied.
  RelativeDirectPointerImpl() = delete;
  RelativeDirectPointerImpl(RelativeDirectPointerImpl &&) = delete;
  RelativeDirectPointerImpl(const RelativeDirectPointerImpl &) = delete;
  RelativeDirectPointerImpl &operator=(RelativeDirectPointerImpl &&)
    = delete;
  RelativeDirectPointerImpl &operator=(const RelativeDirectPointerImpl&)
    = delete;

public:
  using ValueTy = T;
  using PointerTy = T*;

  PointerTy get() const & {
    // Check for null.
    if (Nullable && RelativeOffset == 0)
      return nullptr;
    
    // The value is addressed relative to `this`.
    auto base = reinterpret_cast<intptr_t>(this);
    intptr_t absolute = base + RelativeOffset;
    return reinterpret_cast<PointerTy>(absolute);
  }

};

/// A direct relative reference to an object.
template<typename T, bool Nullable = true>
class RelativeDirectPointer :
  private RelativeDirectPointerImpl<T, Nullable>
{
  using super = RelativeDirectPointerImpl<T, Nullable>;
public:
  using super::get;

  operator typename super::PointerTy() const & {
    return this->get();
  }

  const typename super::ValueTy &operator*() const & {
    return *this->get();
  }

  const typename super::ValueTy *operator->() const & {
    return this->get();
  }
};

/// A specialization of RelativeDirectPointer for function pointers,
/// allowing for calls.
template<typename RetTy, typename...ArgTy, bool Nullable>
class RelativeDirectPointer<RetTy (ArgTy...), Nullable> :
  private RelativeDirectPointerImpl<RetTy (ArgTy...), Nullable>
{
  using super = RelativeDirectPointerImpl<RetTy (ArgTy...), Nullable>;
public:
  using super::get;

  operator typename super::PointerTy() const & {
    return this->get();
  }

  RetTy operator()(ArgTy...arg) {
    return this->get()(std::forward<ArgTy>(arg)...);
  }
};

/// A direct relative reference to an aligned object, with an additional
/// tiny integer value crammed into its low bits.
template<typename PointeeTy, typename IntTy>
class RelativeDirectPointerIntPair {
  int32_t RelativeOffsetPlusInt;

  /// RelativePointers should appear in statically-generated metadata. They
  /// shouldn't be constructed or copied.
  RelativeDirectPointerIntPair() = delete;
  RelativeDirectPointerIntPair(RelativeDirectPointerIntPair &&) = delete;
  RelativeDirectPointerIntPair(const RelativeDirectPointerIntPair &) = delete;
  RelativeDirectPointerIntPair &operator=(RelativeDirectPointerIntPair &&)
    = delete;
  RelativeDirectPointerIntPair &operator=(const RelativeDirectPointerIntPair&)
    = delete;

  static int32_t getMask() {
    static_assert(alignof(PointeeTy) >= alignof(int32_t),
                  "pointee alignment must be at least 32 bit");

    return alignof(int32_t) - 1;
  }

public:
  using ValueTy = PointeeTy;
  using PointerTy = PointeeTy*;

  PointerTy getPointer() const & {
    // The value is addressed relative to `this`.
    auto base = reinterpret_cast<intptr_t>(this);
    intptr_t absolute = base + (RelativeOffsetPlusInt & ~getMask());
    return reinterpret_cast<PointerTy>(absolute);
  }

  IntTy getInt() const & {
    return IntTy(RelativeOffsetPlusInt & getMask());
  }
};

}

