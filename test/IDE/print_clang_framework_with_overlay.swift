// RUN: rm -rf %t
// RUN: mkdir -p %t

// RUN: %target-swift-frontend(mock-sdk: -F %S/Inputs/mock-sdk) -I %t -emit-module -o %t/FooOverlay.swiftmodule %S/Inputs/FooOverlay.swift
// RUN: %target-swift-ide-test(mock-sdk: -F %S/Inputs/mock-sdk) -I %t -print-module -source-filename %s -module-to-print=FooOverlay -function-definitions=false | FileCheck %s

import FooOverlay

// CHECK: @_exported import Foo
// CHECK: @_exported import struct Foo.FooStruct1
// CHECK: @_exported import Foo.FooSub
// CHECK: @_exported import func Foo.FooSub.fooSubFunc1
// FIXME: this duplicate import is silly, but not harmful.
// CHECK: @_exported import func Foo.fooSubFunc1
// CHECK: func fooSubOverlayFunc1(x: Int32) -> Int32
