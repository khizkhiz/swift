// RUN: %target-parse-verify-swift

struct X {
  typealias MyInt = Int
  func getInt() -> MyInt { return 7 }
}

extension X {
  typealias MyReal = Double
  func getFloat() -> MyReal { return 3.14 }
}

protocol MyIteratorProtocol {}
protocol MySequence {
  typealias Iterator : MyIteratorProtocol
  func iterator() -> Iterator
}

struct IteratorWrapper<I : MyIteratorProtocol> {
  var index: Int
  var elements: I
}

struct SequenceWrapper<T : MySequence> {
  var input : T

  typealias Iterator = IteratorWrapper<T.Iterator>
  func iterator() -> Iterator {
    return Iterator(index: 0, elements: input.iterator())
  }
}
