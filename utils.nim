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

import math, hashes, random

type
  Deg* = distinct float64
  Rad* = distinct float64

template base_operations(T, B) =
  proc `-`*(a: T): T {.borrow.}

  proc `+`*(a, b: T): T {.borrow.}
  proc `-`*(a, b: T): T {.borrow.}
  proc `*`*(a, b: T): T {.borrow.}
  proc `/`*(a, b: T): T {.borrow.}
  
  proc `*`*(a: B, b: T): T {.borrow.}
  proc `*`*(a: T, b: B): T {.borrow.}

  proc `/`*(a: B, b: T): T {.borrow.}
  proc `/`*(a: T, b: B): T {.borrow.}

  proc `+=`*(a: var T, b: T) {.borrow.}
  proc `-=`*(a: var T, b: T) {.borrow.}
  proc `*=`*(a: var T, b: T) {.borrow.}
  proc `/=`*(a: var T, b: T) {.borrow.}
  
  proc `<`*(a, b: T): bool {.borrow.}
  proc `==`*(a, b: T): bool {.borrow.}
  proc `<=`*(a, b: T): bool {.borrow.}

  proc abs*(a: T): T {.borrow.}
  
  proc hash*(a: T): Hash {.borrow.}

base_operations(Deg, float64)
base_operations(Rad, float64)

proc `$`*(deg: Deg): string =
  $float64(deg) & "°"

proc `$`*(rad: Rad): string =
  $float64(rad) & "rad"

converter to_deg*(rad: Rad): Deg =
  Deg(rad.float64 / PI * 180)

converter to_rad*(deg: Deg): Rad =
  Rad(deg.float64 / 180 * PI)

proc sin*(x: Rad): float64 = sin(float64(x))
proc cos*(x: Rad): float64 = cos(float64(x))
proc tan*(x: Rad): float64 = tan(float64(x))
proc arcsin*(x: float64): Rad = Rad(math.arcsin(x))
proc arccos*(x: float64): Rad = Rad(math.arccos(x))

type
  Vector2*[T] = object
    x*: T
    y*: T

  Vec2* = Vector2[float64]
  Index2* = Vector2[int]

proc `+`*[T](a, b: Vector2[T]): Vector2[T] =
  Vector2[T](x: a.x + b.x, y: a.y + b.y)

proc `-`*[T](a, b: Vector2[T]): Vector2[T] =
  Vector2[T](x: a.x - b.x, y: a.y - b.y)

proc `*`*[T](a, b: Vector2[T]): Vector2[T] =
  Vector2[T](x: a.x * b.x, y: a.y * b.y)

proc `*`*[T](a: Vector2[T], b: T): Vector2[T] =
  Vector2[T](x: a.x * b, y: a.y * b)

proc `/`*[T](a, b: Vector2[T]): Vector2[T] =
  Vector2[T](x: a.x / b.x, y: a.y / b.y)

proc `/`*[T](a: Vector2[T], b: T): Vector2[T] =
  Vector2[T](x: a.x / b, y: a.y / b)

proc length*[T](vec: Vector2[T]): float64 =
  sqrt(float64(vec.x * vec.x + vec.y * vec.y))

proc normalize*[T](vec: Vector2[T]): Vec2 =
  let len = vec.length()
  return Vec2(x: vec.x.float64 / len, y: vec.y.float64 / len)

proc dist*[T](a, b: Vector2[T]): float64 =
  length(a - b)

proc dot*[T](a, b: Vector2[T]): T =
  return a.x * b.x + a.y * b.y

proc angle*[T](vec: Vector2[T]): Rad =
  Rad(arctan2(vec.y.float64, vec.x.float64))

proc min*[T](a, b: Vector2[T]): Vector2[T] =
  Vector2[T](x: min(a.x, b.x), y: min(a.y, b.y))

proc max*[T](a, b: Vector2[T]): Vector2[T] =
  Vector2[T](x: max(a.x, b.x), y: max(a.y, b.y))

proc floor*[T](vec: Vector2[T]): Vector2[T] =
  Vector2[T](x: vec.x.floor(), y: vec.y.floor())

