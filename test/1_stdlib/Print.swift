// RUN: mkdir -p %t
// RUN: %target-build-swift %s -parse-stdlib -Xfrontend -disable-access-control -o %t/a.out -Xlinker -dead_strip
// RUN: %target-run %t/a.out env | FileCheck %s
// RUN: %target-run %t/a.out ru_RU.UTF-8 | FileCheck %s
// REQUIRES: executable_test

// XFAIL: linux

import Swift
import Darwin

// Interpret the command line arguments.
let arg = Process.arguments[1]

if arg == "env" {
  setlocale(LC_ALL, "")
} else {
  setlocale(LC_ALL, arg)
}

import StdlibUnittest
let PrintTests = TestSuite("Print")

PrintTests.test("stdlib types have description") {
  func hasDescription(any: Any) {
    expectTrue(any is CustomStringConvertible)
  }

  hasDescription(Int(42))
  hasDescription(UInt(42))

  hasDescription(Int8(-42))
  hasDescription(Int16(-42))
  hasDescription(Int32(-42))
  hasDescription(Int64(-42))
  hasDescription(UInt8(42))
  hasDescription(UInt16(42))
  hasDescription(UInt32(42))
  hasDescription(UInt64(42))

  hasDescription(Bool(true))

  hasDescription(CChar(42))
  hasDescription(CUnsignedChar(42))
  hasDescription(CUnsignedShort(42))
  hasDescription(CUnsignedInt(42))
  hasDescription(CUnsignedLong(42))
  hasDescription(CUnsignedLongLong(42))
  hasDescription(CSignedChar(42))
  hasDescription(CShort(42))
  hasDescription(CInt(42))
  hasDescription(CLong(42))
  hasDescription(CLongLong(42))
  hasDescription(CFloat(1.0))
  hasDescription(CDouble(1.0))

  hasDescription(CWideChar(42))
  hasDescription(CChar16(42))
  hasDescription(CChar32(42))
  hasDescription(CBool(true))
}

var failed = false

func printedIs<T>(
    object: T, _ expected1: String, expected2: String? = nil,
    file: StaticString = __FILE__, line: UInt = __LINE__
) {
  let actual = String(object)
  var match = expected1 == actual
  if !match && expected2 != nil {
    match = expected2! == actual
  }
  if !match {
    print(
      "check failed at \(file), line \(line)",
      "expected: \"\(expected1)\" or \"\(expected2)\"",
      "actual: \"\(actual)\"",
      "",
      separator: "\n")
    failed = true
  }
}

func debugPrintedIs<T>(
    object: T, _ expected1: String, expected2: String? = nil,
    file: StaticString = __FILE__, line: UInt = __LINE__
) {
  var actual = ""
  debugPrint(object, terminator: "", toStream: &actual)
  if expected1 != actual && (expected2 == nil || expected2! != actual) {
    print(
      "check failed at \(file), line \(line)",
      "expected: \"\(expected1)\" or \"\(expected2)\"",
      "actual: \"\(actual)\"",
      "",
      separator: "\n")
    failed = true
  }
}

func assertEquals(
    expected: String, _ actual: String,
    file: StaticString = __FILE__, line: UInt = __LINE__
) {
  if expected != actual {
    print(
      "check failed at \(file), line \(line)",
      "expected: \"\(expected)\"",
      "actual: \"\(actual)\"",
      "",
      separator: "\n")
    failed = true
  }
}

PrintTests.test("test stdlib types printed") {
  expectPrinted("1.0", Float(1.0))
  expectPrinted("-1.0", Float(-1.0))
  expectPrinted("1.0", Double(1.0))
  expectPrinted("-1.0", Double(-1.0))

  expectPrinted("42", CChar(42))
  expectPrinted("42", CUnsignedChar(42))
  expectPrinted("42", CUnsignedShort(42))
  expectPrinted("42", CUnsignedInt(42))
  expectPrinted("42", CUnsignedLong(42))
  expectPrinted("42", CUnsignedLongLong(42))
  expectPrinted("42", CSignedChar(42))
  expectPrinted("42", CShort(42))
  expectPrinted("42", CInt(42))
  expectPrinted("42", CLong(42))
  expectPrinted("42", CLongLong(42))
  expectPrinted("1.0", CFloat(1.0))
  expectPrinted("-1.0", CFloat(-1.0))
  expectPrinted("1.0", CDouble(1.0))
  expectPrinted("-1.0", CDouble(-1.0))

  expectPrinted("*", CWideChar(42))
  expectPrinted("42", CChar16(42))
  expectPrinted("*", CChar32(42))
  expectPrinted("true", CBool(true))
  expectPrinted("false", CBool(false))


  let s0: String = "abc"
  expectPrinted("abc", s0)
  expectDebugPrinted("\"abc\"", s0)

  let s1: String =  "\\ \' \" \0 \n \r \t \u{05}"
  expectDebugPrinted("\"\\\\ \\\' \\\" \\0 \\n \\r \\t \\u{05}\"", s1)

  let ch: Character = "a"
  expectPrinted("a", ch)
  expectDebugPrinted("\"a\"", ch)

  let us0: UnicodeScalar = "a"
  expectPrinted("a", us0)
  expectDebugPrinted("\"a\"", us0)

  let us1: UnicodeScalar = "\\"
  expectPrinted("\\", us1)
  expectEqual("\"\\\\\"", us1.description)
  expectDebugPrinted("\"\\\\\"", us1)

  let us2: UnicodeScalar = "あ"
  expectPrinted("あ", us2)
  expectEqual("\"あ\"", us2.description)
  expectDebugPrinted("\"\\u{3042}\"", us2)
}

PrintTests.test("optional strings") {
  expectEqual("nil", String!())
  expectEqual("meow", String!("meow"))
  expectEqual("nil", String?())
  expectEqual("Optional(\"meow\")", String?("meow"))
}

PrintTests.test("custom string convertible structs") {
  struct Wrapper : CustomStringConvertible {
    var x: CustomStringConvertible? = nil
    
    var description: String {
      return "Wrapper(\(x.debugDescription))"
    }
  }
  expectPrinted("Wrapper(nil)", Wrapper())
  expectPrinted("Wrapper(Optional(Wrapper(nil)))",
    Wrapper(x: Wrapper()))
  expectPrinted("Wrapper(Optional(Wrapper(Optional(Wrapper(nil)))))",
    Wrapper(x: Wrapper(x: Wrapper())))
}

PrintTests.test("integer printing") {
  if (UInt64(Int.max) > 0x1_0000_0000 as UInt64) {
    expectPrinted("-9223372036854775808", Int.min)
    expectPrinted("9223372036854775807", Int.max)
  } else {
    expectPrinted("-2147483648", Int.min)
    expectPrinted("2147483647", Int.max)
  }
  
  expectPrinted("0", Int(0))
  expectPrinted("42", Int(42))
  expectPrinted("-42", Int(-42))
  
  if (UInt64(UInt.max) > 0x1_0000_0000 as UInt64) {
    expectPrinted("18446744073709551615", UInt.max)
  } else {
    expectPrinted("4294967295", UInt.max)
  }
  
  expectPrinted("0", UInt.min)
  expectPrinted("0", UInt(0))
  expectPrinted("42", UInt(42))
  
  expectPrinted("-128", Int8.min)
  expectPrinted("127", Int8.max)
  expectPrinted("0", Int8(0))
  expectPrinted("42", Int8(42))
  expectPrinted("-42", Int8(-42))
  
  expectPrinted("0", UInt8.min)
  expectPrinted("255", UInt8.max)
  expectPrinted("0", UInt8(0))
  expectPrinted("42", UInt8(42))
  
  expectPrinted("-32768", Int16.min)
  expectPrinted("32767", Int16.max)
  expectPrinted("0", Int16(0))
  expectPrinted("42", Int16(42))
  expectPrinted("-42", Int16(-42))
  
  expectPrinted("0", UInt16.min)
  expectPrinted("65535", UInt16.max)
  expectPrinted("0", UInt16(0))
  expectPrinted("42", UInt16(42))
  
  expectPrinted("-2147483648", Int32.min)
  expectPrinted("2147483647", Int32.max)
  expectPrinted("0", Int32(0))
  expectPrinted("42", Int32(42))
  expectPrinted("-42", Int32(-42))
  
  expectPrinted("0", UInt32.min)
  expectPrinted("4294967295", UInt32.max)
  expectPrinted("0", UInt32(0))
  expectPrinted("42", UInt32(42))
  
  expectPrinted("-9223372036854775808", Int64.min)
  expectPrinted("9223372036854775807", Int64.max)
  expectPrinted("0", Int64(0))
  expectPrinted("42", Int64(42))
  expectPrinted("-42", Int64(-42))
  
  expectPrinted("0", UInt64.min)
  expectPrinted("18446744073709551615", UInt64.max)
  expectPrinted("0", UInt64(0))
  expectPrinted("42", UInt64(42))
  
  expectPrinted("-42", Int8(-42))
  expectPrinted("-42", Int16(-42))
  expectPrinted("-42", Int32(-42))
  expectPrinted("-42", Int64(-42))
  expectPrinted("42", UInt8(42))
  expectPrinted("42", UInt16(42))
  expectPrinted("42", UInt32(42))
  expectPrinted("42", UInt64(42))
}

PrintTests.test("floating point printing") {
  func asFloat32(f: Float32) -> Float32 { return f }
  func asFloat64(f: Float64) -> Float64 { return f }
  #if arch(i386) || arch(x86_64)
    func asFloat80(f: Swift.Float80) -> Swift.Float80 { return f }
  #endif
  
  expectPrinted("inf", Float.infinity)
  expectPrinted("-inf", -Float.infinity)
  expectPrinted("nan", Float.NaN)
  expectPrinted("0.0", asFloat32(0.0))
  expectPrinted("1.0", asFloat32(1.0))
  expectPrinted("-1.0", asFloat32(-1.0))
  expectPrinted("100.125", asFloat32(100.125))
  expectPrinted("-100.125", asFloat32(-100.125))
  
  expectPrinted("inf", Double.infinity)
  expectPrinted("-inf", -Double.infinity)
  expectPrinted("nan", Double.NaN)
  expectPrinted("0.0", asFloat64(0.0))
  expectPrinted("1.0", asFloat64(1.0))
  expectPrinted("-1.0", asFloat64(-1.0))
  expectPrinted("100.125", asFloat64(100.125))
  expectPrinted("-100.125", asFloat64(-100.125))
  
  expectPrinted("1.00001", asFloat32(1.00001))
  expectPrinted("1.25e+17", asFloat32(125000000000000000.0))
  expectPrinted("1.25e+16", asFloat32(12500000000000000.0))
  expectPrinted("1.25e+15", asFloat32(1250000000000000.0))
  expectPrinted("1.25e+14", asFloat32(125000000000000.0))
  expectPrinted("1.25e+13", asFloat32(12500000000000.0))
  expectPrinted("1.25e+12", asFloat32(1250000000000.0))
  expectPrinted("1.25e+11", asFloat32(125000000000.0))
  expectPrinted("1.25e+10", asFloat32(12500000000.0))
  expectPrinted("1.25e+09", asFloat32(1250000000.0))
  expectPrinted("1.25e+08", asFloat32(125000000.0))
  expectPrinted("1.25e+07", asFloat32(12500000.0))
  expectPrinted("1.25e+06", asFloat32(1250000.0))
  expectPrinted("125000.0", asFloat32(125000.0))
  expectPrinted("12500.0",  asFloat32(12500.0))
  expectPrinted("1250.0",   asFloat32(1250.0))
  expectPrinted("125.0",    asFloat32(125.0))
  expectPrinted("12.5",     asFloat32(12.5))
  expectPrinted("1.25",     asFloat32(1.25))
  expectPrinted("0.125",    asFloat32(0.125))
  expectPrinted("0.0125",   asFloat32(0.0125))
  expectPrinted("0.00125",  asFloat32(0.00125))
  expectPrinted("0.000125", asFloat32(0.000125))
  expectPrinted("1.25e-05", asFloat32(0.0000125))
  expectPrinted("1.25e-06", asFloat32(0.00000125))
  expectPrinted("1.25e-07", asFloat32(0.000000125))
  expectPrinted("1.25e-08", asFloat32(0.0000000125))
  expectPrinted("1.25e-09", asFloat32(0.00000000125))
  expectPrinted("1.25e-10", asFloat32(0.000000000125))
  expectPrinted("1.25e-11", asFloat32(0.0000000000125))
  expectPrinted("1.25e-12", asFloat32(0.00000000000125))
  expectPrinted("1.25e-13", asFloat32(0.000000000000125))
  expectPrinted("1.25e-14", asFloat32(0.0000000000000125))
  expectPrinted("1.25e-15", asFloat32(0.00000000000000125))
  expectPrinted("1.25e-16", asFloat32(0.000000000000000125))
  expectPrinted("1.25e-17", asFloat32(0.0000000000000000125))
  
  expectPrinted("1.00000000000001", asFloat64(1.00000000000001))
  expectPrinted("1.25e+17", asFloat64(125000000000000000.0))
  expectPrinted("1.25e+16", asFloat64(12500000000000000.0))
  expectPrinted("1.25e+15", asFloat64(1250000000000000.0))
  expectPrinted("125000000000000.0", asFloat64(125000000000000.0))
  expectPrinted("12500000000000.0", asFloat64(12500000000000.0))
  expectPrinted("1250000000000.0", asFloat64(1250000000000.0))
  expectPrinted("125000000000.0", asFloat64(125000000000.0))
  expectPrinted("12500000000.0", asFloat64(12500000000.0))
  expectPrinted("1250000000.0", asFloat64(1250000000.0))
  expectPrinted("125000000.0", asFloat64(125000000.0))
  expectPrinted("12500000.0", asFloat64(12500000.0))
  expectPrinted("1250000.0", asFloat64(1250000.0))
  expectPrinted("125000.0", asFloat64(125000.0))
  expectPrinted("12500.0", asFloat64(12500.0))
  expectPrinted("1250.0", asFloat64(1250.0))
  expectPrinted("125.0", asFloat64(125.0))
  expectPrinted("12.5", asFloat64(12.5))
  expectPrinted("1.25", asFloat64(1.25))
  expectPrinted("0.125", asFloat64(0.125))
  expectPrinted("0.0125", asFloat64(0.0125))
  expectPrinted("0.00125", asFloat64(0.00125))
  expectPrinted("0.000125", asFloat64(0.000125))
  expectPrinted("1.25e-05", asFloat64(0.0000125))
  expectPrinted("1.25e-06", asFloat64(0.00000125))
  expectPrinted("1.25e-07", asFloat64(0.000000125))
  expectPrinted("1.25e-08", asFloat64(0.0000000125))
  expectPrinted("1.25e-09", asFloat64(0.00000000125))
  expectPrinted("1.25e-10", asFloat64(0.000000000125))
  expectPrinted("1.25e-11", asFloat64(0.0000000000125))
  expectPrinted("1.25e-12", asFloat64(0.00000000000125))
  expectPrinted("1.25e-13", asFloat64(0.000000000000125))
  expectPrinted("1.25e-14", asFloat64(0.0000000000000125))
  expectPrinted("1.25e-15", asFloat64(0.00000000000000125))
  expectPrinted("1.25e-16", asFloat64(0.000000000000000125))
  expectPrinted("1.25e-17", asFloat64(0.0000000000000000125))
  
  #if arch(i386) || arch(x86_64)
    expectPrinted("1.00000000000000001", asFloat80(1.00000000000000001))
    expectPrinted("1.25e+19", asFloat80(12500000000000000000.0))
    expectPrinted("1.25e+18", asFloat80(1250000000000000000.0))
    expectPrinted("125000000000000000.0", asFloat80(125000000000000000.0))
    expectPrinted("12500000000000000.0", asFloat80(12500000000000000.0))
    expectPrinted("1250000000000000.0", asFloat80(1250000000000000.0))
    expectPrinted("125000000000000.0", asFloat80(125000000000000.0))
    expectPrinted("12500000000000.0", asFloat80(12500000000000.0))
    expectPrinted("1250000000000.0", asFloat80(1250000000000.0))
    expectPrinted("125000000000.0", asFloat80(125000000000.0))
    expectPrinted("12500000000.0", asFloat80(12500000000.0))
    expectPrinted("1250000000.0", asFloat80(1250000000.0))
    expectPrinted("125000000.0", asFloat80(125000000.0))
    expectPrinted("12500000.0", asFloat80(12500000.0))
    expectPrinted("1250000.0", asFloat80(1250000.0))
    expectPrinted("125000.0", asFloat80(125000.0))
    expectPrinted("12500.0", asFloat80(12500.0))
    expectPrinted("1250.0", asFloat80(1250.0))
    expectPrinted("125.0", asFloat80(125.0))
    expectPrinted("12.5", asFloat80(12.5))
    expectPrinted("1.25", asFloat80(1.25))
    expectPrinted("0.125", asFloat80(0.125))
    expectPrinted("0.0125", asFloat80(0.0125))
    expectPrinted("0.00125", asFloat80(0.00125))
    expectPrinted("0.000125", asFloat80(0.000125))
    expectPrinted("1.25e-05", asFloat80(0.0000125))
    expectPrinted("1.25e-06", asFloat80(0.00000125))
    expectPrinted("1.25e-07", asFloat80(0.000000125))
    expectPrinted("1.25e-08", asFloat80(0.0000000125))
    expectPrinted("1.25e-09", asFloat80(0.00000000125))
    expectPrinted("1.25e-10", asFloat80(0.000000000125))
    expectPrinted("1.25e-11", asFloat80(0.0000000000125))
    expectPrinted("1.25e-12", asFloat80(0.00000000000125))
    expectPrinted("1.25e-13", asFloat80(0.000000000000125))
    expectPrinted("1.25e-14", asFloat80(0.0000000000000125))
    expectPrinted("1.25e-15", asFloat80(0.00000000000000125))
    expectPrinted("1.25e-16", asFloat80(0.000000000000000125))
    expectPrinted("1.25e-17", asFloat80(0.0000000000000000125))
  #endif
}

func test_BoolPrinting() {
  printedIs(Bool(true), "true")
  printedIs(Bool(false), "false")

  printedIs(true, "true")
  printedIs(false, "false")

  print("test_BoolPrinting done")
}
test_BoolPrinting()
// CHECK: test_BoolPrinting done

func test_CTypesPrinting() {
  printedIs(CChar(42), "42")
  printedIs(CUnsignedChar(42), "42")
  printedIs(CUnsignedShort(42), "42")
  printedIs(CUnsignedInt(42), "42")
  printedIs(CUnsignedLong(42), "42")
  printedIs(CUnsignedLongLong(42), "42")
  printedIs(CSignedChar(42), "42")
  printedIs(CShort(42), "42")
  printedIs(CInt(42), "42")
  printedIs(CLong(42), "42")
  printedIs(CLongLong(42), "42")
  printedIs(CFloat(1.0), "1.0")
  printedIs(CFloat(-1.0), "-1.0")
  printedIs(CDouble(1.0), "1.0")
  printedIs(CDouble(-1.0), "-1.0")

  printedIs(CWideChar(42), "*")
  printedIs(CChar16(42), "42")
  printedIs(CChar32(42), "*")
  printedIs(CBool(true), "true")
  printedIs(CBool(false), "false")

  print("test_CTypesPrinting done")
}
test_CTypesPrinting()
// CHECK: test_CTypesPrinting done


