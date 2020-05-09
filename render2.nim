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

import strutils, sequtils, sugar, times
import tables, hashes, times, random
import sdl2 except Color, rgb, Event
import opengl
import utils, window, shader

const
  SOLID_VERT_SHADER_SOURCE = """
    #version 450 core
    
    in vec3 pos;
    in vec4 color;
    
    out vec4 p_color;
    
    uniform mat4 u_view_mat;
    
    void main() {
      p_color = color;
      gl_Position = u_view_mat * vec4(pos, 1);
    }
  """
  SOLID_FRAG_SHADER_SOURCE = """
    #version 450 core
    
    in vec4 p_color;
    out vec4 color;
    
    void main() {
      color = p_color;
    }
  """

const
  ELLIPSE_VERT_SHADER_SOURCE = """
    #version 450 core
    
    in vec3 pos;
    in vec2 uv;
    in vec4 color;
    
    out vec4 p_color;
    out vec2 p_uv;
    
    uniform mat4 u_view_mat;
    
    void main() {
      p_color = color;
      p_uv = uv;
      gl_Position = u_view_mat * vec4(pos, 1);
    }
  """
  ELLIPSE_FRAG_SHADER_SOURCE = """
    #version 450 core
    
    in vec2 p_uv;
    in vec4 p_color;
    
    out vec4 color;
    
    void main() {
      if (length(p_uv) < 1) {
        color = p_color;
      } else {
        color = vec4(p_color.xyz, 0);
      }
    }
  """

type
  BatchKind = enum BatchSolid, BatchEllipse

  Batch = object
    max_size: int
    prog: ShaderProgram
    indices: seq[GLuint]
    verts: seq[GLfloat]
    
    attribs: GLuint
    buffer: GLuint
    elements: GLuint

  Render2* = object
    window: BaseWindow
    batches: array[BatchKind, Batch]
    prev_batch: BatchKind
    
    is_path: bool
    path_pos: Vec2
    path_start: Vec2
    
    fill*: Color
    stroke*: Color
    stroke_width*: float64
    
    stats*: Stats2
  
  Stats2* = object
    triangles*: int
    drawcalls*: int
    recent_fps*: array[32, float64]
    prev_time: Time
    
proc reset(stats: var Stats2) =
  stats.triangles = 0
  stats.drawcalls = 0

proc push_fps(stats: var Stats2, fps: float64) =
  for it in 1..<stats.recent_fps.len:
    stats.recent_fps[it - 1] = stats.recent_fps[it]
  stats.recent_fps[^1] = fps

proc fps*(stats: Stats2): float64 = stats.recent_fps[^1]
proc average_fps*(stats: Stats2): float64 =
  var sum: float64 = 0
  for fps in stats.recent_fps:
    sum += fps
  return sum / stats.recent_fps.len.float64

proc new_batch(prog: ShaderProgram, max_size: int): Batch =
  var
    attribs: GLuint
    buffer: GLuint
    elements: GLuint
  
  gl_gen_vertex_arrays(1, attribs.addr)
  gl_bind_vertex_array(attribs)
  
  gl_gen_buffers(1, buffer.addr)
  gl_bind_buffer(GL_ARRAY_BUFFER, buffer)
  gl_gen_buffers(1, elements.addr)
  gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, elements)
  
  prog.use()
  prog.config_attribs()
  
  return Batch(
    attribs: attribs,
    elements: elements,
    buffer: buffer,
    prog: prog,
    max_size: max_size
  )

proc clear(batch: var Batch) =
  batch.verts = @[]
  batch.indices = @[]

proc new_view_mat4(size: Index2): Mat4 =
  return Mat4(data: [
    float64 2 / size.x, 0, 0, -1,
    0, -2 / size.y, 0, 1,
    0, 0, 1, 0,
    0, 0, 0, 1
  ])

proc render(batch: var Batch, size: Index2, stats: var Stats2) =
  if batch.verts.len == 0:
    batch.clear()
    return
  
  gl_bind_vertex_array(batch.attribs)
  gl_bind_buffer(GL_ARRAY_BUFFER, batch.buffer)
  gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, batch.elements)

  gl_buffer_data(GL_ARRAY_BUFFER,
    sizeof(GLfloat) * batch.verts.len,
    batch.verts[0].addr,
    GL_DYNAMIC_DRAW
  )
  
  gl_buffer_data(GL_ELEMENT_ARRAY_BUFFER,
    sizeof(GLint) * batch.indices.len,
    batch.indices[0].addr,
    GL_DYNAMIC_DRAW
  )
    
  batch.prog.use()
  batch.prog.uniform("u_view_mat", new_view_mat4(size))
  
  gl_draw_elements(GL_TRIANGLES, batch.indices.len.GLsizei, GL_UNSIGNED_INT, nil)
  
  stats.drawcalls += 1
  stats.triangles += batch.indices.len div 3
  
  batch.clear()
  
