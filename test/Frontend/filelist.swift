// RUN: rm -rf %t && mkdir %t
// RUN: echo '%S/Inputs/filelist-other.swift' >> %t/input.txt
// RUN: echo '%s' >> %t/input.txt
// RUN: echo '%S/../Inputs/empty.swift' >> %t/input.txt
// RUN: not %target-swift-frontend -parse -filelist %t/input.txt -primary-file %s 2>&1 | FileCheck %s
// RUN: not %target-swift-frontend -parse -filelist %t/input.txt 2>&1 | FileCheck %s

// RUN: echo '%t/filelist-other.bc' >> %t/output.txt
// RUN: echo '%t/filelist.bc' >> %t/output.txt
// RUN: echo '%t/filelist-other.bc' >> %t/output.txt
// RUN: %target-swift-frontend -emit-bc -filelist %t/input.txt -output-filelist %t/output.txt -num-threads 1 -DWORKING -module-name main
// RUN: ls %t/filelist-other.bc %t/filelist.bc %t/filelist-other.bc

func test() {
#if !WORKING
  // Check with FileCheck because we want to see that this file is being
  // compiled.
  // CHECK: error: cannot convert value of type 'Bar' to specified type 'Foo'
  let x: Foo = other()
#endif
}