func test_PointerPrinting() {
  let nullUP = UnsafeMutablePointer<Float>()
  let fourByteUP = UnsafeMutablePointer<Float>(bitPattern: 0xabcd1234 as UInt)

#if !(arch(i386) || arch(arm))
  let eightByteAddr: UInt = 0xabcddcba12344321
  let eightByteUP = UnsafeMutablePointer<Float>(bitPattern: eightByteAddr)
#endif

#if arch(i386) || arch(arm)
  let expectedNull = "0x00000000"
  printedIs(fourByteUP, "0xabcd1234")
#else
  let expectedNull = "0x0000000000000000"
  printedIs(fourByteUP, "0x00000000abcd1234")
  printedIs(eightByteUP, "0xabcddcba12344321")
#endif

  printedIs(nullUP, expectedNull)

  printedIs(UnsafeBufferPointer(start: nullUP, count: 0),
      "UnsafeBufferPointer(start: \(expectedNull), length: 0)")
  printedIs(UnsafeMutableBufferPointer(start: nullUP, count: 0),
      "UnsafeMutableBufferPointer(start: \(expectedNull), length: 0)")

  printedIs(COpaquePointer(), expectedNull)
  printedIs(CVaListPointer(_fromUnsafeMutablePointer: nullUP), expectedNull)
  printedIs(AutoreleasingUnsafeMutablePointer<Int>(), expectedNull)

  print("test_PointerPrinting done")
}
test_PointerPrinting()
// CHECK: test_PointerPrinting done


protocol ProtocolUnrelatedToPrinting {}

struct StructPrintable : CustomStringConvertible, ProtocolUnrelatedToPrinting {
  let x: Int

  init(_ x: Int) {
    self.x = x
  }

  var description: String {
    return "►\(x)◀︎"
  }
}

struct LargeStructPrintable : CustomStringConvertible, ProtocolUnrelatedToPrinting {
  let a: Int
  let b: Int
  let c: Int
  let d: Int

  init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
    self.a = a
    self.b = b
    self.c = c
    self.d = d
  }

  var description: String {
    return "<\(a) \(b) \(c) \(d)>"
  }
}

struct StructDebugPrintable : CustomDebugStringConvertible {
  let x: Int

  init(_ x: Int) {
    self.x = x
  }

  var debugDescription: String {
    return "►\(x)◀︎"
  }
}

struct StructVeryPrintable : CustomStringConvertible, CustomDebugStringConvertible, ProtocolUnrelatedToPrinting {
  let x: Int

  init(_ x: Int) {
    self.x = x
  }

  var description: String {
    return "<description: \(x)>"
  }

  var debugDescription: String {
    return "<debugDescription: \(x)>"
  }
}

struct EmptyStructWithoutDescription {}

struct WithoutDescription {
  let x: Int

  init(_ x: Int) {
    self.x = x
  }
}

struct ValuesWithoutDescription<T, U, V> {
  let t: T
  let u: U
  let v: V

  init(_ t: T, _ u: U, _ v: V) {
    self.t = t
    self.u = u
    self.v = v
  }
}


class ClassPrintable : CustomStringConvertible, ProtocolUnrelatedToPrinting {
  let x: Int

  init(_ x: Int) {
    self.x = x
  }

  var description: String {
    return "►\(x)◀︎"
  }
}

class ClassVeryPrintable : CustomStringConvertible, CustomDebugStringConvertible, ProtocolUnrelatedToPrinting {
  let x: Int

  init(_ x: Int) {
    self.x = x
  }

  var description: String {
    return "<description: \(x)>"
  }

  var debugDescription: String {
    return "<debugDescription: \(x)>"
  }
}

func test_ObjectPrinting() {
  do {
    let s = StructPrintable(1)
    printedIs(s, "►1◀︎")
  }
  do {
    let s: ProtocolUnrelatedToPrinting = StructPrintable(1)
    printedIs(s, "►1◀︎")
  }
  do {
    let s: CustomStringConvertible = StructPrintable(1)
    printedIs(s, "►1◀︎")
  }
  do {
    let s: Any = StructPrintable(1)
    printedIs(s, "►1◀︎")
  }

  do {
    let s = LargeStructPrintable(10, 20, 30, 40)
    printedIs(s, "<10 20 30 40>")
  }
  do {
    let s: ProtocolUnrelatedToPrinting = LargeStructPrintable(10, 20, 30, 40)
    printedIs(s, "<10 20 30 40>")
  }
  do {
    let s: CustomStringConvertible = LargeStructPrintable(10, 20, 30, 40)
    printedIs(s, "<10 20 30 40>")
  }
  do {
    let s: Any = LargeStructPrintable(10, 20, 30, 40)
    printedIs(s, "<10 20 30 40>")
  }

  do {
    let s = StructVeryPrintable(1)
    printedIs(s, "<description: 1>")
  }
  do {
    let s: ProtocolUnrelatedToPrinting = StructVeryPrintable(1)
    printedIs(s, "<description: 1>")
  }
  do {
    let s: CustomStringConvertible = StructVeryPrintable(1)
    printedIs(s, "<description: 1>")
  }
  do {
    let s: CustomDebugStringConvertible = StructVeryPrintable(1)
    printedIs(s, "<description: 1>")
  }
  do {
    let s: Any = StructVeryPrintable(1)
    printedIs(s, "<description: 1>")
  }

  do {
    let c = ClassPrintable(1)
    printedIs(c, "►1◀︎")
  }
  do {
    let c: ProtocolUnrelatedToPrinting = ClassPrintable(1)
    printedIs(c, "►1◀︎")
  }
  do {
    let c: CustomStringConvertible = ClassPrintable(1)
    printedIs(c, "►1◀︎")
  }
  do {
    let c: Any = ClassPrintable(1)
    printedIs(c, "►1◀︎")
  }

  do {
    let c = ClassVeryPrintable(1)
    printedIs(c, "<description: 1>")
  }
  do {
    let c: ProtocolUnrelatedToPrinting = ClassVeryPrintable(1)
    printedIs(c, "<description: 1>")
  }
  do {
    let c: CustomStringConvertible = ClassVeryPrintable(1)
    printedIs(c, "<description: 1>")
  }
  do {
    let c: CustomDebugStringConvertible = ClassVeryPrintable(1)
    printedIs(c, "<description: 1>")
  }
  do {
    let c: Any = ClassVeryPrintable(1)
    printedIs(c, "<description: 1>")
  }

  print("test_ObjectPrinting done")
}
test_ObjectPrinting()
// CHECK: test_ObjectPrinting done

func test_ThickMetatypePrintingImpl<T>(
    thickMetatype: T.Type,
    _ expectedPrint: String,
    _ expectedDebug: String
) {
  printedIs(thickMetatype, expectedPrint)
  printedIs([ thickMetatype ], "[" + expectedDebug + "]")
  debugPrintedIs(thickMetatype, expectedDebug)
  debugPrintedIs([ thickMetatype ], "[" + expectedDebug + "]")
}

func test_gcMetatypePrinting() {
  let structMetatype = StructPrintable.self
  printedIs(structMetatype, "StructPrintable")
  debugPrintedIs(structMetatype, "a.StructPrintable")
  printedIs([ structMetatype ], "[a.StructPrintable]")
  debugPrintedIs([ structMetatype ], "[a.StructPrintable]")
  test_ThickMetatypePrintingImpl(structMetatype, "StructPrintable",
    "a.StructPrintable")

  let classMetatype = ClassPrintable.self
  printedIs(classMetatype, "ClassPrintable")
  debugPrintedIs(classMetatype, "a.ClassPrintable")
  printedIs([ classMetatype ], "[a.ClassPrintable]")
  debugPrintedIs([ classMetatype ], "[a.ClassPrintable]")
  test_ThickMetatypePrintingImpl(classMetatype, "ClassPrintable",
    "a.ClassPrintable")

  print("test_gcMetatypePrinting done")
}
test_gcMetatypePrinting()
// CHECK: test_gcMetatypePrinting done

func test_ArrayPrinting() {
  let arrayOfInts: [Int] = []
  printedIs(arrayOfInts, "[]")

  printedIs([ 1 ], "[1]")
  printedIs([ 1, 2 ], "[1, 2]")
  printedIs([ 1, 2, 3 ], "[1, 2, 3]")

  printedIs([ "foo", "bar", "bas" ], "[\"foo\", \"bar\", \"bas\"]")
  debugPrintedIs([ "foo", "bar", "bas" ], "[\"foo\", \"bar\", \"bas\"]")

  printedIs([ StructPrintable(1), StructPrintable(2),
              StructPrintable(3) ],
            "[►1◀︎, ►2◀︎, ►3◀︎]")

  printedIs([ LargeStructPrintable(10, 20, 30, 40),
              LargeStructPrintable(50, 60, 70, 80) ],
            "[<10 20 30 40>, <50 60 70 80>]")

  printedIs([ StructDebugPrintable(1) ], "[►1◀︎]")

  printedIs([ ClassPrintable(1), ClassPrintable(2),
              ClassPrintable(3) ],
            "[►1◀︎, ►2◀︎, ►3◀︎]")

  printedIs([ ClassPrintable(1), ClassPrintable(2),
              ClassPrintable(3) ] as Array<AnyObject>,
            "[►1◀︎, ►2◀︎, ►3◀︎]")

  print("test_ArrayPrinting done")
}
test_ArrayPrinting()
// CHECK: test_ArrayPrinting done

