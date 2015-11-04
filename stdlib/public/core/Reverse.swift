//===--- Reverse.swift - Lazy sequence reversal ---------------*- swift -*-===//
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

public protocol ReverseIndexType : BidirectionalIndex {
  typealias Base : BidirectionalIndex
  
  /// A type that can represent the number of steps between pairs of
  /// `ReverseIndex` values where one value is reachable from the other.
  typealias Distance: _SignedIntegerType = Base.Distance

  /// The successor position in the underlying (un-reversed)
  /// collection.
  ///
  /// If `self` is `advance(c.reverse.startIndex, n)`, then:
  /// - `self.base` is `advance(c.endIndex, -n)`.
  /// - if `n` != `c.count`, then `c.reverse[self]` is 
  ///   equivalent to `[self.base.predecessor()]`.
  var base: Base { get }

  init(_ base: Base)
}

extension BidirectionalIndex where Self : ReverseIndexType {
  /// Returns the next consecutive value after `self`.
  ///
  /// - Requires: The next value is representable.
  public func successor() -> Self {
    return Self(base.predecessor())
  }

  /// Returns the previous consecutive value before `self`.
  ///
  /// - Requires: The previous value is representable.
  public func predecessor() -> Self {
    return Self(base.successor())
  }
}

/// A wrapper for a `BidirectionalIndex` that reverses its
/// direction of traversal.
public struct ReverseIndex<Base: BidirectionalIndex>
: BidirectionalIndex, ReverseIndexType {
  public typealias Distance = Base.Distance
  
  public init(_ base: Base) { self.base = base }
  
  /// The successor position in the underlying (un-reversed)
  /// collection.
  ///
  /// If `self` is `advance(c.reverse.startIndex, n)`, then:
  /// - `self.base` is `advance(c.endIndex, -n)`.
  /// - if `n` != `c.count`, then `c.reverse[self]` is 
  ///   equivalent to `[self.base.predecessor()]`.
  public let base: Base
}

@warn_unused_result
public func == <Base> (
  lhs: ReverseIndex<Base>, rhs: ReverseIndex<Base>
) -> Bool {
  return lhs.base == rhs.base
}

/// A wrapper for a `RandomAccessIndex` that reverses its
/// direction of traversal.
public struct ReverseRandomAccessIndex<Base: RandomAccessIndex>
  : RandomAccessIndex, ReverseIndexType {

  public typealias Distance = Base.Distance
  
  public init(_ base: Base) { self.base = base }
  
  /// The successor position in the underlying (un-reversed)
  /// collection.
  ///
  /// If `self` is `advance(c.reverse.startIndex, n)`, then:
  /// - `self.base` is `advance(c.endIndex, -n)`.
  /// - if `n` != `c.count`, then `c.reverse[self]` is 
  ///   equivalent to `[self.base.predecessor()]`.
  public let base: Base

  public func distanceTo(other: ReverseRandomAccessIndex) -> Distance {
    return other.base.distanceTo(base)
  }

  public func advancedBy(n: Distance) -> ReverseRandomAccessIndex {
    return ReverseRandomAccessIndex(base.advancedBy(-n))
  }
}

public protocol _ReverseCollection : Collection {
  typealias Index : ReverseIndexType
  typealias Base : Collection
  var _base: Base {get}
}

extension Collection
  where Self : _ReverseCollection, Self.Base.Index : RandomAccessIndex {
  public var startIndex : ReverseRandomAccessIndex<Self.Base.Index> {
    return ReverseRandomAccessIndex(_base.endIndex)
  }
}

extension _ReverseCollection
  where Self : Collection, Self.Index.Base == Self.Base.Index
{
  public var startIndex : Index { return Self.Index(_base.endIndex) }
  public var endIndex : Index { return Self.Index(_base.startIndex) }
  public subscript(position: Index) -> Self.Base.Iterator.Element {
    return _base[position.base.predecessor()]
  }
}

