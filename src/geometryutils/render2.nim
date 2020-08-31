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
import tables, hashes, times, random, math
import sdl2 except Color, rgb, Event
import sdl2/ttf
import opengl
import utils, window, shader

type
  TextError* = ref object of Exception

  Font* = ref object
    size: int
    path: string
    font: FontPtr
    cache: Table[Color, Table[string, Texture]]
  
  Texture* = object
    id*: GLuint
    size*: Index2

proc hash(color: Color): Hash =
  result = color.r.hash()
  result = result !& color.g.hash()
  result = result !& color.b.hash()
  result = result !& color.a.hash()
  return !$ result

proc `==`*(a, b: Font): bool =
  a.path == b.path and a.size == b.size

proc load_font*(path: string, size: int): Font =
  if not ttf_was_init():
    echo "Initialize TTF"
    ttf.ttf_init()

  let font = open_font(path.cstring, size.cint)
  if font == nil:
    raise TextError(msg: "Could not load font\"" & path & "\" of size " & $size)
  return Font(font: font, size: size, path: path)

proc render_static*(font: Font,
                    text: string,
                    color: Color = grey(0)): Texture =
  if color in font.cache and
     text in font.cache[color]:
    return font.cache[color][text]

  if color notin font.cache:
    font.cache[color] = init_table[string, Texture]()
  
  var sdl_color: sdl2.Color
  sdl_color.r = uint8(color.r * 255)
  sdl_color.g = uint8(color.g * 255)
  sdl_color.b = uint8(color.b * 255)
  sdl_color.a = uint8(color.a * 255)
  
  let
    surf = render_text_blended(font.font, text.cstring, sdl_color)
    mode = GL_RGBA
  var id: GLuint
  gl_gen_textures(1, id.addr)
  gl_bind_texture(GL_TEXTURE_2D, id)
  gl_tex_image_2d(GL_TEXTURE_2D, 0, mode.GLint, surf.w, surf.h, 0, mode, GL_UNSIGNED_BYTE, surf.pixels)
  gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  gl_tex_parameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
  gl_bind_texture(GL_TEXTURE_2D, 0)
  
  result = Texture(id: id, size: Index2(x: surf.w.int, y: surf.h.int))
  font.cache[color][text] = result

const
  TEXTURE_VERT_SHADER_SOURCE = """
    #version 430 core
    
    in vec3 pos;
    in vec2 uv;
    in float id;
    
    out vec2 p_uv;
    out float p_id;
    
    uniform mat4 u_view_mat;

    void main() {
      p_id = id;
      p_uv = uv;
      gl_Position = u_view_mat * vec4(pos, 1);  
    }
  """
  
  TEXTURE_FRAG_SHADER_SOURCE = """
    #version 430 core
    
    in float p_id;
    in vec2 p_uv;
    
    out vec4 color;
    
    uniform sampler2D u_tex[32];
  
    void main() {
      color = texture(u_tex[int(p_id)], p_uv) + vec4(p_id) * 0.0001;
    }
  """

const
  SOLID_VERT_SHADER_SOURCE = """
    #version 430 core
    
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
    #version 430 core
    
    in vec4 p_color;
    out vec4 color;
    
    void main() {
      color = p_color;
    }
  """

const
  ELLIPSE_VERT_SHADER_SOURCE = """
    #version 430 core
    
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
    #version 430 core
    
    in vec2 p_uv;
    in vec4 p_color;
    
    out vec4 color;
    
    void main() {
      if (length(p_uv) < 1) {
        color = p_color;
      } else {
        discard;
      }
    }
  """

type
  BatchKind = enum BatchSolid, BatchEllipse, BatchTexture

  Batch = object
    max_size: int
    max_textures: int
    prog: ShaderProgram
    indices: seq[GLuint]
    verts: seq[GLfloat]
    textures: seq[Texture]
    
    attribs: GLuint
    buffer: GLuint
    elements: GLuint

  Render2* = object
    window: BaseWindow
    batches: array[BatchKind, Batch]
    prev_batch: BatchKind
    
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

proc new_batch(prog: ShaderProgram, max_size: int, max_textures: int = 0): Batch =
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
    max_size: max_size,
    max_textures: max_textures
  )

