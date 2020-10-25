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

import tables, streams, macros
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
  stream.store(str.len.int64)
  for chr in str:
    stream.store(chr)

proc store*[K, V](stream: Stream, tab: Table[K, V]) =
  mixin store
  stream.store(tab.len.int64)
  for key in tab.keys:
    stream.store(key)
    stream.store(tab[key])

proc store*[T](stream: Stream, items: seq[T]) =
  mixin store
  stream.store(items.len.int64)
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

proc store*[T](stream: Stream, box: BoundingBox[T]) =
  mixin store
  stream.store(box.min)
  stream.store(box.max)

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
  var length: int64
  stream.load(length)
  str = new_string(int(length))
  for it in 0..<length:
    stream.load(str[it])

proc load*[T](stream: Stream, items: var seq[T]) =
  mixin load
  var length: int64
  stream.load(length)
  items = new_seq[T](int(length))
  for it in 0..<length:
    stream.load(items[it])

proc load*[K, V](stream: Stream, items: var Table[K, V]) =
  mixin load
  var length: int64
  stream.load(length)
  items = init_table[K, V]()
  for it in 0..<int(length):
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

proc load*[T](stream: Stream, box: var BoundingBox[T]) =
  mixin load
  stream.load(box.min)
  stream.load(box.max)

proc load*[N, T](stream: Stream, items: var array[N, T]) =
  mixin load
  for it in 0..<items.len:
    stream.load(items[it])

proc extract_name(node: NimNode): string =
  case node.kind:
    of nnkIdent: return node.str_val
    of nnkPostfix:
      if node[0].kind == nnkIdent and
         node[0].str_val == "*":
        return node[1].extract_name()
      else:
        error("Cannot extract name from " & $node.kind)
    else:
      error("Cannot extract name from " & $node.kind)

proc generate_load(node, stream, value: NimNode): NimNode =
  case node.kind:
    of nnkObjectTy:
      if node[1].kind == nnkOfInherit:
        error("Cannot generate load proc for objects with inheritance")
      return generate_load(node[2], stream, value)
    of nnkRecList:
      result = new_nim_node(nnkStmtList)
      for field in node:
        result.add(field.generate_load(stream, value))
    of nnkIdentDefs:
      return new_call("load", stream, new_dot_expr(
        value, ident(node[0].extract_name())
      ))
    of nnkSym:
      return new_call("load", stream, value)
    of nnkRefTy:
      let nil_sym = gen_sym(nskVar, "nil_sym")
      result = new_stmt_list(
        new_var_stmt(nil_sym, new_lit(false)),
        new_call("load", stream, nil_sym)
      )
      var if_cond = new_nim_node(nnkIfStmt)
      if_cond.add(new_nim_node(nnkElifBranch)
        .add(nil_sym)
        .add(new_stmt_list(
          new_assignment(value, new_nil_lit())
        )))
      if_cond.add(new_nim_node(nnkElse)
        .add(new_stmt_list(
          new_call("new", value),
          generate_load(node[0], stream, value)
        )))
      result.add(if_cond)
    else: error("Node kind not implemented " & $node.kind)

proc generate_store(node, stream, value: NimNode): NimNode =
  case node.kind:
    of nnkObjectTy:
      if node[1].kind == nnkOfInherit:
        error("Cannot generate store proc for objects with inheritance")
      return generate_store(node[2], stream, value)
    of nnkRecList:
      result = new_nim_node(nnkStmtList)
      for field in node:
        result.add(field.generate_store(stream, value))
    of nnkIdentDefs:
      return new_call("store", stream, new_dot_expr(
        value, ident(node[0].extract_name())
      ))
    of nnkSym:
      return new_call("store", stream, value)
    of nnkRefTy:
      result = new_nim_node(nnkIfStmt)
      result.add(new_nim_node(nnkElifBranch)
        .add(new_call("is_nil", value))
        .add(new_stmt_list(
          new_call("store", stream, new_lit(true))
        )))
      result.add(new_nim_node(nnkElse)
        .add(new_stmt_list(
          new_call("store", stream, new_lit(false)),
          generate_store(node[0], stream, value)
        )))
    else: error("Node kind not implemented " & $node.kind)

macro serializable*(typename: typed): untyped =
  let
    impl = typename.get_impl()
    load_stream = gen_sym(nskParam, "stream")
    load_value = gen_sym(nskParam, "value")
    store_stream = gen_sym(nskParam, "stream")
    store_value = gen_sym(nskParam, "value")
  
  result = new_stmt_list(
    new_proc(
      name=new_nim_node(nnkPostfix)
        .add(ident("*"))
        .add(ident("load")),
      params=[new_empty_node(),
        new_ident_defs(load_stream, bind_sym("Stream")),
        new_ident_defs(load_value, new_nim_node(nnkVarTy).add(typename))
      ],
      body=new_stmt_list(
        generate_load(impl[2], load_stream, load_value)
      )
    ),
    new_proc(
      name=new_nim_node(nnkPostfix)
        .add(ident("*"))
        .add(ident("store")),
      params=[new_empty_node(),
        new_ident_defs(store_stream, bind_sym("Stream")),
        new_ident_defs(store_value, typename)
      ],
      body=new_stmt_list(
        generate_store(impl[2], store_stream, store_value)
      )
    )
  )
