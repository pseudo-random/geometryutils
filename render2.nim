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

import xmltree, strtabs, sequtils, strutils
import utils

type
  Align* = enum
    AlignStart, AlignMiddle, AlignEnd

  PathKind = enum
    PathMove, PathLine, PathClose
    
  PathPoint = object
    case kind: PathKind:
      of PathMove:
        move: Vec2
      of PathLine:
        line: Vec2
      of PathClose: discard

  ShapeKind = enum
    ShapeRect, ShapeCircle, ShapeLine, ShapeText, ShapePath

  Shape = object
    fill: Color
    stroke: Color
    stroke_width: float64
    case kind: ShapeKind:
      of ShapeRect:
        rect_pos: Vec2
        rect_size: Vec2
      of ShapeCircle:
        circle_pos: Vec2
        circle_radius: float64
      of ShapeLine:
        line_a: Vec2
        line_b: Vec2
      of ShapeText:
        text: string
        text_pos: Vec2
        text_x_align: Align
        text_y_align: Align
        font_size: float64
        font_family: string
      of ShapePath:
        path: seq[PathPoint]

  VectorRender2* = object
    size*: Index2
    shapes: seq[Shape]
 
    stroke*: Color
    stroke_width*: float64
    fill*: Color
    
    font_size*: float64
    font_family*: string
    
    path: seq[PathPoint]

proc new_vector_render2*(size: Index2): VectorRender2 =
  VectorRender2(
    size: size,
    stroke: rgb(0, 0, 0),
    stroke_width: 1,
    fill: rgb(0, 0, 0),
    font_size: 12,
    font_family: "sans-serif"
  )

proc add_style(shape: Shape, ren: VectorRender2): Shape =
  result = shape
  result.fill = ren.fill
  result.stroke = ren.stroke
  result.stroke_width = ren.stroke_width

proc background*(ren: var VectorRender2, color: Color) =
  ren.shapes.add(Shape(kind: ShapeRect,
    rect_size: Vec2(x: ren.size.x.float64, y: ren.size.y.float64),
    fill: color
  ))

proc rect*(ren: var VectorRender2, pos, size: Vec2) =
  ren.shapes.add(Shape(kind: ShapeRect,
    rect_pos: pos, rect_size: size
  ).add_style(ren))

proc circle*(ren: var VectorRender2, pos: Vec2, radius: float64) =
  ren.shapes.add(Shape(kind: ShapeCircle,
    circle_pos: pos, circle_radius: radius
  ).add_style(ren))

proc line*(ren: var VectorRender2, a, b: Vec2) =
  ren.shapes.add(Shape(kind: ShapeLine,
    line_a: a, line_b: b
  ).add_style(ren))

proc text*(ren: var VectorRender2,
           pos: Vec2,
           text: string,
           x_align: Align = AlignStart,
           y_align: Align = AlignEnd) =
  ren.shapes.add(Shape(kind: ShapeText,
    text_pos: pos, text: text,
    font_size: ren.font_size,
    font_family: ren.font_family,
    text_x_align: x_align, text_y_align: y_align,
  ).add_style(ren))

proc move_to*(ren: var VectorRender2, pos: Vec2) =
  ren.path.add(PathPoint(kind: PathMove, move: pos))

proc line_to*(ren: var VectorRender2, pos: Vec2) =
  ren.path.add(PathPoint(kind: PathLine, line: pos))

proc end_path*(ren: var VectorRender2, close: bool = false) =
  if close:
    ren.path.add(PathPoint(kind: PathClose))
  ren.shapes.add(Shape(kind: ShapePath, path: ren.path).add_style(ren))
  ren.path = @[]

proc to_svg*(color: Color): string =
  if color.a == 0:
    return "none"
  elif color.a == 1:
    result &= "rgb("
    result &= $(color.r * 100) & "%, "
    result &= $(color.g * 100) & "%, "
    result &= $(color.b * 100) & "%"
    result &= ")"
  else:
    result &= "rgba("
    result &= $(color.r * 100) & "%, "
    result &= $(color.g * 100) & "%, "
    result &= $(color.b * 100) & "%, "
    result &= $(color.a * 100) & "%"
    result &= ")"

proc add_style(node: XmlNode, shape: Shape): XmlNode =
  result = node
  result.attrs["stroke-width"] = $shape.stroke_width
  result.attrs["stroke"] = shape.stroke.to_svg()
  result.attrs["fill"] = shape.fill.to_svg()

proc to_text_anchor(align: Align): string =
  case align:
    of AlignStart: "start"
    of AlignMiddle: "middle"
    of AlignEnd: "end"

proc to_text_baseline(align: Align): string =
  case align:
    of AlignStart: "alphabetic"
    of AlignMiddle: "middle"
    of AlignEnd: "hanging"

proc to_svg(point: PathPoint): string =
  case point.kind:
    of PathMove:
      return "M" & $point.move.x & " " & $point.move.y
    of PathLine:
      return "L" & $point.line.x & " " & $point.line.y
    of PathClose:
      return "Z"

proc to_svg*(shape: Shape): XmlNode =
  case shape.kind:
    of ShapeCircle:
      return new_xml_tree("circle", [], to_xml_attributes({
        "cx": $shape.circle_pos.x,
        "cy": $shape.circle_pos.y,
        "r": $shape.circle_radius,
      })).add_style(shape)
    of ShapeRect:
      return new_xml_tree("rect", [], to_xml_attributes({
        "x": $shape.rect_pos.x,
        "y": $shape.rect_pos.y,
        "width": $shape.rect_size.x,
        "height": $shape.rect_size.y,
      })).add_style(shape)
    of ShapeLine:
      return new_xml_tree("line", [], to_xml_attributes({
        "x1": $shape.line_a.x,
        "y1": $shape.line_a.y,
        "x2": $shape.line_b.x,
        "y2": $shape.line_b.y,
      })).add_style(shape)
    of ShapeText:
      return new_xml_tree("text", [new_text(shape.text)], to_xml_attributes({
        "x": $shape.text_pos.x,
        "y": $shape.text_pos.y,
        "font-size": $shape.font_size,
        "font-family": shape.font_family,
        "text-anchor": shape.text_x_align.to_text_anchor(),
        "dominant-baseline": shape.text_y_align.to_text_baseline()
      })).add_style(shape)
    of ShapePath:
      return new_xml_tree("path", [], to_xml_attributes({
        "d": shape.path.map(to_svg).join(" ")
      })).add_style(shape)

proc to_svg*(ren: VectorRender2): XmlNode =
  new_xml_tree("svg", ren.shapes.map(to_svg), to_xml_attributes({
    "width": $ren.size.x,
    "height": $ren.size.y,
    "xmlns": "http://www.w3.org/2000/svg"
  }))
