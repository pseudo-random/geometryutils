import streams, tables
import utils/[utils, serialize]

type
  MyType = object
    a: int
    b: int

  Data = object
    tab: Table[string, seq[seq[int]]]
    vec: Vec2
    array_test: array[3, MyType]
    x: int32

proc store(stream: Stream, my_type: MyType) =
  stream.store(my_type.a)
  stream.store(my_type.b)

proc load(stream: Stream, my_type: var MyType) =
  stream.load(my_type.a)
  stream.load(my_type.b)

proc store(stream: Stream, data: Data) =
  stream.store(data.tab)
  stream.store(data.vec)
  stream.store(data.array_test)
  stream.store(data.x)

proc load(stream: Stream, data: var Data) =
  stream.load(data.tab)
  stream.load(data.vec)
  stream.load(data.array_test)
  stream.load(data.x)

block:
  let items = Data(
    tab: to_table({
      "abc": @[@[1, 2], @[3, 4, 5]],
      "123": @[]
    }),
    vec: Vec2(x: 0.1, y: 0.2),
    array_test: [
      MyType(a: -1, b: 0), MyType(a: 1, b: 2), MyType(b: -2)
    ],
    x: -10
  )
  let stream = new_file_stream("data.bin", fmWrite)
  stream.store(items)
  stream.close()

block:
  var data: Data
  let stream = new_file_stream("data.bin", fmRead)
  stream.load(data)
  stream.close()
  echo data