proc ceil*[T](vec: Vector2[T]): Vector2[T] =
  Vector2[T](x: vec.x.ceil(), y: vec.y.ceil())

proc round*[T](vec: Vector2[T]): Vector2[T] =
  Vector2[T](x: vec.x.round(), y: vec.y.round())

proc `+=`*[T](a: var Vector2[T], b: Vector2[T]) =
  a.x += b.x
  a.y += b.y

proc `-=`*[T](a: var Vector2[T], b: Vector2[T]) =
  a.x -= b.x
  a.y -= b.y

proc `*=`*[T](a: var Vector2[T], b: Vector2[T]) =
  a.x *= b.x
  a.y *= b.y

proc `/=`*[T](a: var Vector2[T], b: Vector2[T]) =
  a.x /= b.x
  a.y /= b.y

proc hash*[T](vec: Vector2[T]): Hash =  
  return !$(vec.x.hash() !& vec.y.hash())

proc new_rand_vec2*(range: HSlice[float64, float64]): Vec2 =
  Vec2(
    x: rand(range),
    y: rand(range)
  )

proc to_vec2*(index2: Index2): Vec2 =
  Vec2(x: float64(index2.x), y: float64(index2.y))

proc to_index2*(vec: Vec2): Index2 =
  Index2(x: int(vec.x), y: int(vec.y))

type
  Vector3*[T] = object
    x*: T
    y*: T
    z*: T
  
  Vec3* = Vector3[float64]
  Index3* = Vector3[int]

proc `+`*[T](a, b: Vector3[T]): Vector3[T] =
  Vector3[T](x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)

proc `-`*[T](a, b: Vector3[T]): Vector3[T] =
  Vector3[T](x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)

proc `*`*[T](a, b: Vector3[T]): Vector3[T] =
  Vector3[T](x: a.x * b.x, y: a.y * b.y, z: a.z * b.z)

proc `/`*[T](a, b: Vector3[T]): Vector3[T] =
  Vector3[T](x: a.x / b.x, y: a.y / b.y, z: a.z / b.z)

proc `*`*[T](a: Vector3[T], b: T): Vector3[T] =
  Vector3[T](x: a.x * b, y: a.y * b, z: a.z * b)

proc `-`*[T](vec: Vector3[T]): Vector3[T] =
  Vector3[T](x: -vec.x, y: -vec.y, z: -vec.z)

proc length*[T](vec: Vector3[T]): float64 =
  sqrt(float64(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z))

proc normalize*[T](vec: Vector3[T]): Vec3 =
  let len = vec.length()
  return Vec3(x: vec.x.float64 / len, y: vec.y.float64 / len, z: vec.z.float64 / len)

proc dist*[T](a, b: Vector3[T]): float64 =
  length(b - a)

proc dot*[T](a, b: Vector3[T]): T =
  return a.x * b.x + a.y * b.y + a.z * b.z

proc cross*[T](a, b: Vector3[T]): Vector3[T] =
  return Vector3[T](
    x: a.y * b.z - a.z * b.y,
    y: a.z * b.x - a.x * b.z,
    z: a.x * b.y - a.y * b.x
  )

proc min*[T](a, b: Vector3[T]): Vector3[T] =
  Vector3[T](x: min(a.x, b.x), y: min(a.y, b.y), z: min(a.z, b.z))

proc max*[T](a, b: Vector3[T]): Vector3[T] =
  Vector3[T](x: max(a.x, b.x), y: max(a.y, b.y), z: max(a.z, b.z))

proc `+=`*[T](a: var Vector3[T], b: Vector3[T]) =
  a.x += b.x
  a.y += b.y
  a.z += b.z

proc `-=`*[T](a: var Vector3[T], b: Vector3[T]) =
  a.x -= b.x
  a.y -= b.y
  a.z -= b.z

proc `*=`*[T](a: var Vector3[T], b: Vector3[T]) =
  a.x *= b.x
  a.y *= b.y
  a.z *= b.z

proc `/=`*[T](a: var Vector3[T], b: Vector3[T]) =
  a.x /= b.x
  a.y /= b.y
  a.z /= b.z

proc hash*[T](vec: Vector3[T]): Hash =  
  return !$(vec.x.hash() !& vec.y.hash() !& vec.z.hash())

proc xy*[T](vec: Vector3[T]): Vector2[T] =
  return Vector2[T](x: vec.x, y: vec.y)

proc yz*[T](vec: Vector3[T]): Vector2[T] =
  return Vector2[T](x: vec.y, y: vec.z)

proc xz*[T](vec: Vector3[T]): Vector2[T] =
  return Vector2[T](x: vec.x, y: vec.z)

proc new_rand_vec3*(range: HSlice[float64, float64]): Vec3 =
  Vec3(
    x: rand(range),
    y: rand(range),
    z: rand(range)
  )

type
  Vector4*[T] = object
    x*: T
    y*: T
    z*: T
    w*: T
  
  Vec4* = Vector4[float64]
  Index4* = Vector4[int]

proc min*[T](a, b: Vector4[T]): Vector4[T] =
  Vector4[T](x: min(a.x, b.x), y: min(a.y, b.y), z: min(a.z, b.z), w: min(a.w, b.w))

proc max*[T](a, b: Vector4[T]): Vector4[T] =
  Vector4[T](x: max(a.x, b.x), y: max(a.y, b.y), z: max(a.z, b.z), w: max(a.w, b.w))

proc yzw*[T](vec: Vector4[T]): Vector3[T] =
  Vector3[T](x: vec.y, y: vec.z, z: vec.w)

proc xyz*[T](vec: Vector4[T]): Vector3[T] =
  Vector3[T](x: vec.x, y: vec.y, z: vec.z)

proc xy*[T](vec: Vector4[T]): Vector2[T] =
  Vector2[T](x: vec.x, y: vec.y)

proc yz*[T](vec: Vector4[T]): Vector2[T] =
  Vector2[T](x: vec.y, y: vec.z)

proc zw*[T](vec: Vector4[T]): Vector2[T] =
  Vector2[T](x: vec.z, y: vec.w)

proc new_vec4*(vec: Vec3, w: float64): Vec4 =
  Vec4(x: vec.x, y: vec.y, z: vec.z, w: w)

type
  Quat* = object
    r*: float64
    i*: float64
    j*: float64
    k*: float64

proc new_quat*(): Quat =
  Quat(r: 1, i: 0, j: 0, k: 0)

proc new_quat*(axis: Vec3, angle: Rad): Quat =
  Quat(
    r: cos(angle / 2), 
    i: axis.x * sin(angle / 2), 
    j: axis.y * sin(angle / 2), 
    k: axis.z * sin(angle / 2)
  )

proc length*(quat: Quat): float64 =
  return sqrt(quat.r * quat.r + quat.i * quat.i + quat.j * quat.j + quat.k * quat.k)

proc angle*(quat: Quat): Rad =
  arccos(quat.r) * 2

proc axis*(quat: Quat): Vec3 =
  let a = quat.angle()
  return Vec3(
    x: quat.i / sin(a / 2),
    y: quat.j / sin(a / 2),
    z: quat.k / sin(a / 2)
  )

proc `*`*(a, b: Quat): Quat =
  return Quat(
    r: a.r * b.r - a.i * b.i - a.j * b.j - a.k * b.k,
    i: a.r * b.i + a.i * b.r + a.j * b.k - a.k * b.j,
    j: a.r * b.j - a.i * b.k + a.j * b.r + a.k * b.i,
    k: a.r * b.k + a.i * b.j - a.j * b.i + a.k * b.r
  )

proc `*=`*(a: var Quat, b: Quat) =
  a = a * b

type
  Matrix4*[T] = object
    data*: array[16, T]

  Mat4* = Matrix4[float64]

proc `[]`*[T](mat: Matrix4[T], x, y: int): T =
  return mat.data[x + y * 4]

proc `[]=`*[T](mat: var Matrix4[T], x, y: int, value: T) =
  mat.data[x + y * 4] = value

proc `*`*[T](mat: Matrix4[T], vec: Vector4[T]): Vector4[T] =
  return Vector4[T](
    x: mat[0, 0] * vec.x + mat[1, 0] * vec.y + mat[2, 0] * vec.z + mat[3, 0] * vec.w,
    y: mat[0, 1] * vec.x + mat[1, 1] * vec.y + mat[2, 1] * vec.z + mat[3, 1] * vec.w,
    z: mat[0, 2] * vec.x + mat[1, 2] * vec.y + mat[2, 2] * vec.z + mat[3, 2] * vec.w,
    w: mat[0, 3] * vec.x + mat[1, 3] * vec.y + mat[2, 3] * vec.z + mat[3, 3] * vec.w
  )

proc `*`*[T](a, b: Matrix4[T]): Matrix4[T] =
  for x in 0..<4:
    for y in 0..<4:
      var sum = T(0)
      for it in 0..<4:
        sum += a[it, y] * b[x, it]
      result[x, y] = sum

proc new_identity_mat4*(): Mat4 =
  return Mat4(data: [
    float64 1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  ])

proc new_translate_mat4*(pos: Vec3): Mat4 =
  return Mat4(data: [
    float64 1, 0, 0, pos.x,
    0, 1, 0, pos.y,
    0, 0, 1, pos.z,
    0, 0, 0, 1
  ])

proc new_rotate_x_mat4*(angle: Rad): Mat4 =
  return Mat4(data: [
    float64 1, 0, 0, 0,
    0, cos(angle), -sin(angle), 0,
    0, sin(angle), cos(angle), 0,
    0, 0, 0, 1
  ])

proc new_rotate_y_mat4*(angle: Rad): Mat4 =
  return Mat4(data: [
    cos(angle), 0, sin(angle), 0,
    0, 1, 0, 0,
    -sin(angle), 0, cos(angle), 0,
    0, 0, 0, 1
  ])

proc new_rotate_z_mat4*(angle: Rad): Mat4 =
  return Mat4(data: [
    cos(angle), -sin(angle), 0, 0,
    sin(angle), cos(angle), 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  ])

proc rotate_x(vec: Vec3, angle: Rad): Vec3 =
  xyz(new_rotate_x_mat4(angle) * new_vec4(vec, 1))

proc rotate_y(vec: Vec3, angle: Rad): Vec3 =
  xyz(new_rotate_y_mat4(angle) * new_vec4(vec, 1))

proc rotate_z(vec: Vec3, angle: Rad): Vec3 =
  xyz(new_rotate_z_mat4(angle) * new_vec4(vec, 1))

proc new_rotate_mat4*(quat: Quat): Mat4 =
  return Mat4(data: [
    quat.r * quat.r + quat.i * quat.i - quat.j * quat.j - quat.k * quat.k,
    2 * quat.i * quat.j - 2 * quat.k * quat.r,
    2 * quat.i * quat.k + 2 * quat.j * quat.r,
    0,
    
    2 * quat.i * quat.j + 2 * quat.k * quat.r,
    quat.r * quat.r - quat.i * quat.i + quat.j * quat.j - quat.k * quat.k,
    2 * quat.j * quat.k - 2 * quat.i * quat.r,
    0,
    
    2 * quat.i * quat.k - 2 * quat.j * quat.r,
    2 * quat.j * quat.k + 2 * quat.i * quat.r,
    quat.r * quat.r - quat.i * quat.i - quat.j * quat.j + quat.k * quat.k,
    0,
    
    0, 0, 0, 1
  ])

proc new_perspective_mat4*(fov: Rad, aspect, near, far: float64): Mat4 =
  return Mat4(data: [
    1 / (aspect * tan(fov / 2)), 0, 0, 0,
    0, 1 / tan(fov / 2), 0, 0,
    0, 0, -(far + near) / (far - near), -1 * far * near / (far - near),
    0, 0, -1, 0
  ])


type
  Color* = object
    r*: float64
    g*: float64
    b*: float64
    a*: float64

proc rgba*(r, g, b, a: float64): Color = 
  Color(r: r, g: g, b: b, a: a)

proc rgba*(value: float64): Color = 
  Color(r: value, g: value, b: value, a: value)

proc rgb*(r, g, b: float64): Color = 
  Color(r: r, g: g, b: b, a: 1)

