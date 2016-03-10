// RUN: %target-parse-verify-swift

@noescape var fn : () -> Int = { 4 }  // expected-error {{@noescape may only be used on 'parameter' declarations}} {{1-11=}}

func doesEscape(fn : () -> Int) {}

func takesGenericClosure<T>(a : Int, @noescape _ fn : () -> T) {}


func takesNoEscapeClosure(@noescape fn : () -> Int) {
  takesNoEscapeClosure { 4 }  // ok

  fn()  // ok

  var x = fn  // expected-error {{@noescape parameter 'fn' may only be called}}

  // This is ok, because the closure itself is noescape.
  takesNoEscapeClosure { fn() }

  // This is not ok, because it escapes the 'fn' closure.
  doesEscape { fn() }   // expected-error {{closure use of @noescape parameter 'fn' may allow it to escape}}

  // This is not ok, because it escapes the 'fn' closure.
  func nested_function() {
    fn()   // expected-error {{declaration closing over @noescape parameter 'fn' may allow it to escape}}
  }

  takesNoEscapeClosure(fn)  // ok

  doesEscape(fn)                   // expected-error {{invalid conversion from non-escaping function of type '@noescape () -> Int' to potentially escaping function type '() -> Int'}}
  takesGenericClosure(4, fn)       // ok
  takesGenericClosure(4) { fn() }  // ok.
}

class SomeClass {
  final var x = 42

  func test() {
    // This should require "self."
    doesEscape { x }  // expected-error {{reference to property 'x' in closure requires explicit 'self.' to make capture semantics explicit}} {{18-18=self.}}

    // Since 'takesNoEscapeClosure' doesn't escape its closure, it doesn't
    // require "self." qualification of member references.
    takesNoEscapeClosure { x }
  }

  func foo() -> Int {
    foo()

    func plain() { foo() }
    let plain2 = { foo() } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}

    func multi() -> Int { foo(); return 0 }
    let mulit2: () -> Int = { foo(); return 0 } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{31-31=self.}}

    doesEscape { foo() } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{18-18=self.}}
    takesNoEscapeClosure { foo() } // okay

    doesEscape { foo(); return 0 } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{18-18=self.}}
    takesNoEscapeClosure { foo(); return 0 } // okay

    func outer() {
      func inner() { foo() }
      let inner2 = { foo() } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
      func multi() -> Int { foo(); return 0 }
      let _: () -> Int = { foo(); return 0 } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{28-28=self.}}
      doesEscape { foo() } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo() }
      doesEscape { foo(); return 0 } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo(); return 0 }
    }

    let outer2: () -> Void = {
      func inner() { foo() } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
      let inner2 = { foo() } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
      func multi() -> Int { foo(); return 0 } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{29-29=self.}}
      let mulit2: () -> Int = { foo(); return 0 } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{33-33=self.}}
      doesEscape { foo() }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo() }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{30-30=self.}}
      doesEscape { foo(); return 0 }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo(); return 0 }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{30-30=self.}}
    }

    doesEscape {
      func inner() { foo() }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
      let inner2 = { foo() }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
      func multi() -> Int { foo(); return 0 }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{29-29=self.}}
      let mulit2: () -> Int = { foo(); return 0 }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{33-33=self.}}
      doesEscape { foo() }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo() }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{30-30=self.}}
      doesEscape { foo(); return 0 }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo(); return 0 }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{30-30=self.}}
      return 0
    }
    takesNoEscapeClosure {
      func inner() { foo() }
      let inner2 = { foo() }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
      func multi() -> Int { foo(); return 0 }
      let mulit2: () -> Int = { foo(); return 0 }  // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{33-33=self.}}
      doesEscape { foo() } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo() } // okay
      doesEscape { foo(); return 0 } // expected-error {{call to method 'foo' in closure requires explicit 'self.' to make capture semantics explicit}} {{20-20=self.}}
      takesNoEscapeClosure { foo(); return 0 } // okay
      return 0
    }

    struct Outer {
      func bar() -> Int {
        bar()

        func plain() { bar() }
        let plain2 = { bar() } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{24-24=self.}}

        func multi() -> Int { bar(); return 0 }
        let _: () -> Int = { bar(); return 0 } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{30-30=self.}}

        doesEscape { bar() } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
        takesNoEscapeClosure { bar() } // okay

        doesEscape { bar(); return 0 } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{22-22=self.}}
        takesNoEscapeClosure { bar(); return 0 } // okay

        return 0
      }
    }

    func structOuter() {
      struct Inner {
        func bar() -> Int {
          bar() // no-warning

          func plain() { bar() }
          let plain2 = { bar() } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{26-26=self.}}

          func multi() -> Int { bar(); return 0 }
          let _: () -> Int = { bar(); return 0 } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{32-32=self.}}

          doesEscape { bar() } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{24-24=self.}}
          takesNoEscapeClosure { bar() } // okay

          doesEscape { bar(); return 0 } // expected-error {{call to method 'bar' in closure requires explicit 'self.' to make capture semantics explicit}} {{24-24=self.}}
          takesNoEscapeClosure { bar(); return 0 } // okay

          return 0
        }
      }
    }

    return 0
  }
}


// Implicit conversions (in this case to @convention(block)) are ok.
@_silgen_name("whatever")
func takeNoEscapeAsObjCBlock(@noescape _: @convention(block) () -> Void)
func takeNoEscapeTest2(@noescape fn : () -> ()) {
  takeNoEscapeAsObjCBlock(fn)
}

