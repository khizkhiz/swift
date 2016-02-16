// RUN: %sourcekitd-test -req=demangle unmangled _TtBf80_  _TtP3foo3bar_ | FileCheck %s
// CHECK:      START DEMANGLE
// CHECK-NEXT: <empty>
// CHECK-NEXT: Builtin.Float80
// CHECK-NEXT: foo.bar
// CHECK-NEXT: END DEMANGLE

// RUN: %sourcekitd-test -req=demangle unmangled _TtBf80_  _TtP3foo3bar_ -simplified-demangling | FileCheck %s -check-prefix=SIMPLIFIED
// SIMPLIFIED:      START DEMANGLE
// SIMPLIFIED-NEXT: <empty>
// SIMPLIFIED-NEXT: Builtin.Float80
// SIMPLIFIED-NEXT: bar
// SIMPLIFIED-NEXT: END DEMANGLE
