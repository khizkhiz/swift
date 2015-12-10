// RUN: not %target-swift-frontend %s -parse

public protocol Q_SequenceDefaultsType {
  typealias Iterator : IteratorProtocol
  func iterator() -> Iterator
}

extension Q_SequenceDefaultsType {
  typealias Element = Iterator.Element
  
  public final func underestimateCount() -> Int { return 0 }
  public final func preprocessingPass<R>(body: (Self)->R) -> R? {
    return nil
  }

  /// Create a ContiguousArray containing the elements of `self`,
  /// in the same order.
  public final func copyToContiguousArray() -> ContiguousArray<Iterator.Element> {
    let initialCapacity = underestimateCount()

    var result = _ContiguousArrayBuffer<Iterator.Element>(
      count: initialCapacity, minimumCapacity: 0)

    var iter = self.iterator()
    while let x? = iter.next() {
      result += CollectionOfOne(x)
    }
    return ContiguousArray(result)
  }

  /// Initialize the storage at baseAddress with the contents of this
  /// sequence.
  public final func initializeRawMemory(
    baseAddress: UnsafeMutablePointer<Iterator.Element>
  ) {
    var p = baseAddress
    var iter = self.iterator()
    while let element? = iter.next() {
      p.initialize(element)
      ++p
    }
  }

//  public final static func _constrainElement(Iterator.Element) {}
}

/// A type that can be iterated with a `for`\ ...\ `in` loop.
///
/// `SequenceType` makes no requirement on conforming types regarding
/// whether they will be destructively "consumed" by iteration.  To
/// ensure non-destructive iteration, constrain your *sequence* to
/// `Collection`.
public protocol Q_SequenceType : Q_SequenceDefaultsType {
  /// A type that provides the *sequence*\ 's iteration interface and
  /// encapsulates its iteration state.
  typealias Iterator : IteratorProtocol

  func iterator() -> Iterator

  /// Return a value less than or equal to the number of elements in
  /// self, **nondestructively**.
  ///
  /// Complexity: O(N)
  func underestimateCount() -> Int

  /// If `self` is multi-pass (i.e., a `Collection`), invoke the function
  /// on `self` and return its result.  Otherwise, return `nil`.
  func preprocessingPass<R>(body: (Self)->R) -> R?

  /// Create a ContiguousArray containing the elements of `self`,
  /// in the same order.
  func copyToContiguousArray() -> ContiguousArray<Iterator.Element>

  /// Initialize the storage at baseAddress with the contents of this
  /// sequence.
  func initializeRawMemory(
    baseAddress: UnsafeMutablePointer<Iterator.Element>
  )
  
//  static func _constrainElement(Element)
}

public extension IteratorProtocol {
  public final func iterator() -> Self {
    return self
  }
}

public typealias Q_ConcreteIteratorProtocol = protocol<IteratorProtocol, Q_SequenceType>

public protocol Q_IndexableType {
  typealias Index : ForwardIndex
  typealias Element
  subscript(position: Index) -> Element {get}
  var startIndex: Index {get}
  var endIndex: Index {get}
}

extension Q_IndexableType {
  public final func iterator() -> Q_IndexingIterator<Self> {
    return Q_IndexingIterator(pos: self.startIndex, elements: self)
  }
}

public protocol Q_CollectionDefaultsType : Q_IndexableType, Q_SequenceType {
  typealias Element = Iterator.Element
}

extension Q_CollectionDefaultsType {
  public final func count() -> Index.Distance {
    return distance(startIndex, endIndex)
  }
  
  public final func underestimateCount() -> Int {
    let n = count().toIntMax()
    return n > IntMax(Int.max) ? Int.max : Int(n)
  }
  
  public final func preprocessingPass<R>(body: (Self)->R) -> R? {
    return body(self)
  }
}

public struct Q_IndexingIterator<C: Q_IndexableType> : Q_ConcreteIteratorProtocol {
  public typealias Element = C.Element
  var pos: C.Index
  let elements: C
  
  public mutating func next() -> C.Element? {
    if pos == elements.endIndex {
      return nil
    }
    let ret = elements[pos]
    ++pos
    return ret
  }
}

public protocol Q_CollectionType : Q_CollectionDefaultsType {
  func count() -> Index.Distance
  subscript(position: Index) -> Element {get}
}

extension Array : Q_CollectionType {
  public func copyToContiguousArray() -> ContiguousArray<Element> {
    return ContiguousArray(self~>_copyToNativeArrayBuffer())
  }
}

struct Boo : Q_CollectionType {
  let startIndex: Int = 0
  let endIndex: Int = 10
  
  subscript(i: Int) -> String {
    return "Boo"
  }
}
