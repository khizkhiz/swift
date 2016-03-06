//===--- RangeReplaceableCollection.swift ---------------------*- swift -*-===//
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
// A Collection protocol with replaceSubrange.
//
//===----------------------------------------------------------------------===//

/// A collection that supports replacement of an arbitrary subrange
/// of elements with the elements of another collection.
public protocol RangeReplaceableCollection : Collection {
  //===--- Fundamental Requirements ---------------------------------------===//

  /// Create an empty instance.
  init()

  /// Construct a Collection of `count` elements, each initialized to
  /// `repeatedValue`.
  init(repeating repeatedValue: Iterator.Element, count: Int)


  /// Replace the given `subRange` of elements with `newElements`.
  ///
  /// Invalidates all indices with respect to `self`.
  ///
  /// - Complexity: O(`subRange.count`) if
  ///   `subRange.endIndex == self.endIndex` and `newElements.isEmpty`,
  ///   O(`self.count` + `newElements.count`) otherwise.
  mutating func replaceSubrange<
    C : Collection where C.Iterator.Element == Iterator.Element
  >(
    subRange: Range<Index>, with newElements: C
  )

  /*
  We could have these operators with default implementations, but the compiler
  crashes:

  <rdar://problem/16566712> Dependent type should have been substituted by Sema
  or SILGen

  func +<
    S : Sequence
    where S.Iterator.Element == Iterator.Element
  >(_: Self, _: S) -> Self

  func +<
    S : Sequence
    where S.Iterator.Element == Iterator.Element
  >(_: S, _: Self) -> Self

  func +<
    S : Collection
    where S.Iterator.Element == Iterator.Element
  >(_: Self, _: S) -> Self

  func +<
    RC : RangeReplaceableCollection
    where RC.Iterator.Element == Iterator.Element
  >(_: Self, _: S) -> Self
*/

  /// A non-binding request to ensure `n` elements of available storage.
  ///
  /// This works as an optimization to avoid multiple reallocations of
  /// linear data structures like `Array`.  Conforming types may
  /// reserve more than `n`, exactly `n`, less than `n` elements of
  /// storage, or even ignore the request completely.
  mutating func reserveCapacity(n: IndexDistance)

  //===--- Derivable Requirements -----------------------------------------===//

  /// Creates a collection instance that contains `elements`.
  init<
    S : Sequence where S.Iterator.Element == Iterator.Element
  >(_ elements: S)

  /// Append `x` to `self`.
  ///
  /// Applying `successor()` to the index of the new element yields
  /// `self.endIndex`.
  ///
  /// - Complexity: Amortized O(1).
  mutating func append(x: Iterator.Element)

  /*
  The 'appendContentsOf' requirement should be an operator, but the compiler crashes:

  <rdar://problem/16566712> Dependent type should have been substituted by Sema
  or SILGen

  func +=<
    S : Sequence
    where S.Iterator.Element == Iterator.Element
  >(inout _: Self, _: S)
  */

  /// Append the elements of `newElements` to `self`.
  ///
  /// - Complexity: O(*length of result*).
  mutating func append<
    S : Sequence
    where
    S.Iterator.Element == Iterator.Element
  >(contentsOf newElements: S)

  /// Insert `newElement` at index `i`.
  ///
  /// Invalidates all indices with respect to `self`.
  ///
  /// - Complexity: O(`self.count`).
  mutating func insert(newElement: Iterator.Element, at i: Index)

  /// Insert `newElements` at index `i`.
  ///
  /// Invalidates all indices with respect to `self`.
  ///
  /// - Complexity: O(`self.count + newElements.count`).
  mutating func insert<
    S : Collection where S.Iterator.Element == Iterator.Element
  >(contentsOf newElements: S, at i: Index)

  /// Remove the element at index `i`.
  ///
  /// Invalidates all indices with respect to `self`.
  ///
  /// - Complexity: O(`self.count`).
  mutating func remove(at i: Index) -> Iterator.Element

  /// Customization point for `removeLast()`.  Implement this function if you
  /// want to replace the default implementation.
  ///
  /// - Returns: A non-nil value if the operation was performed.
  @warn_unused_result
  mutating func _customRemoveLast() -> Iterator.Element?

  /// Customization point for `removeLast(_:)`.  Implement this function if you
  /// want to replace the default implementation.
  ///
  /// - Returns: True if the operation was performed.
  @warn_unused_result
  mutating func _customRemoveLast(n: Int) -> Bool