proc grey*(value: float64): Color = 
  Color(r: value, g: value, b: value, a: 1)
  
proc rgb*(hex: uint32): Color =
  result.r = uint8(hex shr 16).float64() / 255
  result.g = uint8(hex shr 8).float64() / 255
  result.b = uint8(hex).float64() / 255
  result.a = 1

proc rgba*(hex: uint32): Color =
  result.r = uint8(hex shr 24).float64() / 255
  result.g = uint8(hex shr 16).float64() / 255
  result.b = uint8(hex shr 8).float64() / 255
  result.a = uint8(hex).float64() / 255

proc hsv*(h, s, v: float64): Color = 
  quit "Not implemented"

proc `+`*(a, b: Color): Color =
  Color(r: a.r + b.r, g: a.g + b.g, b: a.b + b.b, a: a.a + b.a)

proc average*[T](data: openArray[T]): T =
  for item in data:
    result += item
  result /= T(data.len)

proc average*[T](data: openArray[Vector3[T]]): Vector3[T] =
  for item in data:
    result += item
  result /= Vector3[T](x: T(data.len), y: T(data.len), z: T(data.len))


type
  Segment*[T] = object
    a*: T
    b*: T

  Segment2*[T] = Segment[Vector2[T]]
  Seg2* = Segment2[float64]
  
  Segment3*[T] = Segment[Vector3[T]]
  Seg3* = Segment3[float64]

proc hash*[T](seg: Segment[T]): Hash =
  return !$(seg.a.hash() !& seg.b.hash())

type
  Location* = object
    lat*: Deg
    lon*: Deg

proc angle*(a, b: Location): Rad =
  arccos(
    sin(a.lat) * sin(b.lat) +
    cos(a.lat) * cos(b.lat) * cos(abs(a.lon - b.lon))
  )

const EARTH_RADIUS*: float64 = 6_371_000.0

proc dist*(a, b: Location,
           radius: float64 = EARTH_RADIUS): float64 =
  angle(a, b).float64 * radius

proc to_vector2*(loc: Location): Vector2[Deg] =
  Vector2[Deg](x: loc.lon, y: loc.lat)

proc to_vec3*(loc: Location,
              radius: float64 = EARTH_RADIUS): Vec3 =
  Vec3(x: radius).rotate_y(loc.lat).rotate_z(loc.lon)

proc project_plane*(loc, rel: Location,
                    radius: float64 = EARTH_RADIUS): Vec2 = 
  loc.to_vec3(radius).rotate_z(-rel.lon).rotate_y(-rel.lat).yz()

proc new_location*(lat, lon: Deg): Location =
  Location(lat: lat, lon: lon)

proc new_location*(lat, lon: float64): Location =
  Location(lat: Deg(lat), lon: Deg(lon))

type
  BoundingBox*[T] = object
    min*: T
    max*: T
  
  Box2* = BoundingBox[Vec2]
  Box3* = BoundingBox[Vec3]
  Inter* = BoundingBox[float64]

proc size*[T](box: BoundingBox[T]): T =
  box.max - box.min

proc center*[T](box: BoundingBox[T]): T =
  (box.min + box.max) / 2

proc new_bounding_box*[T](points: seq[T]): BoundingBox[T] =
  result.min = points[0]
  result.max = points[0]
  for point in points:
    result.min = min(result.min, point)
    result.max = max(result.max, point)

proc new_box2*(points: seq[Vec2]): Box2 = new_bounding_box[Vec2](points)
proc new_box3*(points: seq[Vec3]): Box3 = new_bounding_box[Vec3](points)

type
  Viewport*[S, T] = object
    box*: BoundingBox[S]
    size*: T
  
  Viewport2*[T] = Viewport[Vector2[T], Vector2[T]]
  Viewport3*[T] = Viewport[Vector3[T], Vector3[T]]
  
  View2* = Viewport2[float64]

proc map*[S, T](view: Viewport[S, T], pos: S): T =
  (pos - view.box.min) / (view.box.size) * view.size

proc map_reverse*[S, T](view: Viewport[S, T], pos: T): S =
  pos / view.size * view.box.size + view.box.min