// Autoclosure implies noescape, but produce nice diagnostics so people know
// why noescape problems happen.
func testAutoclosure(@autoclosure a : () -> Int) { // expected-note{{parameter 'a' is implicitly @noescape because it was declared @autoclosure}}
  doesEscape { a() }  // expected-error {{closure use of @noescape parameter 'a' may allow it to escape}}
}


// <rdar://problem/19470858> QoI: @autoclosure implies @noescape, so you shouldn't be allowed to specify both
func redundant(@noescape  // expected-error {{@noescape is implied by @autoclosure and should not be redundantly specified}} {{16-25=}}
               @autoclosure fn : () -> Int) {
}


protocol P1 {
  associatedtype Element
}
protocol P2 : P1 {
  associatedtype Element
}

func overloadedEach<O: P1, T>(source: O, _ transform: O.Element -> (), _: T) {}

func overloadedEach<P: P2, T>(source: P, _ transform: P.Element -> (), _: T) {}

struct S : P2 {
  typealias Element = Int
  func each(@noescape transform: Int -> ()) {
    overloadedEach(self,  // expected-error {{cannot invoke 'overloadedEach' with an argument list of type '(S, @noescape Int -> (), Int)'}}
                   transform, 1)
    // expected-note @-2 {{overloads for 'overloadedEach' exist with these partially matching parameter lists: (O, O.Element -> (), T), (P, P.Element -> (), T)}}
  }
}



// rdar://19763676 - False positive in @noescape analysis triggered by parameter label
func r19763676Callee(@noescape f: (param: Int) -> Int) {}

func r19763676Caller(@noescape g: (Int) -> Int) {
  r19763676Callee({ _ in g(1) })
}


// <rdar://problem/19763732> False positive in @noescape analysis triggered by default arguments
func calleeWithDefaultParameters(@noescape f: () -> (), x : Int = 1) {}  // expected-warning {{closure parameter prior to parameters with default arguments will not be treated as a trailing closure}}

func callerOfDefaultParams(@noescape g: () -> ()) {
  calleeWithDefaultParameters(g)
}



// <rdar://problem/19773562> Closures executed immediately { like this }() are not automatically @noescape
class NoEscapeImmediatelyApplied {
  func f() {
    // Shouldn't require "self.", the closure is obviously @noescape.
    _ = { return ivar }()
  }
  
  final var ivar  = 42
}



// Reduced example from XCTest overlay, involves a TupleShuffleExpr
public func XCTAssertTrue(@autoclosure expression: () -> Boolean, _ message: String = "", file: StaticString = #file, line: UInt = #line) -> Void {
}
public func XCTAssert( @autoclosure expression: () -> Boolean, _ message: String = "", file: StaticString = #file, line: UInt = #line)  -> Void {
  XCTAssertTrue(expression, message, file: file, line: line);
}



/// SR-770 - Currying and `noescape`/`rethrows` don't work together anymore
func curriedFlatMap<A, B>(x: [A]) -> (@noescape (A) -> [B]) -> [B] {
  return { f in
    x.flatMap(f)
  }
}

func curriedFlatMap2<A, B>(x: [A]) -> (@noescape (A) -> [B]) -> [B] {
  return { (f : @noescape (A) -> [B]) in
    x.flatMap(f)
  }
}

func bad(a : (Int)-> Int) -> Int { return 42 }
func escapeNoEscapeResult(x: [Int]) -> (@noescape (Int) -> Int) -> Int {
  return { f in
    bad(f)  // expected-error {{invalid conversion from non-escaping function of type '@noescape (Int) -> Int' to potentially escaping function type '(Int) -> Int'}}
  }
}


// SR-824 - @noescape for Type Aliased Closures
//
typealias CompletionHandlerNE = @noescape (success: Bool) -> ()
typealias CompletionHandler = (success: Bool) -> ()
var escape : CompletionHandlerNE
func doThing1(@noescape completion: CompletionHandler) {
  // expected-error @+2 {{@noescape value 'escape' may only be called}}
  // expected-error @+1 {{@noescape parameter 'completion' may only be called}}
  escape = completion
}
func doThing2(completion: CompletionHandlerNE) {
  // expected-error @+2 {{@noescape value 'escape' may only be called}}
  // expected-error @+1 {{@noescape parameter 'completion' may only be called}}
  escape = completion
}

// <rdar://problem/19997680> @noescape doesn't work on parameters of function type
func apply<T, U>(@noescape f: T -> U, @noescape g: (@noescape T -> U) -> U) -> U {
  return g(f)
}

// <rdar://problem/19997577> @noescape cannot be applied to locals, leading to duplication of code
enum r19997577Type {
  case Unit
  case Function(() -> r19997577Type, () -> r19997577Type)
  case Sum(() -> r19997577Type, () -> r19997577Type)

  func reduce<Result>(initial: Result, @noescape _ combine: (Result, r19997577Type) -> Result) -> Result {
    let binary: @noescape (r19997577Type, r19997577Type) -> Result = { combine(combine(combine(initial, self), $0), $1) }
    switch self {
    case Unit:
      return combine(initial, self)
    case let Function(t1, t2):
      return binary(t1(), t2())
    case let Sum(t1, t2):
      return binary(t1(), t2())
    }
  }
}