proc clear(batch: var Batch) =
  batch.verts = @[]
  batch.indices = @[]
  batch.textures = @[]

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
  
  for id, texture in batch.textures:
    gl_active_texture(GLenum(GL_TEXTURE0.int64 + id.int64))
    gl_bind_texture(GL_TEXTURE_2D, texture.id)
    batch.prog.uniform("u_tex[" & $id & "]", id)
  
  gl_draw_elements(GL_TRIANGLES, batch.indices.len.GLsizei, GL_UNSIGNED_INT, nil)
  
  stats.drawcalls += 1
  stats.triangles += batch.indices.len div 3
  
  batch.clear()
  

proc add(batch: var Batch,
         textures: seq[Texture],
         size: Index2,
         stats: var Stats2): seq[int] =
  if batch.textures.len + textures.len > batch.max_textures:
    batch.render(size, stats)
  for tex in textures:
    if tex in batch.textures:
      result.add(batch.textures.find(tex))
    else:
      result.add(batch.textures.len)
      batch.textures.add(tex)

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
    
    prog_texture = link_program([
      compile_shader(ShaderVertex, TEXTURE_VERT_SHADER_SOURCE),
      compile_shader(ShaderFragment, TEXTURE_FRAG_SHADER_SOURCE)
    ], @[
      Attribute(name: "pos", kind: AttribFloat, count: 3),
      Attribute(name: "uv", kind: AttribFloat, count: 2),
      Attribute(name: "id", kind: AttribFloat, count: 1)
    ])
  
  gl_enable(GL_BLEND)
  gl_blend_func(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  
  return Render2(
    window: window,
    batches: [
      new_batch(prog_solid, 1024),
      new_batch(prog_ellipse, 1024),
      new_batch(prog_texture, 1024, max_textures=32)
    ]
  )

proc flush*(ren: var Render2) =
  ren.batches[ren.prev_batch].render(ren.window.size, ren.stats)

proc add(ren: var Render2, 
         batch_kind: BatchKind,
         verts: seq[GLfloat],
         indices: seq[GLuint]) =
  if ren.prev_batch != batch_kind:
    ren.flush()
    ren.prev_batch = batch_kind
  ren.batches[batch_kind].add(verts, indices) 

proc add(ren: var Render2,
         batch_kind: BatchKind,
         textures: seq[Texture]): seq[int] =
  if ren.prev_batch != batch_kind:
    ren.flush()
    ren.prev_batch = batch_kind  
  return ren.batches[batch_kind].add(textures, ren.window.size, ren.stats)

proc background*(ren: var Render2, color: Color) =
  gl_disable(GL_STENCIL_TEST)
  gl_stencil_func(GL_ALWAYS, 0, 0)
  gl_clear(GL_STENCIL_BUFFER_BIT)
  for batch in ren.batches.mitems:
    batch.clear()
  gl_clear_color(color.r.GLfloat, color.g.GLfloat, color.b.GLfloat, color.a.GLfloat)
  gl_clear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

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

proc ellipse_corner*(ren: var Render2,
                     pos, size: Vec2,
                     color: Color = grey(0)) =
  var verts: seq[GLfloat] = @[]
  verts.add(new_vec3(pos, 0))
  verts.add(Vec2(x: -1, y: -1))
  verts.add(color)
  verts.add(new_vec3(pos + Vec2(x: size.x), 0))
  verts.add(Vec2(x: 1, y: -1))
  verts.add(color)
  verts.add(new_vec3(pos + Vec2(y: size.y), 0))
  verts.add(Vec2(x: -1, y: 1))
  verts.add(color)
  verts.add(new_vec3(pos + size, 0))
  verts.add(Vec2(x: 1, y: 1))
  verts.add(color)
  ren.add(BatchEllipse, verts, @[
    GLuint 0, 1, 3,
    2, 0, 3
  ])

proc rect*(ren: var Render2,
           pos, size: Vec2,
           color: Color = grey(0)) =
  var verts: seq[GLfloat] = @[]
  verts.add(new_vec3(pos, 0))
  verts.add(color)
  verts.add(new_vec3(pos + Vec2(x: size.x), 0))
  verts.add(color)
  verts.add(new_vec3(pos + Vec2(y: size.y), 0))
  verts.add(color)
  verts.add(new_vec3(pos + size, 0))
  verts.add(color)
  ren.add(BatchSolid, verts, @[
    GLuint 0, 1, 3,
    2, 0, 3
  ])

proc rect*(ren: var Render2,
           pos, size, radius: Vec2,
           color: Color = grey (0)) =
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
      verts.add(color)

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
      verts.add(color)

  var indices: seq[GLuint] = @[]
  for it in 0..<7:
    for idx in [0, 1, 3, 2, 0, 3]:
      indices.add(GLuint(idx + 4 * it))

  ren.add(BatchEllipse, verts, indices)

proc rot90(vec: Vec2): Vec2 =
  Vec2(x: -vec.y, y: vec.x)

proc line*(ren: var Render2,
           a, b: Vec2,
           color: Color = grey(0),
           width: float64 = 1) =
  let offset = normalize(b - a).rot90() * width / 2
  var verts: seq[GLfloat] = @[]
  
  for pos in [a + offset, b + offset, a - offset, b - offset]:
    verts.add(new_vec3(pos, 0))
    verts.add(color)
  
  ren.add(BatchSolid, verts, @[GLuint 0, 1, 3, 2, 0, 3])

proc path*(ren: var Render2,
           points: seq[Vec2],
           color: Color = grey(0),
           width: float64 = 1) =
  if points.len < 2:
    return
  var
    verts: seq[Glfloat]
    tris: seq[GLuint]
  
  block:
    let offset = normalize(points[1] - points[0]).rot90() * width / 2
    verts.add(new_vec3(points[0] + offset, 0))
    verts.add(color)
    verts.add(new_vec3(points[0] - offset, 0))
    verts.add(color)
  
  for it in 2..<points.len:
    let
      left = points[it - 2]
      center = points[it - 1]
      right = points[it]
      offset_a = normalize(center - left).rot90()
      offset_b = normalize(right - center).rot90()
    var
      offset = (offset_a + offset_b) / 2
      l = (width / 2) / (cos(math.arccos(dot(offset_a, offset_b)) / 2))
    if l > width * 2 or classify(l) == fcNaN or l <= 0:
      offset = offset_a
      l = width / 2
    offset = offset.normalize() * l
    
    verts.add(new_vec3(center + offset, 0))
    verts.add(color)
    verts.add(new_vec3(center - offset, 0))
    verts.add(color)
  
  block:
    let offset = normalize(points[^1] - points[^2]).rot90() * width / 2
    verts.add(new_vec3(points[^1] + offset, 0))
    verts.add(color)
    verts.add(new_vec3(points[^1] - offset, 0))
    verts.add(color)
  
  for it in 1..<points.len:
    let base = GLuint((it - 1) * 2)
    tris.add([base + 0, base + 1, base + 3])
    tris.add([base + 3, base + 2, base + 0])
  
  ren.add(BatchSolid, verts, tris)

proc rect*(ren: var Render2,
           pos, size: Vec2,
           radius: float64,
           color: Color = grey(0)) =
  ren.rect(pos, size, Vec2(x: radius, y: radius), color=color)

proc ellipse*(ren: var Render2,
              pos, size: Vec2,
              color: Color = grey(0)) =
  ren.ellipse_corner(pos - size, size * 2, color=color)

proc circle*(ren: var Render2,
             pos: Vec2,
             radius: float64,
             color: Color = grey(0)) =
  ren.ellipse(pos, Vec2(x: radius, y: radius), color=color)

proc begin_clip*(ren: var Render2) =
  ren.flush()
  gl_enable(GL_STENCIL_TEST)
  gl_stencil_mask(0xff)
  gl_stencil_func(GL_NEVER, 0, 0)
  gl_stencil_op(GL_INCR, GL_INCR, GL_INCR)

proc end_clip*(ren: var Render2) =
  ren.flush()
  gl_stencil_func(GL_NOTEQUAL, 0, 0xff)
  gl_stencil_op(GL_KEEP, GL_KEEP, GL_KEEP)

proc no_clip*(ren: var Render2) =
  ren.flush()
  gl_disable(GL_STENCIL_TEST)
  gl_stencil_func(GL_ALWAYS, 0, 0)
  gl_clear(GL_STENCIL_BUFFER_BIT)

proc add*(ren: var Render2, texture: Texture, pos: Vec2, size: Vec2) =
  let idx = ren.add(BatchTexture, @[texture])
  var verts: seq[GLfloat] = @[]
  for uv in [Vec2(), Vec2(x: 1), Vec2(y: 1), Vec2(x: 1, y: 1)]:
    verts.add(new_vec3(pos + size * uv, 0))
    verts.add(uv)
    verts.add(GLfloat(idx[0]))
  
  ren.add(BatchTexture, verts, @[GLuint 0, 1, 3, 2, 0, 3])

proc add*(ren: var Render2, texture: Texture, pos: Vec2) =
  ren.add(texture, pos, texture.size.to_vec2())

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