  /// Remove the element at `startIndex` and return it.
  ///
  /// - Complexity: O(`self.count`)
  /// - Precondition: `!self.isEmpty`.
  mutating func removeFirst() -> Iterator.Element

  /// Remove the first `n` elements.
  ///
  /// - Complexity: O(`self.count`)
  /// - Precondition: `n >= 0 && self.count >= n`.
  mutating func removeFirst(n: Int)

  /// Remove all elements within `bounds`.
  ///
  /// Invalidates all indices with respect to `self`.
  ///
  /// - Complexity: O(`self.count`).
  mutating func removeSubrange(bounds: Range<Index>)

  /// Remove all elements.
  ///
  /// Invalidates all indices with respect to `self`.
  ///
  /// - parameter keepCapacity: If `true`, is a non-binding request to
  ///    avoid releasing storage, which can be a useful optimization
  ///    when `self` is going to be grown again.
  ///
  /// - Complexity: O(`self.count`).
  mutating func removeAll(keepingCapacity keepCapacity: Bool /*= false*/)

}

//===----------------------------------------------------------------------===//
// Default implementations for RangeReplaceableCollection
//===----------------------------------------------------------------------===//

extension RangeReplaceableCollection {

  public init(repeating repeatedValue: Iterator.Element, count: Int) {
    self.init()
    if count != 0 {
      let elements = Repeated(_repeating: repeatedValue, count: count)
      append(contentsOf: elements)
    }
  }

  public init<
    S : Sequence where S.Iterator.Element == Iterator.Element
  >(_ elements: S) {
    self.init()
    append(contentsOf: elements)
  }

  public mutating func append(newElement: Iterator.Element) {
    insert(newElement, at: endIndex)
  }

  public mutating func append<
    S : Sequence where S.Iterator.Element == Iterator.Element
  >(contentsOf newElements: S) {
    let approximateCapacity = self.count +
      numericCast(newElements.underestimatedCount)
    self.reserveCapacity(approximateCapacity)
    for element in newElements {
      append(element)
    }
  }

  public mutating func insert(
    newElement: Iterator.Element, at i: Index
  ) {
    replaceSubrange(i..<i, with: CollectionOfOne(newElement))
  }

  public mutating func insert<
    C : Collection where C.Iterator.Element == Iterator.Element
  >(contentsOf newElements: C, at i: Index) {
    replaceSubrange(i..<i, with: newElements)
  }

  public mutating func remove(at index: Index) -> Iterator.Element {
    _precondition(!isEmpty, "can't remove from an empty collection")
    let result: Iterator.Element = self[index]
    replaceSubrange(index...index, with: EmptyCollection())
    return result
  }

  public mutating func removeSubrange(bounds: Range<Index>) {
    replaceSubrange(bounds, with: EmptyCollection())
  }

  public mutating func removeFirst(n: Int) {
    if n == 0 { return }
    _precondition(n >= 0, "number of elements to remove should be non-negative")
    _precondition(count >= numericCast(n),
      "can't remove more items from a collection than it has")
    let end = advance(startIndex, by: numericCast(n))
    removeSubrange(startIndex..<end)
  }

  public mutating func removeFirst() -> Iterator.Element {
    _precondition(!isEmpty,
      "can't remove first element from an empty collection")
    let firstElement = first!
    removeFirst(1)
    return firstElement
  }

  public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
    if !keepCapacity {
      self = Self()
    }
    else {
      replaceSubrange(indices, with: EmptyCollection())
    }
  }

  public mutating func reserveCapacity(n: IndexDistance) {}
}

extension RangeReplaceableCollection where SubSequence == Self {
  /// Remove the element at `startIndex` and return it.
  ///
  /// - Complexity: O(1)
  /// - Precondition: `!self.isEmpty`.
  public mutating func removeFirst() -> Iterator.Element {
    _precondition(!isEmpty, "can't remove items from an empty collection")
    let element = first!
    self = self[startIndex.successor()..<endIndex]
    return element
  }

  /// Remove the first `n` elements.
  ///
  /// - Complexity: O(1)
  /// - Precondition: `self.count >= n`.
  public mutating func removeFirst(n: Int) {
    if n == 0 { return }
    _precondition(n >= 0, "number of elements to remove should be non-negative")
    _precondition(count >= numericCast(n),
      "can't remove more items from a collection than it contains")
    self = self[advance(startIndex, by: numericCast(n))..<endIndex]
  }
}