func test_DictionaryPrinting() {
  var dictSI: Dictionary<String, Int> = [:]
  printedIs(dictSI, "[:]")
  debugPrintedIs(dictSI, "[:]")

  dictSI = [ "aaa": 1 ]
  printedIs(dictSI, "[\"aaa\": 1]")
  debugPrintedIs(dictSI, "[\"aaa\": 1]")

  dictSI = [ "aaa": 1, "bbb": 2 ]
  printedIs(dictSI, "[\"aaa\": 1, \"bbb\": 2]", expected2: "[\"bbb\": 2, \"aaa\": 1]")
  debugPrintedIs(dictSI, "[\"aaa\": 1, \"bbb\": 2]", expected2: "[\"bbb\": 2, \"aaa\": 1]")

  let dictSS = [ "aaa": "bbb" ]
  printedIs(dictSS, "[\"aaa\": \"bbb\"]")
  debugPrintedIs(dictSS, "[\"aaa\": \"bbb\"]")

  print("test_DictionaryPrinting done")
}
test_DictionaryPrinting()
// CHECK: test_DictionaryPrinting done

func test_SetPrinting() {
  var sI = Set<Int>()
  printedIs(sI, "[]")
  debugPrintedIs(sI, "Set([])")

  sI = Set<Int>([11, 22])
  printedIs(sI, "[11, 22]", expected2: "[22, 11]")
  debugPrintedIs(sI, "Set([11, 22])", expected2: "Set([22, 11])")

  let sS = Set<String>(["Hello", "world"])
  printedIs(sS, "[\"Hello\", \"world\"]", expected2: "[\"world\", \"Hello\"]")
  debugPrintedIs(sS, "Set([\"Hello\", \"world\"])", expected2: "Set([\"world\", \"Hello\"])")

  print("test_SetPrinting done")
}
test_SetPrinting()
// CHECK: test_SetPrinting done

func test_TuplePrinting() {
  let tuple1 = (42, ())
  printedIs(tuple1, "(42, ())")

  let tuple2 = ((), 42)
  printedIs(tuple2, "((), 42)")

  let tuple3 = (42, StructPrintable(3))
  printedIs(tuple3, "(42, ►3◀︎)")

  let tuple4 = (42, LargeStructPrintable(10, 20, 30, 40))
  printedIs(tuple4, "(42, <10 20 30 40>)")

  let tuple5 = (42, ClassPrintable(3))
  printedIs(tuple5, "(42, ►3◀︎)")

  let tuple6 = ([123: 123], (1, 2, "3"))
  printedIs(tuple6, "([123: 123], (1, 2, \"3\"))")

  let arrayOfTuples1 =
      [ (1, "two", StructPrintable(3), StructDebugPrintable(4),
         WithoutDescription(5)) ]
  printedIs(arrayOfTuples1, "[(1, \"two\", ►3◀︎, ►4◀︎, a.WithoutDescription(x: 5))]")

  let arrayOfTuples2 =
      [ (1, "two", WithoutDescription(3)),
        (11, "twenty-two", WithoutDescription(33)),
        (111, "two hundred twenty-two", WithoutDescription(333)) ]
  printedIs(arrayOfTuples2, "[(1, \"two\", a.WithoutDescription(x: 3)), (11, \"twenty-two\", a.WithoutDescription(x: 33)), (111, \"two hundred twenty-two\", a.WithoutDescription(x: 333))]")

  print("test_TuplePrinting done")
}
test_TuplePrinting()
// CHECK: test_TuplePrinting done

func test_ArbitraryStructPrinting() {
  let arrayOfArbitraryStructs =
    [ WithoutDescription(1), WithoutDescription(2), WithoutDescription(3) ]
  printedIs(
    arrayOfArbitraryStructs,
    "[a.WithoutDescription(x: 1), a.WithoutDescription(x: 2), a.WithoutDescription(x: 3)]")
  debugPrintedIs(
    arrayOfArbitraryStructs,
    "[a.WithoutDescription(x: 1), a.WithoutDescription(x: 2), a.WithoutDescription(x: 3)]")

  printedIs(
    EmptyStructWithoutDescription(),
    "EmptyStructWithoutDescription()")
  debugPrintedIs(
    EmptyStructWithoutDescription(),
    "a.EmptyStructWithoutDescription()")

  printedIs(
    ValuesWithoutDescription(1.25, "abc", [ 1, 2, 3 ]),
    "ValuesWithoutDescription<Double, String, Array<Int>>(t: 1.25, u: \"abc\", v: [1, 2, 3])")
  debugPrintedIs(
    ValuesWithoutDescription(1.25, "abc", [ 1, 2, 3 ]),
    "a.ValuesWithoutDescription<Swift.Double, Swift.String, Swift.Array<Swift.Int>>(t: 1.25, u: \"abc\", v: [1, 2, 3])")

  print("test_ArbitraryStructPrinting done")
}
test_ArbitraryStructPrinting()
// CHECK: test_ArbitraryStructPrinting done

func test_MetatypePrinting() {
  printedIs(Int.self, "Int")
  debugPrintedIs(Int.self, "Swift.Int")

  print("test_MetatypePrinting done")
}
test_MetatypePrinting()
// CHECK: test_MetatypePrinting done