proc add(batch: var Batch,
         verts: seq[GLfloat],
         indices: seq[GLuint]) =
  let idx = batch.verts.len div batch.prog.vert_count()
  batch.verts &= verts
  for index in indices:
    batch.indices.add(index + GLuint(idx))

proc new_render2*(window: BaseWindow): Render2 =
  let 
    prog_solid = link_program([
      compile_shader(ShaderVertex, SOLID_VERT_SHADER_SOURCE),
      compile_shader(ShaderFragment, SOLID_FRAG_SHADER_SOURCE)
    ], @[
      Attribute(name: "pos", kind: AttribFloat, count: 3),
      Attribute(name: "color", kind: AttribFloat, count: 4)
    ])
    
    prog_ellipse = link_program([
      compile_shader(ShaderVertex, ELLIPSE_VERT_SHADER_SOURCE),
      compile_shader(ShaderFragment, ELLIPSE_FRAG_SHADER_SOURCE)
    ], @[
      Attribute(name: "pos", kind: AttribFloat, count: 3),
      Attribute(name: "uv", kind: AttribFloat, count: 2),
      Attribute(name: "color", kind: AttribFloat, count: 4)
    ])
  
  gl_enable(GL_BLEND)
  gl_blend_func(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  
  return Render2(
    window: window,
    fill: grey(0),
    stroke: grey(0),
    stroke_width: 1,
    batches: [
      new_batch(prog_solid, 1024),
      new_batch(prog_ellipse, 1024)
    ]
  )

proc add(ren: var Render2, 
         batch_kind: BatchKind,
         verts: seq[GLfloat],
         indices: seq[GLuint]) =
  if ren.prev_batch != batch_kind:
    ren.batches[ren.prev_batch].render(ren.window.size, ren.stats)
    ren.prev_batch = batch_kind
  ren.batches[batch_kind].add(verts, indices) 

proc background*(ren: var Render2, color: Color) =
  for batch in ren.batches.mitems:
    batch.clear()
  gl_clear_color(color.r.GLfloat, color.g.GLfloat, color.b.GLfloat, color.a.GLfloat)
  gl_clear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

proc add(verts: var seq[GLfloat], vec: Vec2) =
  verts.add(GLfloat(vec.x))
  verts.add(GLfloat(vec.y))

proc add(verts: var seq[GLfloat], vec: Vec3) =
  verts.add(GLfloat(vec.x))
  verts.add(GLfloat(vec.y))
  verts.add(GLfloat(vec.z))

proc add(verts: var seq[GLfloat], color: Color) =
  verts.add(GLfloat(color.r))
  verts.add(GLfloat(color.g))
  verts.add(GLfloat(color.b))
  verts.add(GLfloat(color.a))

proc ellipse_corner*(ren: var Render2, pos, size: Vec2) =
  var verts: seq[GLfloat] = @[]
  verts.add(new_vec3(pos, 0))
  verts.add(Vec2(x: -1, y: -1))
  verts.add(ren.fill)
  verts.add(new_vec3(pos + Vec2(x: size.x), 0))
  verts.add(Vec2(x: 1, y: -1))
  verts.add(ren.fill)
  verts.add(new_vec3(pos + Vec2(y: size.y), 0))
  verts.add(Vec2(x: -1, y: 1))
  verts.add(ren.fill)
  verts.add(new_vec3(pos + size, 0))
  verts.add(Vec2(x: 1, y: 1))
  verts.add(ren.fill)
  ren.add(BatchEllipse, verts, @[
    GLuint 0, 1, 3,
    2, 0, 3
  ])

proc rect*(ren: var Render2, pos, size: Vec2) =
  var verts: seq[GLfloat] = @[]
  verts.add(new_vec3(pos, 0))
  verts.add(ren.fill)
  verts.add(new_vec3(pos + Vec2(x: size.x), 0))
  verts.add(ren.fill)
  verts.add(new_vec3(pos + Vec2(y: size.y), 0))
  verts.add(ren.fill)
  verts.add(new_vec3(pos + size, 0))
  verts.add(ren.fill)
  ren.add(BatchSolid, verts, @[
    GLuint 0, 1, 3,
    2, 0, 3
  ])

proc rect*(ren: var Render2, pos, size, radius: Vec2) =
  var verts: seq[GLfloat] = @[]

  block rects:
    for pos in [# Center
                pos + Vec2(y: radius.y),
                pos + Vec2(x: size.x) + Vec2(y: radius.y),
                pos + Vec2(y: size.y) - Vec2(y: radius.y),
                pos + size - Vec2(y: radius.y),
                # Top
                pos + Vec2(x: radius.x),
                pos + Vec2(x: size.x) - Vec2(x: radius.x),
                pos + radius,
                pos + Vec2(x: size.x) + Vec2(y: radius.y, x: -radius.x),
                # Bottom
                pos + Vec2(y: size.y) - Vec2(y: radius.y, x: -radius.x),
                pos + size - radius,
                pos + Vec2(y: size.y) - Vec2(x: -radius.x),
                pos + size - Vec2(x: radius.x)]:
      verts.add(new_vec3(pos, 0))
      verts.add(Vec2())
      verts.add(ren.fill)

  block corners:
    for (pos, uv) in [# Top left
                      (pos, Vec2(x: -1, y: -1)),
                      (pos + Vec2(x: radius.x), Vec2(y: -1)),
                      (pos + Vec2(y: radius.y), Vec2(x: -1)),
                      (pos + radius, Vec2()),
                      # Top Right
                      (pos + Vec2(x: size.x - radius.x), Vec2(y: -1)),
                      (pos + Vec2(x: size.x), Vec2(y: -1, x: 1)),
                      (pos + Vec2(x: size.x - radius.x, y: radius.y), Vec2()),
                      (pos + Vec2(x: size.x, y: radius.y), Vec2(x: 1)),
                      # Bottom 
                      (pos + Vec2(y: size.y - radius.y), Vec2(x: -1)),
                      (pos + Vec2(x: radius.x, y: size.y - radius.y), Vec2()),
                      (pos + Vec2(y: size.y), Vec2(x: -1, y: 1)),
                      (pos + Vec2(x: radius.x, y: size.y), Vec2(y: 1)),
                      # Bottom Right
                      (pos + size - radius, Vec2()),
                      (pos + size - radius + Vec2(x: radius.x), Vec2(x: 1)),
                      (pos + size - radius + Vec2(y: radius.y), Vec2(y: 1)),
                      (pos + size - radius + radius, Vec2(x: 1, y: 1))]:
      verts.add(new_vec3(pos, 0))
      verts.add(uv)
      verts.add(ren.fill)

  var indices: seq[GLuint] = @[]
  for it in 0..<7:
    for idx in [0, 1, 3, 2, 0, 3]:
      indices.add(GLuint(idx + 4 * it))

  ren.add(BatchEllipse, verts, indices)

proc rot90(vec: Vec2): Vec2 =
  Vec2(x: -vec.y, y: vec.x)

proc line*(ren: var Render2, a, b: Vec2) =
  let offset = normalize(b - a).rot90() * ren.stroke_width / 2
  var verts: seq[GLfloat] = @[]
  
  for pos in [a + offset, b + offset, a - offset, b - offset]:
    verts.add(new_vec3(pos, 0))
    verts.add(ren.stroke)
  
  ren.add(BatchSolid, verts, @[GLuint 0, 1, 3, 2, 0, 3])

proc set_path_pos(ren: var Render2, pos: Vec2) =
  if not ren.is_path:
    ren.path_start = pos
    ren.is_path = true
  ren.path_pos = pos

proc move_to*(ren: var Render2, pos: Vec2) =
  ren.set_path_pos(pos)

proc line_to*(ren: var Render2, pos: Vec2) =
  ren.line(ren.path_pos, pos)
  ren.set_path_pos(pos)

proc end_path*(ren: var Render2, close: bool = false) =
  if close:
    ren.line(ren.path_start, ren.path_pos)
  ren.is_path = false

proc rect*(ren: var Render2, pos, size: Vec2, radius: float64) =
  ren.rect(pos, size, Vec2(x: radius, y: radius))

proc ellipse*(ren: var Render2, pos, size: Vec2) =
  ren.ellipse_corner(pos - size / 2, size)

proc circle*(ren: var Render2, pos: Vec2, radius: float64) =
  ren.ellipse(pos, Vec2(x: radius, y: radius))

proc render*(ren: var Render2, stats: var Stats2) =
  block:
    let
      time = get_time()
      dtime = in_microseconds(time - ren.stats.prev_time).int / 1_000_000
    ren.stats.push_fps(1 / dtime)
    ren.stats.prev_time = time
  
  for batch in ren.batches.mitems:
    batch.render(ren.window.size, ren.stats)
  
  stats = ren.stats
  ren.stats.reset()

proc render*(ren: var Render2) =
  var stats = Stats2()
  ren.render(stats)