extension RangeReplaceableCollection {
  @warn_unused_result
  public mutating func _customRemoveLast() -> Iterator.Element? {
    return nil
  }

  @warn_unused_result
  public mutating func _customRemoveLast(n: Int) -> Bool {
    return false
  }
}

extension RangeReplaceableCollection
  where
  Self : BidirectionalCollection,
  SubSequence == Self {

  @warn_unused_result
  public mutating func _customRemoveLast() -> Iterator.Element? {
    let element = last!
    self = self[startIndex..<previous(endIndex)]
    return element
  }

  @warn_unused_result
  public mutating func _customRemoveLast(n: Int) -> Bool {
    self = self[startIndex..<advance(endIndex, by: numericCast(-n))]
    return true
  }
}

extension RangeReplaceableCollection where Self : BidirectionalCollection {
  /// Remove an element from the end.
  ///
  /// - Complexity: O(1)
  /// - Precondition: `!self.isEmpty`
  public mutating func removeLast() -> Iterator.Element {
    _precondition(!isEmpty, "can't remove last element from an empty collection")
    if let result = _customRemoveLast() {
      return result
    }
    return remove(at: previous(endIndex))
  }

  /// Remove the last `n` elements.
  ///
  /// - Complexity: O(`self.count`)
  /// - Precondition: `n >= 0 && self.count >= n`.
  public mutating func removeLast(n: Int) {
    if n == 0 { return }
    _precondition(n >= 0, "number of elements to remove should be non-negative")
    _precondition(count >= numericCast(n),
      "can't remove more items from a collection than it contains")
    if _customRemoveLast(n) {
      return
    }
    let end = endIndex
    removeSubrange(advance(end, by: numericCast(-n))..<end)
  }
}

@warn_unused_result
public func +<
    C : RangeReplaceableCollection,
    S : Sequence
    where S.Iterator.Element == C.Iterator.Element
>(lhs: C, rhs: S) -> C {
  var lhs = lhs
  // FIXME: what if lhs is a reference type?  This will mutate it.
  lhs.reserveCapacity(lhs.count + numericCast(rhs.underestimatedCount))
  lhs.append(contentsOf: rhs)
  return lhs
}

@warn_unused_result
public func +<
  C : RangeReplaceableCollection,
  S : Sequence
  where S.Iterator.Element == C.Iterator.Element
>(lhs: S, rhs: C) -> C {
  var result = C()
  result.reserveCapacity(rhs.count + numericCast(lhs.underestimatedCount))
  result.append(contentsOf: lhs)
  result.append(contentsOf: rhs)
  return result
}

@warn_unused_result
public func +<
  RRC1 : RangeReplaceableCollection,
  RRC2 : RangeReplaceableCollection
  where RRC1.Iterator.Element == RRC2.Iterator.Element
>(lhs: RRC1, rhs: RRC2) -> RRC1 {
  var lhs = lhs
  // FIXME: what if lhs is a reference type?  This will mutate it.
  lhs.reserveCapacity(lhs.count + numericCast(rhs.count))
  lhs.append(contentsOf: rhs)
  return lhs
}

@available(*, unavailable, renamed="RangeReplaceableCollection")
public typealias RangeReplaceableCollectionType = RangeReplaceableCollection

extension RangeReplaceableCollection {
  @available(*, unavailable, renamed="replaceSubrange")
  public mutating func replaceRange<
    C : Collection where C.Iterator.Element == Iterator.Element
  >(
    subRange: Range<Index>, with newElements: C
  ) {
    fatalError("unavailable function can't be called")
  }

  @available(*, unavailable, renamed="removeAt")
  public mutating func removeAtIndex(i: Index) -> Iterator.Element {
    fatalError("unavailable function can't be called")
  }

  @available(*, unavailable, renamed="removeSubrange")
  public mutating func removeRange(subRange: Range<Index>) {
  }

  @available(*, unavailable, renamed="append(contentsOf:)")
  public mutating func appendContentsOf<
    S : Sequence
    where
    S.Iterator.Element == Iterator.Element
  >(newElements: S) {
    fatalError("unavailable function can't be called")
  }

  @available(*, unavailable, renamed="insert(contentsOf:at:)")
  public mutating func insertContentsOf<
    C : Collection where C.Iterator.Element == Iterator.Element
  >(newElements: C, at i: Index) {
    fatalError("unavailable function can't be called")
  }
}

