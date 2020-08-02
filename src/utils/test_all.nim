# MIT License
# 
# Copyright (c) 2020 pseudo-random <josh.leh.2018@gmail.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import test, utils

block:
  let
    a = Vec2(x: 2, y: 1)
    b = Vec2(x: 1, y: 1)
    c = Vec2(x: 2, y: 3)
  
  test "Vec2":
    a + b == Vec2(x: 3, y: 2)
    a - b == Vec2(x: 1)
    a * c == Vec2(x: 4, y: 3)
    a / b == a
    angle(b).to_deg() == Deg(45)
    b.normalize().length().between(0.99, 1.01)
    dist(a, c) == 2

block:
  let
    a = Vec3(x: 1)
    b = Vec3(x: 1, y: 1, z: 1)
    c = Vec3(x: 2, y: 3, z: 4)

  test "Vec3":
    a + b == Vec3(x: 2, y: 1, z: 1)
    b - a == Vec3(y: 1, z: 1)
    b * c == c
    a * c == Vec3(x: 2)
    b.normalize().length().between(0.99, 1.01)
    a.normalize().length().between(0.99, 1.01)
    c.normalize().length().between(0.99, 1.01)
    c.xy == Vec2(x: 2, y: 3)
    c.yz == Vec2(x: 3, y: 4)
    c.xz == Vec2(x: 2, y: 4)
    a.rotate_z(Deg(90)).x.between(-0.001, 0.001)
    a.rotate_z(Deg(90)).y.between(0.999, 1.001)

block:
  let a = Box3(
    min: Vec3(x: -1, y: -1, z: -1),
    max: Vec3(x: 1, y: 1, z: 1)
  )
  
  test "Box3":
    a.center == Vec3()
    a.size == Vec3(x: 2, y: 2, z: 2)

block:
  let mat = Mat2(data: [float64 1, 2, 3, 4])
  
  test "Mat2":
    mat * mat.inverse() == new_identity_mat2()

block:
  let mat = Mat4(data: [
    float64 1, 2, 3, 4,
    5, 6, 7, 8,
    9, 10, 3, 12,
    13, 14, 15, 1
  ])
  
  test "Mat4":
    abs(sum(mat * mat.inverse() - new_identity_mat4())) < 0.0001

