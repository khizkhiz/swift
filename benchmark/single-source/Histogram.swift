//===--- Histogram.swift --------------------------------------------------===//
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

// This test measures performance of histogram generating.
// <rdar://problem/17384894>
import TestsUtils

typealias rrggbb_t = UInt32

func output_sorted_sparse_rgb_histogram<S: SequenceType where S.Generator.Element == rrggbb_t>(samples: S, _ N: Int) {
  var histogram = Dictionary<rrggbb_t, Int>()
  for  _ in 1...50*N {
    for sample in samples {   // This part is really awful, I agree
      let i = histogram.indexForKey(sample)
      histogram[sample] = (i != nil ? histogram[i!].1 : 0) + 1
    }
  }
}

// Packed-RGB test data: four gray samples, two red, two blue, and a 4 pixel gradient from black to white
let samples: [rrggbb_t] = [
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF,
  0x00808080, 0x00808080, 0x00808080, 0x00808080,
  0x00FF0000, 0x00FF0000, 0x000000FF, 0x000000FF,
  0x00000000, 0x00555555, 0x00AAAAAA, 0x00FFFFFF
]

@inline(never)
public func run_Histogram(N: Int) {
  output_sorted_sparse_rgb_histogram(samples, N);
}