/// A Collection that presents the elements of its `Base` collection
/// in reverse order.
///
/// - Note: This type is the result of `x.reverse()` where `x` is a
///   collection having bidirectional indices.
///
/// The `reverse()` method is always lazy when applied to a collection
/// with bidirectional indices, but does not implicitly confer
/// laziness on algorithms applied to its result.  In other words, for
/// ordinary collections `c` having bidirectional indices:
///
/// * `c.reverse()` does not create new storage
/// * `c.reverse().map(f)` maps eagerly and returns a new array
/// * `c.lazy.reverse().map(f)` maps lazily and returns a `LazyMapCollection`
///
/// - See also: `ReverseRandomAccessCollection`
public struct ReverseCollection<
  Base : Collection where Base.Index : BidirectionalIndex
> : Collection, _ReverseCollection {
  /// Creates an instance that presents the elements of `base` in
  /// reverse order.
  ///
  /// - Complexity: O(1)
  public init(_ base: Base) {
    self._base = base
  }

  /// A type that represents a valid position in the collection.
  ///
  /// Valid indices consist of the position of every element and a
  /// "past the end" position that's not valid for use as a subscript.
  public typealias Index = ReverseIndex<Base.Index>

  /// A type that provides the *sequence*'s iteration interface and
  /// encapsulates its iteration state.
  public typealias Iterator = CollectionDefaultIterator<ReverseCollection>
  
  public let _base: Base
}

/// A Collection that presents the elements of its `Base` collection
/// in reverse order.
///
/// - Note: This type is the result of `x.reverse()` where `x` is a
///   collection having random access indices.
/// - See also: `ReverseCollection`
public struct ReverseRandomAccessCollection<
  Base : Collection where Base.Index : RandomAccessIndex
> : _ReverseCollection {
  /// Creates an instance that presents the elements of `base` in
  /// reverse order.
  ///
  /// - Complexity: O(1)
  public init(_ base: Base) {
    self._base = base
  }

  /// A type that represents a valid position in the collection.
  ///
  /// Valid indices consist of the position of every element and a
  /// "past the end" position that's not valid for use as a subscript.
  public typealias Index = ReverseRandomAccessIndex<Base.Index>
  
  /// A type that provides the *sequence*'s iteration interface and
  /// encapsulates its iteration state.
  public typealias Iterator = CollectionDefaultIterator<
    ReverseRandomAccessCollection
  >

  public let _base: Base
}

extension Collection where Index : BidirectionalIndex {
  /// Return the elements of `self` in reverse order.
  ///
  /// - Complexity: O(1)
  @warn_unused_result
  public func reverse() -> ReverseCollection<Self> {
    return ReverseCollection(self)
  }
}

extension Collection where Index : RandomAccessIndex {
  /// Return the elements of `self` in reverse order.
  ///
  /// - Complexity: O(1)
  @warn_unused_result
  public func reverse() -> ReverseRandomAccessCollection<Self> {
    return ReverseRandomAccessCollection(self)
  }
}

extension LazyCollectionProtocol
where Index : BidirectionalIndex, Elements.Index : BidirectionalIndex {
  /// Return the elements of `self` in reverse order.
  ///
  /// - Complexity: O(1)
  @warn_unused_result
  public func reverse() -> LazyCollection<
    ReverseCollection<Elements>
  > {
    return ReverseCollection(elements).lazy
  }
}

extension LazyCollectionProtocol
where Index : RandomAccessIndex, Elements.Index : RandomAccessIndex {
  /// Return the elements of `self` in reverse order.
  ///
  /// - Complexity: O(1)
  @warn_unused_result
  public func reverse() -> LazyCollection<
    ReverseRandomAccessCollection<Elements>
  > {
    return ReverseRandomAccessCollection(elements).lazy
  }
}

// ${'Local Variables'}:
// eval: (read-only-mode 1)
// End:
