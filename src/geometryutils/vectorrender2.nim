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

import xmltree, strtabs, sequtils, strutils, sugar, tables
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
    ShapeBackground, ShapeRect,
    ShapeEllipse,
    ShapeLine, ShapePath,
    ShapeText

  Shape = object
    fill: Color
    stroke: Color
    stroke_width: float64
    clip: Box2
    has_clip: bool
    case kind: ShapeKind:
      of ShapeRect:
        rect_pos: Vec2
        rect_size: Vec2
      of ShapeLine:
        line_a: Vec2
        line_b: Vec2
      of ShapeText:
        text: string
        text_pos: Vec2
        text_x_align: Align
        text_y_align: Align
        text_rotation: Deg
        font_size: float64
        font_family: string
      of ShapePath:
        path: seq[PathPoint]
      of ShapeEllipse:
        ellipse_pos: Vec2
        ellipse_size: Vec2
      of ShapeBackground: discard

  VectorRender2* = object
    size*: Index2
    shapes: seq[Shape]
    
    stroke*: Color
    stroke_width*: float64
    fill*: Color
    has_clip*: bool
    clip*: Box2
    
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
  if ren.has_clip:
    result.has_clip = true
    result.clip = ren.clip

proc background*(ren: var VectorRender2, color: Color) =
  ren.shapes.add(Shape(kind: ShapeBackground, fill: color))

proc rect*(ren: var VectorRender2, pos, size: Vec2) =
  ren.shapes.add(Shape(kind: ShapeRect,
    rect_pos: pos, rect_size: size
  ).add_style(ren))

proc circle*(ren: var VectorRender2, pos: Vec2, radius: float64) =
  ren.shapes.add(Shape(kind: ShapeEllipse,
    ellipse_pos: pos, ellipse_size: Vec2(x: radius, y: radius)
  ).add_style(ren))

proc ellipse*(ren: var VectorRender2, pos, size: Vec2) =
  ren.shapes.add(Shape(kind: ShapeEllipse,
    ellipse_pos: pos, ellipse_size: size
  ).add_style(ren))

proc line*(ren: var VectorRender2, a, b: Vec2) =
  ren.shapes.add(Shape(kind: ShapeLine,
    line_a: a, line_b: b
  ).add_style(ren))

proc text*(ren: var VectorRender2,
           pos: Vec2,
           text: string,
           x_align: Align = AlignStart,
           y_align: Align = AlignStart,
           rotation: Deg = Deg(0)) =
  ren.shapes.add(Shape(kind: ShapeText,
    text_pos: pos, text: text,
    font_size: ren.font_size,
    font_family: ren.font_family,
    text_x_align: x_align, text_y_align: y_align,
    text_rotation: rotation
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

proc clip_region*(ren: var VectorRender2, clip: Box2) =
  ren.clip = clip
  ren.has_clip = true

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

proc add_style(node: XmlNode,
               shape: Shape,
               defs: var seq[XmlNode],
               clips: var Table[Box2, string]): XmlNode =
  result = node
  result.attrs["stroke-width"] = $shape.stroke_width
  result.attrs["stroke"] = shape.stroke.to_svg()
  result.attrs["fill"] = shape.fill.to_svg()
  if shape.has_clip:
    if shape.clip notin clips:
      let name = "clip" & $clips.len
      defs.add(new_xml_tree("clipPath", [
        new_xml_tree("rect", [], to_xml_attributes({
          "x": $shape.clip.min.x,
          "y": $shape.clip.min.y,
          "width": $shape.clip.size.x,
          "height": $shape.clip.size.y
        }))
      ], to_xml_attributes({"id": name})))
      clips[shape.clip] = name
    result.attrs["clip-path"] = "url(#" & clips[shape.clip] & ")"

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

proc to_svg*(shape: Shape,
             size: Index2,
             defs: var seq[XmlNode],
             clips: var Table[Box2, string]): XmlNode =
  case shape.kind:
    of ShapeRect:
      return new_xml_tree("rect", [], to_xml_attributes({
        "x": $shape.rect_pos.x,
        "y": $shape.rect_pos.y,
        "width": $shape.rect_size.x,
        "height": $shape.rect_size.y,
      })).add_style(shape, defs, clips)
    of ShapeLine:
      return new_xml_tree("line", [], to_xml_attributes({
        "x1": $shape.line_a.x,
        "y1": $shape.line_a.y,
        "x2": $shape.line_b.x,
        "y2": $shape.line_b.y,
      })).add_style(shape, defs, clips)
    of ShapeText:
      var attrs = to_xml_attributes({
        "font-size": $shape.font_size,
        "font-family": shape.font_family,
        "text-anchor": shape.text_x_align.to_text_anchor(),
        "dominant-baseline": shape.text_y_align.to_text_baseline()
      })
      if shape.text_rotation != Deg(0):
        attrs["transform"] = "translate(" & $shape.text_pos.x & " " & $shape.text_pos.y & ") "
        attrs["transform"] &= "rotate(" & $float64(shape.text_rotation) & ")"
      else:
        attrs["x"] = $shape.text_pos.x
        attrs["y"] = $shape.text_pos.y
      return new_xml_tree("text", [new_text(shape.text)], attrs).add_style(shape, defs, clips)
    of ShapePath:
      return new_xml_tree("path", [], to_xml_attributes({
        "d": shape.path.map(to_svg).join(" ")
      })).add_style(shape, defs, clips)
    of ShapeBackground:
      return new_xml_tree("rect", [], to_xml_attributes({
        "x": "0", "y": "0",
        "width": $size.x, "height": $size.y,
      })).add_style(shape, defs, clips)
    of ShapeEllipse:
      return new_xml_tree("ellipse", [], to_xml_attributes({
        "cx": $shape.ellipse_pos.x,
        "cy": $shape.ellipse_pos.y,
        "rx": $shape.ellipse_size.x,
        "ry": $shape.ellipse_size.y
      })).add_style(shape, defs, clips)

proc to_svg*(ren: VectorRender2): XmlNode =
  var
    defs: seq[XmlNode] = @[]
    clips = init_table[Box2, string]()
    body: seq[XmlNode] = @[]
  for shape in ren.shapes:
    body.add(to_svg(shape, ren.size, defs, clips))
  if defs.len > 0:
    let defs_section = new_xml_tree("defs", defs)
    body = @[defs_section] & body
  
  return new_xml_tree("svg", body, to_xml_attributes({
    "width": $ren.size.x,
    "height": $ren.size.y,
    "xmlns": "http://www.w3.org/2000/svg"
  }))

proc render_to*[T](ren: VectorRender2, target: var T) =
  mixin background, line, ellipse, rect, path
  for shape in ren.shapes:
    case shape.kind:
      of ShapeBackground:
        target.background(shape.fill)
      of ShapeLine:
        if shape.stroke.a != 0:
          target.line(shape.line_a, shape.line_b,
            color=shape.stroke,
            width=shape.stroke_width
          )
      of ShapeEllipse:
        if shape.fill.a != 0:
          target.ellipse(shape.ellipse_pos, shape.ellipse_size, color=shape.fill)
      of ShapePath:
        var
          pos: Vec2
          start: Vec2
          is_start = true
          points: seq[Vec2]
        
        template set_pos(new_pos) =
          if is_start:
            start = new_pos
            is_start = false
          pos = new_pos
        
        for point in shape.path:
          case point.kind:
            of PathMove:
              if points.len > 0:
                target.path(points,
                  color=shape.stroke,
                  width=shape.stroke_width
                )
                points = @[]
              points.add(point.move)
              set_pos(point.move)
            of PathLine:
              points.add(point.line)
              set_pos(point.line)
            of PathClose:
              points.add(start)
        
        if points.len > 0:
          target.path(points,
            color=shape.stroke,
            width=shape.stroke_width
          )
          points = @[]
      of ShapeRect:
        if shape.fill.a != 0:
          target.rect(shape.rect_pos, shape.rect_size,
            color=shape.fill
          )
        if shape.stroke.a != 0:
          let positions = [
            shape.rect_pos,
            shape.rect_pos + Vec2(x: shape.rect_size.x),
            shape.rect_pos + shape.rect_size,
            shape.rect_pos + Vec2(y: shape.rect_size.y)
          ]
          for it in 0..<positions.len:
            let
              a = positions[it]
              b = positions[(it + 1) mod positions.len]
            target.line(a, b,
              color=shape.stroke,
              width=shape.stroke_width
            )
      else: discard
