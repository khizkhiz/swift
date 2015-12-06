// RUN: rm -rf %t  &&  mkdir %t
// RUN: ulimit -c unlimited && %target-jit-run %s -I %S -enable-source-import | FileCheck %s
// REQUIRES: executable_test

// REQUIRES: swift_interpreter

// FIXME: iOS: -enable-source-import plus %target-build-swift equals link errors
// FIXME: This test uses IRGen with -enable-source-import; it may fail with -g.

import complex

func printDensity(d: Int) {
  if (d > 40) {
     print(" ", terminator: "")
  } else if d > 6 {
     print(".", terminator: "")
  } else if d > 4 {
     print("+", terminator: "")
  } else if d > 2 {
     print("*", terminator: "")
  } else {
     print("#", terminator: "")
  }
}

extension Double {
  func abs() -> Double {
    if (self >= 0.0) { return self }
    return self * -1.0
  }
}

func getMandelbrotIterations(c: Complex, maxIterations: Int) -> Int {
  var n = 0
  var z = Complex()
  while (n < maxIterations && z.magnitude() < 4.0) {
    z = z*z + c
    n += 1
  }
  return n
}

func fractal (densityFunc:(c: Complex, maxIterations: Int) -> Int)
             (xMin:Double, xMax:Double,
              yMin:Double, yMax:Double,
              rows:Int, cols:Int,
              maxIterations:Int) {
  // Set the spacing for the points in the Mandelbrot set.
  var dX = (xMax - xMin) / Double(rows)
  var dY = (yMax - yMin) / Double(cols)
  // Iterate over the points an determine if they are in the
  // Mandelbrot set.
  for var row = xMin; row < xMax ; row += dX {
    for var col = yMin; col < yMax; col += dY {
      var c = Complex(real: col, imag: row)
      printDensity(densityFunc(c: c, maxIterations: maxIterations))
    }
    print("\n", terminator: "")
  }
}

var mandelbrot = fractal(getMandelbrotIterations)
mandelbrot(xMin: -1.35, xMax: 1.4, yMin: -2.0, yMax: 1.05, rows: 40, cols: 80,
           maxIterations: 200)

// CHECK: ################################################################################
// CHECK: ##############################********************##############################
// CHECK: ########################********************************########################
// CHECK: ####################***************************+++**********####################
// CHECK: #################****************************++...+++**********#################
// CHECK: ##############*****************************++++......+************##############
// CHECK: ############******************************++++.......+++************############
// CHECK: ##########******************************+++++....  ...++++************##########
// CHECK: ########******************************+++++....      ..++++++**********#########
// CHECK: #######****************************+++++.......     .....++++++**********#######
// CHECK: ######*************************+++++....... . ..   ............++*********######
// CHECK: #####*********************+++++++++...   ..             . ... ..++*********#####
// CHECK: ####******************++++++++++++.....                       ..++**********####
// CHECK: ###***************++++++++++++++... .                        ...+++**********###
// CHECK: ##**************+++.................                          ....+***********##
// CHECK: ##***********+++++.................                             .++***********##
// CHECK: #**********++++++.....       .....                             ..++***********##
// CHECK: #*********++++++......          .                              ..++************#
// CHECK: #*******+++++.......                                          ..+++************#
// CHECK: #++++............                                            ...+++************#
// CHECK: #++++............                                            ...+++************#
// CHECK: #******+++++........                                          ..+++************#
// CHECK: #********++++++.....            .                              ..++************#
// CHECK: #**********++++++.....        ....                              .++************#
// CHECK: #************+++++.................                            ..++***********##
// CHECK: ##*************++++.................                          . ..+***********##
// CHECK: ###***************+.+++++++++++.....                         ....++**********###
// CHECK: ###******************+++++++++++++.....                      ...+++*********####
// CHECK: ####*********************++++++++++....                   ..  ..++*********#####
// CHECK: #####*************************+++++........ . .        . .......+*********######
// CHECK: #######***************************+++..........     .....+++++++*********#######
// CHECK: ########*****************************++++++....      ...++++++**********########
// CHECK: ##########*****************************+++++.....  ....++++***********##########
// CHECK: ###########******************************+++++........+++***********############
// CHECK: #############******************************++++.. ...++***********##############
// CHECK: ################****************************+++...+++***********################
// CHECK: ###################***************************+.+++**********###################
// CHECK: #######################**********************************#######################
// CHECK: ############################************************############################
// CHECK: ################################################################################


func getBurningShipIterations(c: Complex, maxIterations: Int) -> Int {
  var n = 0
  var z = Complex()
  while (n < maxIterations && z.magnitude() < 4.0) {
    var zTmp = Complex(real: z.real.abs(), imag: z.imag.abs())
    z = zTmp*zTmp + c
    n += 1
  }
  return n
}

print("\n== BURNING SHIP ==\n\n", terminator: "")

var burningShip = fractal(getBurningShipIterations)
burningShip(xMin: -2.0, xMax: 1.2, yMin: -2.1, yMax: 1.2, rows: 40, cols: 80,
            maxIterations: 200)

// CHECK: ################################################################################
// CHECK: ################################################################################
// CHECK: ################################################################################
// CHECK: #####################################################################*****######
// CHECK: ################################################################*******+...+*###
// CHECK: #############################################################**********+...****#
// CHECK: ###########################################################************. .+****#
// CHECK: #########################################################***********++....+.****
// CHECK: ######################################################************+++......++***
// CHECK: ##############################*******************###************..... .....+++++
// CHECK: ########################*******+++*******************+ .+++++ . .     ........+*
// CHECK: ####################**********+.. .+++*******+.+++**+.                .....+.+**
// CHECK: #################**********++++...+...++ ..   . . .+                ...+++++.***
// CHECK: ##############***********++.....  . ... .                         ...++++++****#
// CHECK: ############*************.......  . .                            ...+++********#
// CHECK: ##########***************.  ..                                  ...+++*********#
// CHECK: #########***************++. ..  . .                            ...+++*********##
// CHECK: #######*****************. ...                                 ...+++**********##
// CHECK: ######*****************+.                                    ...+++**********###
// CHECK: #####****************+++ .                                 .....++***********###
// CHECK: #####**********++..... .                                   ....+++***********###
// CHECK: ####*********+++.. .                                      ....+++***********####
// CHECK: ####********++++.                                         ....+++***********####
// CHECK: ###*******++++.                                           ...++++***********####
// CHECK: ###**++*+..+...                                           ...+++************####
// CHECK: ###                                                       ...+++************####
// CHECK: ###*********+++++++++.........     ......                   ..++************####
// CHECK: ####****************++++++....................               .++***********#####
// CHECK: #####********************++++++++++++++++........             .+***********#####
// CHECK: ########****************************+++++++++.......          ++***********#####
// CHECK: ###########*******************************++++++......      ..++**********######
// CHECK: ###############*******************************+++++.........++++*********#######
// CHECK: ####################****************************++++++++++++++**********########
// CHECK: ##########################*************************+++++++++***********#########
// CHECK: ################################**************************************##########
// CHECK: ####################################********************************############
// CHECK: ########################################***************************#############
// CHECK: ###########################################**********************###############
// CHECK: #############################################*****************##################
// CHECK: ################################################***********#####################
