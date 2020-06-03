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

import tables, streams
import utils

proc store*[T: SomeUnsignedInt](stream: Stream, value: T) =
  var cur = value
  for it in 0..<sizeof(value):
    stream.write(uint8(cur and 0xff))
    cur = cur shr 8

proc store*[T: int16](stream: Stream, value: T) =
  stream.store(cast[uint16](value))

proc store*[T: int32](stream: Stream, value: T) =
  stream.store(cast[uint32](value))

proc store*[T: int64](stream: Stream, value: T) =
  stream.store(cast[uint64](value))

proc store*(stream: Stream, value: float32) =
  stream.store(cast[uint32](value))

proc store*(stream: Stream, value: float64) =
  stream.store(cast[uint64](value))

proc store*(stream: Stream, value: uint8 | int8 | char) =
  stream.write(value)

proc store*(stream: Stream, value: bool) =
  if value:
    stream.write(uint8(1))
  else:
    stream.write(uint8(0))

proc store*(stream: Stream, str: string) =
  stream.store(str.len)
  for chr in str:
    stream.store(chr)

proc store*[K, V](stream: Stream, tab: Table[K, V]) =
  mixin store
  stream.store(tab.len)
  for key, value in tab:
    stream.store(key)
    stream.store(value)

proc store*[T](stream: Stream, items: seq[T]) =
  mixin store
  stream.store(items.len)
  for item in items:
    stream.store(item)

proc store*[N, T](stream: Stream, items: array[N, T]) =
  mixin store
  for item in items:
    stream.store(item)

proc store*(stream: Stream, value: Deg | Rad) =
  mixin store
  stream.store(value.float64)

proc store*[T](stream: Stream, vec: Vector2[T]) =
  mixin store
  stream.store(vec.x)
  stream.store(vec.y)

proc store*[T](stream: Stream, vec: Vector3[T]) =
  mixin store
  stream.store(vec.x)
  stream.store(vec.y)
  stream.store(vec.z)

proc store*[T](stream: Stream, vec: Vector4[T]) =
  mixin store
  stream.store(vec.x)
  stream.store(vec.y)
  stream.store(vec.z)
  stream.store(vec.w)

proc store*(stream: Stream, color: Color) =
  stream.store(color.r)
  stream.store(color.g)
  stream.store(color.b)
  stream.store(color.a)

proc store*(stream: Stream, loc: Location) =
  stream.store(loc.lat)
  stream.store(loc.lon)

proc load*[T: SomeInteger](stream: Stream, value: var T) =
  var cur: uint64 = 0
  for it in 0..<sizeof(value):
    cur = cur or (uint64(stream.read_uint8()) shl (8 * it))
  value = cast[T](cur)

proc load*(stream: Stream, value: var char) =
  value = stream.read_char()

proc load*(stream: Stream, value: var bool) =
  value = stream.read_uint8() != 0

proc load*(stream: Stream, str: var string) =
  var length = 0
  stream.load(length)
  str = new_string(length)
  for it in 0..<length:
    stream.load(str[it])

proc load*[T](stream: Stream, items: var seq[T]) =
  mixin store
  var length: int
  stream.load(length)
  items = new_seq[T](length)
  for it in 0..<length:
    stream.load(items[it])

proc load*[K, V](stream: Stream, items: var Table[K, V]) =
  mixin store
  var length: int
  stream.load(length)  
  items = init_table[K, V]()
  for it in 0..<length:
    var
      key: K
      value: V
    stream.load(key)
    stream.load(value)
    items[key] = value

proc load*(stream: Stream, value: var float64) =
  var x: uint64
  stream.load(x)
  value = cast[float64](x)

proc load*(stream: Stream, value: var float32) =
  var x: uint32
  stream.load(x)
  value = cast[float32](x)

proc load*[T: Deg | Rad](stream: Stream, value: var T) =
  var x: float64
  stream.load(x)
  value = T(x)

proc load*[T](stream: Stream, vec: var Vector2[T]) =
  mixin load
  stream.load(vec.x)
  stream.load(vec.y)

proc load*[T](stream: Stream, vec: var Vector3[T]) =
  mixin load
  stream.load(vec.x)
  stream.load(vec.y)
  stream.load(vec.z)

proc load*[T](stream: Stream, vec: var Vector4[T]) =
  mixin load
  stream.load(vec.x)
  stream.load(vec.y)
  stream.load(vec.z)
  stream.load(vec.w)

proc load*(stream: Stream, color: var Color) =
  stream.load(color.r)
  stream.load(color.g)
  stream.load(color.b)
  stream.load(color.a)

proc load*(stream: Stream, loc: var Location) =
  stream.load(loc.lat)
  stream.load(loc.lon)

proc load*[N, T](stream: Stream, items: var array[N, T]) =
  mixin load
  for it in 0..<items.len:
    stream.load(items[it])
