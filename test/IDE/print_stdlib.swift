// Check interface produced for the standard library.
//
// RUN: %target-swift-ide-test -print-module -module-to-print=Swift -source-filename %s -print-interface > %t.txt
// RUN: FileCheck -check-prefix=CHECK-ARGC %s < %t.txt
// RUN: FileCheck %s < %t.txt
// RUN: FileCheck -check-prefix=CHECK-SUGAR %s < %t.txt
// RUN: FileCheck -check-prefix=CHECK-MUTATING-ATTR %s < %t.txt
// RUN: FileCheck -check-prefix=NO-FIXMES %s < %t.txt
// RUN: FileCheck -check-prefix=CHECK-ARGC %s < %t.txt

// RUN: %target-swift-ide-test -print-module -module-to-print=Swift -source-filename %s -print-interface-doc > %t-doc.txt
// RUN: FileCheck %s < %t-doc.txt

// RUN: %target-swift-ide-test -print-module -module-to-print=Swift -source-filename %s -print-interface -skip-underscored-stdlib-protocols > %t-prot.txt
// RUN: FileCheck -check-prefix=CHECK-UNDERSCORED-PROT %s < %t-prot.txt
// CHECK-UNDERSCORED-PROT-NOT: protocol _

// CHECK-ARGC: static var argc: CInt { get }

// CHECK-NOT: @rethrows
// CHECK-NOT: {{^}}import
// CHECK-NOT: _Double
// CHECK-NOT: _StringBuffer
// CHECK-NOT: _StringCore
// CHECK-NOT: _ArrayBody
// DONT_CHECK-NOT: {{([^I]|$)([^n]|$)([^d]|$)([^e]|$)([^x]|$)([^a]|$)([^b]|$)([^l]|$)([^e]|$)}}
// CHECK-NOT: buffer: _ArrayBuffer
// CHECK-NOT: func ~>
// FIXME: Builtin.
// FIXME: RawPointer
// CHECK-NOT: extension [
// CHECK-NOT: extension {{.*}}?
// CHECK-NOT: extension {{.*}}!
// CHECK-NOT: addressWithOwner
// CHECK-NOT: mutableAddressWithOwner
// CHECK-NOT: _ColorLiteralConvertible
// CHECK-NOT: _FileReferenceLiteralConvertible
// CHECK-NOT: _ImageLiteralConvertible

// CHECK-SUGAR: extension Array :
// CHECK-SUGAR: extension ImplicitlyUnwrappedOptional :
// CHECK-SUGAR: extension Optional :

// CHECK-MUTATING-ATTR: mutating func

// NO-FIXMES-NOT: FIXME
// RUN: %target-swift-ide-test -print-module-groups -module-to-print=Swift -source-filename %s -print-interface > %t-group.txt
// RUN: FileCheck -check-prefix=CHECK-GROUPS1 %s < %t-group.txt
// CHECK-GROUPS1: Module groups begin:
// CHECK-GROUPS1-DAG: Pointer
// CHECK-GROUPS1-DAG: C
// CHECK-GROUPS1-DAG: Protocols
// CHECK-GROUPS1-DAG: Optional
// CHECK-GROUPS1-DAG: Collection/Lazy Views
// CHECK-GROUPS1-DAG: Math
// CHECK-GROUPS1-DAG: Reflection
// CHECK-GROUPS1-DAG: Misc
// CHECK-GROUPS1-DAG: Collection
// CHECK-GROUPS1-DAG: Bool
// CHECK-GROUPS1-DAG: Assert
// CHECK-GROUPS1-DAG: String
// CHECK-GROUPS1-DAG: Collection/Array
// CHECK-GROUPS1-DAG: Collection/Type-erased
// CHECK-GROUPS1-NOT: <NULL>
// CHECK-GROUPS1: Module groups end.

// RUN: %target-swift-ide-test -print-module -module-group "Pointer" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "C" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Protocols" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Optional" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Collection/Lazy Views" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Math" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Reflection" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Misc" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Collection" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Bool" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Assert" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "String" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Collection/Array" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD
// RUN: %target-swift-ide-test -print-module -module-group "Collection/Type-erased" -synthesize-extension -module-to-print=Swift -source-filename %s -print-interface | FileCheck %s -check-prefix=CHECK-FREQUENT-WORD

// CHECK-FREQUENT-WORD: ///