func test_StringInterpolation() {
  assertEquals("1", "\(1)")
  assertEquals("2", "\(1 + 1)")
  assertEquals("aaa1bbb2ccc", "aaa\(1)bbb\(2)ccc")

  assertEquals("1.0", "\(1.0)")
  assertEquals("1.5", "\(1.5)")
  assertEquals("1e-12", "\(1.0 / (1000000000000))")

  assertEquals("inf", "\(1 / 0.0)")
  assertEquals("-inf", "\(-1 / 0.0)")
  assertEquals("nan", "\(0 / 0.0)")

  assertEquals("<[►1◀︎, ►2◀︎, ►3◀︎]>", "<\([ StructPrintable(1), StructPrintable(2), StructPrintable(3) ])>")
  assertEquals("WithoutDescription(x: 1)", "\(WithoutDescription(1))")

  print("test_StringInterpolation done")
}
test_StringInterpolation()
// CHECK: test_StringInterpolation done

struct MyString : StringLiteralConvertible, StringInterpolationConvertible {
  init(str: String) {
    value = str
  }

  var value: String

  init(unicodeScalarLiteral value: String) {
    self.init(str: value)
  }

  init(extendedGraphemeClusterLiteral value: String) {
    self.init(str: value)
  }

  init(stringLiteral value: String) {
    self.init(str: value)
  }

  init(stringInterpolation strings: MyString...) {
    var result = ""
    for s in strings {
      result += s.value
    }
    self.init(str: result)
  }

  init<T>(stringInterpolationSegment expr: T) {
    self.init(str: "<segment " + String(expr) + ">")
  }
}

func test_CustomStringInterpolation() {
  assertEquals("<segment aaa><segment 1><segment bbb>",
               ("aaa\(1)bbb" as MyString).value)

  print("test_CustomStringInterpolation done")
}
test_CustomStringInterpolation()
// CHECK: test_CustomStringInterpolation done

func test_StdoutUTF8Printing() {
  print("\u{00B5}")
// CHECK: {{^}}µ{{$}}

  print("test_StdoutUTF8Printing done")
}
test_StdoutUTF8Printing()
// CHECK: test_StdoutUTF8Printing done

func test_varargs() {
  print("", 1, 2, 3, 4, "", separator: "|") // CHECK: |1|2|3|4|
  print(1, 2, 3, separator: "\n", terminator: "===")
  print(4, 5, 6, separator: "\n")
  // CHECK-NEXT: 1
  // CHECK-NEXT: 2
  // CHECK-NEXT: 3===4
  // CHECK-NEXT: 5
  // CHECK-NEXT: 6

  debugPrint("", 1, 2, 3, 4, "", separator: "|")
   // CHECK-NEXT: ""|1|2|3|4|""
  debugPrint(1, 2, 3, separator: "\n", terminator: "===")
  debugPrint(4, 5, 6, separator: "\n")
  // CHECK-NEXT: 1
  // CHECK-NEXT: 2
  // CHECK-NEXT: 3===4
  // CHECK-NEXT: 5
  // CHECK-NEXT: 6

  var output = ""
  print(
    "", 1, 2, 3, 4, "", separator: "|", toStream: &output)
  print(output == "|1|2|3|4|\n") // CHECK-NEXT: true
  output = ""
  debugPrint(
    "", 1, 2, 3, 4, "", separator: "|", terminator: "", toStream: &output)
  print(output == "\"\"|1|2|3|4|\"\"") // CHECK-NEXT: true
  print("test_varargs done")
}
test_varargs()
// CHECK: test_varargs done

func test_playgroundPrintHook() {
  
  var printed: String? = nil
  _playgroundPrintHook = { printed = $0 }
  
  print("", 1, 2, 3, 4, "", separator: "|") // CHECK: |1|2|3|4|
  print("%\(printed!)%") // CHECK-NEXT: %|1|2|3|4|
  // CHECK-NEXT: %
  
  printed = nil
  debugPrint("", 1, 2, 3, 4, "", separator: "|")
  // CHECK-NEXT: ""|1|2|3|4|""
  print("%\(printed!)%") // CHECK-NEXT: %""|1|2|3|4|""
  // CHECK-NEXT: %
  
  var explicitStream = ""
  printed = nil
  print("", 1, 2, 3, 4, "", separator: "!", toStream: &explicitStream)
  print(printed)               // CHECK-NEXT: nil
  print("%\(explicitStream)%") // CHECK-NEXT: %!1!2!3!4!
  // CHECK-NEXT: %
  
  explicitStream = ""
  printed = nil
  debugPrint(
    "", 1, 2, 3, 4, "", separator: "!", toStream: &explicitStream)
  print(printed) // CHECK-NEXT: nil
  print("%\(explicitStream)%") // CHECK-NEXT: %""!1!2!3!4!""
  // CHECK-NEXT: %
  
  _playgroundPrintHook = nil
  print("test_playgroundPrintHook done")
  // CHECK-NEXT: test_playgroundPrintHook done
}
test_playgroundPrintHook()

if !failed {
  print("OK")
}
// CHECK: OK

