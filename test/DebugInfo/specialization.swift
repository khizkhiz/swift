// RUN: %target-swift-frontend -O %s -disable-llvm-optzns -emit-sil -g -o - | FileCheck %s

// CHECK: sil shared [noinline] @_TTSg5SiSis21IntegerArithmeticTypes__
// CHECK-SAME: _TF14specialization3sumuRxs21IntegerArithmeticTyperFTxx_x
// CHECK-SAME: $@convention(thin) (Int, Int) -> Int {
// CHECK: bb0(%0 : $Int, %1 : $Int):
// CHECK:  debug_value %0 : $Int, let, name "i", argno 1
// CHECK:  debug_value %1 : $Int, let, name "j", argno 2
  
@inline(never)
public func sum<T : IntegerArithmeticType>(i : T, _ j : T) -> T {
  let result = i + j
  return result
}

public func inc(i: inout Int) {
  i = sum(i, 1)
}
