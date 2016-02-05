//===----------------------------------------------------------------------===//
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

// The compiler has special knowledge of Optional<Wrapped>, including the fact
// that it is an enum with cases named 'None' and 'Some'.
public enum Optional<Wrapped> : NilLiteralConvertible {
  case None
  case Some(Wrapped)

  /// Construct a non-`nil` instance that stores `some`.
  @_transparent
  public init(_ some: Wrapped) { self = .Some(some) }

  /// If `self == nil`, returns `nil`.  Otherwise, returns `f(self!)`.
  @warn_unused_result
  public func map<U>(@noescape f: (Wrapped) throws -> U) rethrows -> U? {
    switch self {
    case .Some(let y):
      return .Some(try f(y))
    case .None:
      return .None
    }
  }

  /// Returns `nil` if `self` is `nil`, `f(self!)` otherwise.
  @warn_unused_result
  public func flatMap<U>(@noescape f: (Wrapped) throws -> U?) rethrows -> U? {
    switch self {
    case .Some(let y):
      return try f(y)
    case .None:
      return .None
    }
  }

  /// Create an instance initialized with `nil`.
  @_transparent
  public init(nilLiteral: ()) {
    self = .None
  }

  /// - Returns: `nonEmpty!`.
  ///
  /// - Requires: `nonEmpty != nil`.  In particular, in -O builds, no test
  ///   is performed to ensure that `nonEmpty` actually is non-nil.
  ///
  /// - Warning: Trades safety for performance.  Use `unsafelyUnwrapped`
  ///   only when `nonEmpty!` has proven to be a performance problem and
  ///   you are confident that, always, `nonEmpty != nil`.  It is better
  ///   than an `unsafeBitCast` because it's more restrictive, and
  ///   because checking is still performed in debug builds.
  public var unsafelyUnwrapped: Wrapped {
    @inline(__always)
    get {
      if let x = self {
        return x
      }
      _stdlibAssertionFailure("unsafelyUnwrapped of nil optional")
    }
  }

  /// - Returns: `unsafelyUnwrapped`.
  ///
  /// This version is for internal stdlib use; it avoids any checking
  /// overhead for users, even in Debug builds.
  public // SPI(SwiftExperimental)
  var _unsafelyUnwrapped: Wrapped {
    @inline(__always)
    get {
      if let x = self {
        return x
      }
      _sanityCheckFailure("_unsafelyUnwrapped of nil optional")
    }
  }

}

extension Optional : CustomDebugStringConvertible {
  /// A textual representation of `self`, suitable for debugging.
  public var debugDescription: String {
    switch self {
    case .Some(let value):
      var result = "Optional("
      debugPrint(value, terminator: "", toStream: &result)
      result += ")"
      return result
    case .None:
      return "nil"
    }
  }
}

// Intrinsics for use by language features.
@_transparent
public // COMPILER_INTRINSIC
func _doesOptionalHaveValueAsBool<Wrapped>(v: Wrapped?) -> Bool {
  return v != nil
}

@_transparent
public // COMPILER_INTRINSIC
func _diagnoseUnexpectedNilOptional() {
  _requirementFailure(
                "unexpectedly found nil while unwrapping an Optional value")
}

@_transparent
public // COMPILER_INTRINSIC
func _getOptionalValue<Wrapped>(v: Wrapped?) -> Wrapped {
  switch v {
  case let x?:
    return x
  case .None:
    _requirementFailure(
      "unexpectedly found nil while unwrapping an Optional value")
  }
}

@_transparent
public // COMPILER_INTRINSIC
func _injectValueIntoOptional<Wrapped>(v: Wrapped) -> Wrapped? {
  return .Some(v)
}

@_transparent
public // COMPILER_INTRINSIC
func _injectNothingIntoOptional<Wrapped>() -> Wrapped? {
  return .None
}

// Comparisons
@warn_unused_result
public func == <T: Equatable> (lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l == r
  case (nil, nil):
    return true
  default:
    return false
  }
}

@warn_unused_result
public func != <T : Equatable> (lhs: T?, rhs: T?) -> Bool {
  return !(lhs == rhs)
}

// Enable pattern matching against the nil literal, even if the element type
// isn't equatable.
public struct _OptionalNilComparisonType : NilLiteralConvertible {
  /// Create an instance initialized with `nil`.
  @_transparent
  public init(nilLiteral: ()) {
  }
}
@_transparent
@warn_unused_result
public func ~= <T>(lhs: _OptionalNilComparisonType, rhs: T?) -> Bool {
  switch rhs {
  case .Some(_):
    return false
  case .None:
    return true
  }
}

// Enable equality comparisons against the nil literal, even if the
// element type isn't equatable
@warn_unused_result
public func == <T>(lhs: T?, rhs: _OptionalNilComparisonType) -> Bool {
  switch lhs {
  case .Some(_):
    return false
  case .None:
    return true
  }
}

@warn_unused_result
public func != <T>(lhs: T?, rhs: _OptionalNilComparisonType) -> Bool {
  switch lhs {
  case .Some(_):
    return true
  case .None:
    return false
  }
}

@warn_unused_result
public func == <T>(lhs: _OptionalNilComparisonType, rhs: T?) -> Bool {
  switch rhs {
  case .Some(_):
    return false
  case .None:
    return true
  }
}

@warn_unused_result
public func != <T>(lhs: _OptionalNilComparisonType, rhs: T?) -> Bool {
  switch rhs {
  case .Some(_):
    return true
  case .None:
    return false
  }
}

@warn_unused_result
public func < <T : Comparable> (lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

@warn_unused_result
public func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

@warn_unused_result
public func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}

@warn_unused_result
public func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}

@_transparent
@warn_unused_result
public func ?? <T> (optional: T?, @autoclosure defaultValue: () throws -> T)
    rethrows -> T {
  switch optional {
  case .Some(let value):
    return value
  case .None:
    return try defaultValue()
  }
}

@_transparent
@warn_unused_result
public func ?? <T> (optional: T?, @autoclosure defaultValue: () throws -> T?)
    rethrows -> T? {
  switch optional {
  case .Some(let value):
    return value
  case .None:
    return try defaultValue()
  }
}
