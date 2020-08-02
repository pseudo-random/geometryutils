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

import opengl
import utils

type
  ShaderKind* = enum ShaderVertex, ShaderFragment
  Shader* = object
    kind: ShaderKind
    id: GLuint
  
  ShaderProgram* = object
    id: GLuint
    attribs: seq[Attribute]
  
  ShaderError* = ref object of Exception

  AttribKind* = enum AttribFloat, AttribInt
  Attribute* = object
    name*: string
    count*: int
    kind*: AttribKind

proc to_gl(kind: ShaderKind): GLenum =
  case kind:
    of ShaderVertex: return GL_VERTEX_SHADER
    of ShaderFragment: return GL_FRAGMENT_SHADER

proc compile_shader*(kind: ShaderKind, source: string): Shader =
  let id = gl_create_shader(kind.to_gl())
  var source_len = GLint(source.len)
  gl_shader_source(id, 1, alloc_c_string_array([source]), source_len.addr)
  gl_compile_shader(id)
  
  var info_log_len: GLint
  gl_get_shaderiv(id, GL_INFO_LOG_LENGTH, info_log_len.addr)
  if info_log_len > 0:
    var
      info_log = new_string(info_log_len)
      actual_len: GLint
    gl_get_shader_info_log(id, info_log_len, actual_len.addr, info_log.cstring)
    raise ShaderError(msg: info_log)
  
  return Shader(kind: kind, id: id)

proc link_program*(shaders: openArray[Shader], attribs: seq[Attribute]): ShaderProgram =
  let id = gl_create_program()
  for shader in shaders:
    gl_attach_shader(id, shader.id)
  
  gl_link_program(id)

  var info_log_len: GLint
  gl_get_programiv(id, GL_INFO_LOG_LENGTH, info_log_len.addr)
  if info_log_len > 0:
    var
      info_log = new_string(info_log_len)
      actual_len: GLint
    gl_get_program_info_log(id, info_log_len, actual_len.addr, info_log.cstring)
    raise ShaderError(msg: info_log)
  
  return ShaderProgram(id: id, attribs: attribs)

proc use*(prog: ShaderProgram) =
  gl_use_program(prog.id)

proc uniform*(prog: ShaderProgram, name: string, value: float64) =
  let loc = gl_get_uniform_location(prog.id, name.cstring)
  gl_uniform1f(loc, value.GLfloat)

proc uniform*(prog: ShaderProgram, name: string, value: int) =
  let loc = gl_get_uniform_location(prog.id, name.cstring)
  gl_uniform1i(loc, value.GLint)

proc uniform*(prog: ShaderProgram, name: string, value: Vec2) =
  let loc = gl_get_uniform_location(prog.id, name.cstring)
  gl_uniform2f(loc, value.x.GLfloat, value.y.GLfloat)

proc uniform*(prog: ShaderProgram, name: string, value: Vec3) =
  let loc = gl_get_uniform_location(prog.id, name.cstring)
  gl_uniform3f(loc, 
    value.x.GLfloat,
    value.y.GLfloat,
    value.z.GLfloat
  )

proc uniform*(prog: ShaderProgram, name: string, value: Vec4) =
  let loc = gl_get_uniform_location(prog.id, name.cstring)
  gl_uniform4f(loc,
    value.x.GLfloat,
    value.y.GLfloat,
    value.z.GLfloat,
    value.w.GLfloat
  )

proc uniform*(prog: ShaderProgram, name: string, value: Color) =
  let loc = gl_get_uniform_location(prog.id, name.cstring)
  gl_uniform4f(loc,
    value.r.GLfloat,
    value.g.GLfloat,
    value.b.GLfloat,
    value.a.GLfloat
  )

proc uniform*(prog: ShaderProgram, name: string, value: Mat4) =
  let loc = gl_get_uniform_location(prog.id, name.cstring)
  var data: array[16, GLfloat]
  for it, x in value.data:
    data[it] = GLfloat(x)
  gl_uniform_matrix4fv(loc, 1, true, data[0].addr)

proc size*(attrib: Attribute): int =
  case attrib.kind:
    of AttribFloat: return attrib.count * sizeof GLfloat
    of AttribInt: return attrib.count * sizeof GLint

proc to_gl(kind: AttribKind): GLenum =
  case kind:
    of AttribFloat: return cGL_FLOAT
    of AttribInt: return cGL_INT

proc config_attribs*(prog: ShaderProgram) =
  var stride = 0
  for attrib in prog.attribs:
    stride += attrib.size()
  
  var offset = 0
  for attrib in prog.attribs:
    let id = gl_get_attrib_location(prog.id, attrib.name.cstring)
    if id < 0:
      raise ShaderError(msg: "Could not find attribute: " & attrib.name)
    gl_enable_vertex_attrib_array(id.GLuint)
    gl_vertex_attrib_pointer(
      id.GLuint,
      GLint(attrib.count),
      attrib.kind.to_gl(),
      false,
      GLsizei(stride),
      cast[pointer](offset)
    )
    offset += attrib.size()

proc vert_count*(prog: ShaderProgram): int =
  for attrib in prog.attribs:
    result += attrib.count
