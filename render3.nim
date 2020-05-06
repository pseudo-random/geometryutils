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

import strutils, sequtils, sugar
import tables, hashes, times, random
import sdl2 except Color, rgb
import opengl
import utils

type
  Vertex* = object
    pos*: Vec3
    normal*: Vec3

  Mesh* = ref object
    verts*: seq[Vertex]
    tris*: seq[array[3, int]]

proc load_obj*(source: string): Mesh =
  ## A procedure which is able to load simple .obj files.
  ## Currently not all features of the obj file format are
  ## implemented. All faces must be triangles
  
  result = Mesh()
  var
    verts: seq[Vec3] = @[]
    norms: seq[Vec3] = @[]

  for line in source.split('\n'):
    if line.len == 0 or line[0] == '#':
      continue
    let parts = line.split(' ')
    if parts.len < 1:
      continue
    case parts[0]:
      of "v":
        verts.add(Vec3(
          x: parts[1].parse_float(),
          y: parts[2].parse_float(),
          z: parts[3].parse_float()
        ))
      of "vn":
        norms.add(Vec3(
          x: parts[1].parse_float(),
          y: parts[2].parse_float(),
          z: parts[3].parse_float()
        ))
      of "f":
        var tri: array[3, int]
        for it, part in parts[1..^1]:
          let vals = part.split('/').map(parse_int)
          result.verts.add(Vertex(
            pos: verts[vals[0] - 1],
            normal: norms[vals[2] - 1]
          ))
          tri[it] = result.verts.len - 1
        result.tris.add(tri)
      else:  
        echo "Unknown command: " & line

proc add_quad*(mesh: Mesh, pos, a, b: Vec3) =
  ## Add a quad to a given mesh
  let
    normal = cross(a, b).normalize()
    idx = mesh.verts.len
  mesh.verts.add(Vertex(pos: pos, normal: normal))
  mesh.verts.add(Vertex(pos: pos + a, normal: normal))
  mesh.verts.add(Vertex(pos: pos + a + b, normal: normal))
  mesh.verts.add(Vertex(pos: pos + b, normal: normal))
  mesh.tris.add([idx, idx + 1, idx + 2])
  mesh.tris.add([idx, idx + 2, idx + 3])

proc add_cube*(mesh: Mesh, pos, size: Vec3) =  
  ## Add a cube with position `pos` and size `size` to the
  ## given mesh.
  mesh.add_quad(pos, Vec3(y: size.y), Vec3(x: size.x))
  mesh.add_quad(pos + Vec3(z: size.z), Vec3(x: size.x), Vec3(y: size.y))

  mesh.add_quad(pos, Vec3(x: size.x), Vec3(z: size.z))
  mesh.add_quad(pos + Vec3(y: size.y), Vec3(z: size.z), Vec3(x: size.x))

  mesh.add_quad(pos, Vec3(z: size.z), Vec3(y: size.y))
  mesh.add_quad(pos + Vec3(x: size.x), Vec3(y: size.y), Vec3(z: size.z))

proc new_cube_mesh*(pos, size: Vec3): Mesh =
  ## Creates a cube mesh
  result = Mesh()
  result.add_cube(pos, size)

proc add(data: var seq[GLfloat], vec: Vec3) =
  data.add(vec.x.GLfloat)
  data.add(vec.y.GLfloat)
  data.add(vec.z.GLfloat)

proc vert_data(mesh: Mesh): seq[GLfloat] =
  for vertex in mesh.verts:
    result.add(vertex.pos)
    result.add(vertex.normal)

proc index_data(mesh: Mesh): seq[GLuint] =
  for tri in mesh.tris:
    for idx in tri:
      result.add(idx.GLuint)

type
  ShaderKind* = enum ShaderVertex, ShaderFragment
  Shader* = object
    kind: ShaderKind
    id: GLuint
  
  ShaderProgram* = object
    id: GLuint
  
  ShaderError* = ref object of Exception

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

proc link_program*(shaders: openArray[Shader]): ShaderProgram =
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
  
  return ShaderProgram(id: id)

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

type
  AttribKind* = enum AttribFloat, AttribInt
  Attribute* = object
    name*: string
    count*: int
    kind*: AttribKind

proc size*(attrib: Attribute): int =
  case attrib.kind:
    of AttribFloat: return attrib.count * sizeof GLfloat
    of AttribInt: return attrib.count * sizeof GLint

proc to_gl(kind: AttribKind): GLenum =
  case kind:
    of AttribFloat: return cGL_FLOAT
    of AttribInt: return cGL_INT

proc config_attribs*(prog: ShaderProgram,
                     attribs: openArray[Attribute]) =
  var stride = 0
  for attrib in attribs:
    stride += attrib.size()
  
  var offset = 0
  for attrib in attribs:
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

type
  EventKind* = enum
    EventQuit, EventResize,
    EventButtonDown, EventButtonUp,
    EventMove, EventWheel,
    EventKeyDown, EventKeyUp

  Event* = object
    pos*: Index2
    buttons*: array[3, bool]
    case kind*: EventKind:
      of EventButtonDown, EventButtonUp:
        button*: int
      of EventMove:
        prev_pos*: Index2
      of EventResize:
        size*: Index2
      of EventKeyDown, EventKeyUp:
        keycode*: int
      of EventWheel:
        delta*: Index2
      else: discard

  Window* = ref object
    win: WindowPtr
    size*: Index2
    
    events: seq[Event]
    pos*: Index2
    buttons*: array[3, bool]
    

proc new_window*(title: string = "Window",
                 size: Index2 = Index2(x: 640, y: 480),
                 pos: Index2 = Index2(x: 100, y: 100),
                 resizable: bool = false): Window =
  ## Creates a new window. Note that using multiple windows
  ## is currently not supported.
  
  if sdl2.was_init(INIT_EVERYTHING) != INIT_EVERYTHING:
    echo "Initializing..."
    discard sdl2.init(INIT_EVERYTHING)
    discard sdl2.gl_set_attribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4)
    discard sdl2.gl_set_attribute(SDL_GL_CONTEXT_MINOR_VERSION, 5)

  var flags = SDL_WINDOW_OPENGL
  if resizable:
    flags = flags or SDL_WINDOW_RESIZABLE
  
  let win = create_window(
    title.cstring,
    pos.x.cint, pos.y.cint,
    size.x.cint, size.y.cint, flags
  )
  discard win.gl_create_context()
  load_extensions()
  gl_clear_color(0, 0, 0, 1)
  return Window(win: win, size: size)

proc add_stateful(event: Event, window: Window): Event =
  result = event
  result.buttons = window.buttons
  result.pos = window.pos

proc add(window: Window, event: Event) =
  window.events.add(event.add_stateful(window))

proc poll*(window: Window): seq[Event] =
  var evt = sdl2.default_event
  while poll_event(evt):
    case evt.kind:
      of QuitEvent:
        window.add(Event(kind: EventQuit))
      of WindowEvent:
        let event = cast[WindowEventPtr](evt.addr)
        case event.event:
          of WindowEvent_Resized:
            window.size = Index2(x: event.data1.int, y: event.data2.int)
            gl_viewport(0, 0, window.size.x.cint, window.size.y.cint)
            window.add(Event(kind: EventResize, size: window.size))
          else:
            discard
      of KeyDown, KeyUp:
        let
          event = cast[KeyboardEventPtr](evt.addr)
          keycode = event.keysym.sym.int

        if evt.kind == KeyDown:
          window.add(Event(kind: EventKeyDown, keycode: keycode))
        else:
          window.add(Event(kind: EventKeyUp, keycode: keycode))
      of MouseMotion:
        let
          event = cast[MouseMotionEventPtr](evt.addr)
          prev_pos = window.pos
        window.pos = Index2(x: event.x.int, y: event.y.int)
        window.add(Event(kind: EventMove, prev_pos: prev_pos))
      of MouseButtonDown, MouseButtonUp:
        let
          event = cast[MouseButtonEventPtr](evt.addr)
          button = event.button.int - 1 
        if button >= 0 and button < window.buttons.len:
          window.buttons[button] = evt.kind == MouseButtonDown
        
        if evt.kind == MouseButtonDown:
          window.add(Event(kind: EventButtonDown, button: button))
        else:
          window.add(Event(kind: EventButtonUp, button: button))
      of MouseWheel:
        let event = cast[MouseWheelEventPtr](evt.addr)
        window.add(Event(kind: EventWheel, delta: Index2(
          x: event.x.int, y: event.y.int
        )))
      else:
        discard
  
  result = window.events
  window.events = @[]
  return

proc swap*(window: Window) =
  window.win.gl_swap_window()

type
  RenderError* = ref object of Exception

  Instance* = object
    mat*: Mat4
    color*: Color

  Buffer = object
    mesh: Mesh
    
    attribs: GLuint
    buffer: GLuint
    indices: GLuint
    
    prog: ShaderProgram
    batch_size: int
    instances: seq[Instance]

  Camera* = object
    mat*: Mat4
    fov*: Deg
    near*: float64
    far*: float64

  LightKind* = enum LightPoint, LightSun, LightAmbient
  Light* = object
    case kind*: LightKind:
      of LightPoint:
        pos*: Vec3
        intensity*: float64 
      of LightSun:
        direction*: Vec3 
      of LightAmbient:
        ambient*: float64

  Render3* = object
    window: Window
  
    shader_prog: ShaderProgram
    meshes: Table[Mesh, Buffer]
    
    camera*: Camera
    max_point_lights: int
    point_lights: seq[Light]
    max_sun_lights: int
    sun_lights: seq[Light]
    ambient_light: float64

  Stats* = object
    triangles*: int
    batches*: int
    instances*: int
    recent_fps*: array[32, float64]
    ptime: Time

proc reset*(stats: var Stats) =
  stats.triangles = 0
  stats.batches = 0
  stats.instances = 0

proc push_fps*(stats: var Stats, fps: float64) =
  for it in 1..<stats.recent_fps.len:
    stats.recent_fps[it - 1] = stats.recent_fps[it]
  stats.recent_fps[^1] = fps

proc fps*(stats: Stats): float64 = stats.recent_fps[^1]
proc average_fps*(stats: Stats): float64 =
  var sum: float64 = 0
  for measurement in stats.recent_fps:
    sum += measurement
  return sum / float64(stats.recent_fps.len)

proc hash(mesh: Mesh): Hash =
  return !$ mesh[].addr.hash()

proc `==`(a, b: Mesh): bool =
  a[].addr == b[].addr

proc make_matrix(camera: Camera, size: Index2): Mat4 =
  let perspective = new_perspective_mat4(
    camera.fov, size.x / size.y, camera.near, camera.far
  )
  return perspective * camera.mat

proc new_camera*(fov: Deg = Deg(35),
                 near: float64 = 0.1,
                 far: float64 = 200.0): Camera =
  return Camera(
    fov: fov,
    near: 0.1,
    far: 200.0,
    mat: new_identity_mat4()
  )

const
  # TODO: Load files at compile time
  VERTEX_SHADER_SOURCE = """
    #version 450 core
    
    in vec3 pos;
    in vec3 normal;
    
    out vec3 p_normal;
    out vec4 p_color;
    out vec3 p_world_pos;
    
    uniform mat4 u_camera_mat;
    uniform mat4 u_model_mat[128];
    uniform vec4 u_color[128];
    
    void main() {
      p_color = u_color[gl_InstanceID];
      p_normal = (u_model_mat[gl_InstanceID] * vec4(normal, 0)).xyz;
      vec4 world_pos = u_model_mat[gl_InstanceID] * vec4(pos, 1);
      p_world_pos = world_pos.xyz;
      gl_Position = u_camera_mat * world_pos;
    }
  """
  FRAGMENT_SHADER_SOURCE = """
    #version 450 core
  
    in vec4 p_color;
    in vec3 p_normal;
    in vec3 p_world_pos;
    
    out vec4 color;
    
    uniform vec4 u_color[128];
    
    uniform vec3 u_suns[1];
    uniform int u_sun_light_count;
    uniform vec3 u_point_pos[32];
    uniform float u_point_intensity[32];
    uniform int u_point_light_count;
    uniform float u_ambient_light;
    
    void main() {
      float intensity = u_ambient_light;
      if (u_sun_light_count > 0) {
        intensity += clamp(dot(normalize(p_normal), normalize(u_suns[0])), 0, 1);
      }
      
      for (int it = 0; it < u_point_light_count; it++) {
        vec3 dir = u_point_pos[it] - p_world_pos;
        float d = length(dir) * 0.3;
        float falloff = 3 / (d * d + 1);
        float alignment = clamp(
          dot(normalize(p_normal), normalize(dir)),
          0, 1
        );
        intensity += falloff * alignment * u_point_intensity[it];
      }
      
      color = p_color * clamp(intensity, 0, 1);
    }
  """

proc new_render3*(window: Window): Render3 =
  let shader_prog = link_program([
    compile_shader(ShaderVertex, VERTEX_SHADER_SOURCE),
    compile_shader(ShaderFragment, FRAGMENT_SHADER_SOURCE)
  ])
  
  gl_enable(GL_DEPTH_TEST)
  gl_enable(GL_CULL_FACE)
  
  return Render3(
    window: window,
    shader_prog: shader_prog,
    camera: new_camera(),
    max_point_lights: 32,
    max_sun_lights: 1
  )

proc new_buffer(mesh: Mesh, prog: ShaderProgram): Buffer =
  var
    attribs: GLuint
    buffer: GLuint
    indices: GLuint
  gl_gen_vertex_arrays(1, attribs.addr)
  gl_bind_vertex_array(attribs)

  gl_gen_buffers(1, buffer.addr)
  var data = mesh.vert_data()
  gl_bind_buffer(GL_ARRAY_BUFFER, buffer)
  gl_buffer_data(GL_ARRAY_BUFFER,
    data.len * sizeof GLfloat, data[0].addr,
    GL_STATIC_DRAW
  )
  
  gl_gen_buffers(1, indices.addr)
  var elems = mesh.index_data()
  gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, indices)
  gl_buffer_data(GL_ELEMENT_ARRAY_BUFFER,
    elems.len * sizeof GLuint, elems[0].addr,
    GL_STATIC_DRAW
  )

  prog.config_attribs([
    Attribute(name: "pos", count: 3, kind: AttribFloat),
    Attribute(name: "normal", count: 3, kind: AttribFloat)
  ])

  return Buffer(
    mesh: mesh,
    buffer: buffer,
    attribs: attribs,
    indices: indices,
    prog: prog,
    batch_size: 128
  )

proc add*(ren: var Render3, mesh: Mesh, inst: Instance) =
  if mesh notin ren.meshes:
    ren.meshes[mesh] = new_buffer(mesh, ren.shader_prog)

  ren.meshes[mesh].instances.add(inst)

proc add*(ren: var Render3,
          mesh: Mesh,
          pos: Vec3 = Vec3(),
          rot: Quat = new_quat(),
          color: Color = grey(0.8)) =
  ren.add(mesh, Instance(
    mat: new_translate_mat4(pos) * new_rotate_mat4(rot),
    color: color
  ))

proc add*(ren: var Render3,
          light: Light) =
  case light.kind:
    of LightSun:
      if ren.sun_lights.len >= ren.max_sun_lights:
        raise RenderError(msg: "Exceeded sun light limit")
      ren.sun_lights.add(light)
    of LightPoint:
      if ren.point_lights.len >= ren.max_point_lights:
        raise RenderError(msg: "Exceeded point light limit")
      ren.point_lights.add(light)
    of LightAmbient:
      ren.ambient_light = light.ambient

proc render*(ren: var Render3,
             stats: var Stats) =
  stats.reset()
  
  block compute_fps:
    let
      cur_time = get_time()
      dtime = in_microseconds(cur_time - stats.ptime).int / 1_000_000
    stats.ptime = cur_time
    stats.push_fps(1 / dtime)
  
  for mesh, buffer in ren.meshes:
    gl_bind_vertex_array(buffer.attribs)
    buffer.prog.use()
    
    gl_bind_buffer(GL_ARRAY_BUFFER, buffer.buffer)
    gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, buffer.indices)

    for it, light in ren.point_lights:
      buffer.prog.uniform("u_point_pos[" & $it & "]", light.pos)
      buffer.prog.uniform("u_point_intensity[" & $it & "]", light.intensity)
    buffer.prog.uniform("u_point_light_count", ren.point_lights.len.int)

    for it, light in ren.sun_lights:
      buffer.prog.uniform("u_suns[" & $it & "]", light.direction)
    buffer.prog.uniform("u_sun_light_count", ren.sun_lights.len.int)
    buffer.prog.uniform("u_light_ratio", 0.2)
    
    buffer.prog.uniform("u_ambient_light", ren.ambient_light)

    var it = 0
    while it < buffer.instances.len:
      buffer.prog.uniform("u_camera_mat",
        ren.camera.make_matrix(ren.window.size)
      )
      buffer.prog.uniform("u_light_dir", Vec3(x: 0.5, y: 0.2, z: 1).normalize())
  
      var count = 0
      for it2 in 0..<min(buffer.batch_size, buffer.instances.len - it):
        let inst = buffer.instances[it2 + it]
        buffer.prog.uniform("u_color[" & $it2 & "]", inst.color)
        buffer.prog.uniform("u_model_mat[" & $it2 & "]", inst.mat)
        count += 1
      
      gl_draw_elements_instanced(GL_TRIANGLES,
        GLsizei(mesh.tris.len * 3), GL_UNSIGNED_INT, nil, GLsizei(count)
      )
      stats.triangles += mesh.tris.len * count
      stats.batches += 1
      stats.instances += count
      it += buffer.batch_size
      
    ren.meshes[mesh].instances = @[]
  
  ren.point_lights = @[]
  ren.sun_lights = @[]
  ren.ambient_light = 0

proc render*(ren: var Render3) =
  var stats = Stats()
  render(ren, stats)

proc background*(render: Render3, color: Color) =
  gl_clear_color(color.r, color.g, color.b, color.a)
  gl_clear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

type
  OrbitCameraController = object
    y*: Deg
    x*: Deg
    zoom*: float64
    zoom_speed*: float64
    rotation_speed*: float64

proc new_orbit_camera_controller*(zoom: float64 = 10,
                                  rotation_speed: float64 = 0.5,
                                  zoom_speed: float64 = 1.2): OrbitCameraController =
  return OrbitCameraController(
    x: Deg(0),
    y: Deg(0),
    zoom: zoom,
    zoom_speed: zoom_speed,
    rotation_speed: rotation_speed
  )

proc process*(cont: var OrbitCameraController,
              evt: Event) =
  case evt.kind:
    of EventMove:
      if evt.buttons[0]:
        let delta = evt.pos - evt.prev_pos
        cont.y += Deg(delta.x) * cont.rotation_speed
        cont.x += Deg(delta.y) * cont.rotation_speed
    of EventWheel:
      if evt.delta.y < 0:
        cont.zoom *= cont.zoom_speed
      else:
        cont.zoom /= cont.zoom_speed
    else: discard

proc update*(cont: OrbitCameraController,
             camera: var Camera) =
  let
    translate = new_translate_mat4(Vec3(z: -cont.zoom))
    rot_y = new_rotate_y_mat4(cont.y)
    rot_x = new_rotate_x_mat4(cont.x)
  camera.mat = translate * rot_x * rot_y

type
  ModelCameraController* = object
    rot: Quat
    zoom: float64
    rotation_speed: float64
    zoom_speed: float64

proc new_model_camera_controller*(zoom: float64 = 10,
                                  rotation_speed: float64 = 0.5,
                                  zoom_speed: float64 = 1.2): ModelCameraController =
  return ModelCameraController(
    rot: new_quat(),
    zoom: zoom,
    zoom_speed: zoom_speed,
    rotation_speed: rotation_speed
  )

proc process*(cont: var ModelCameraController,
              evt: Event) =
  case evt.kind:
    of EventMove:
      if evt.buttons[0]:
        let delta = evt.pos - evt.prev_pos
        cont.rot = new_quat(Vec3(y: 1), Deg(delta.x) * cont.rotation_speed) * cont.rot
        cont.rot = new_quat(Vec3(x: 1), Deg(delta.y) * cont.rotation_speed) * cont.rot
    of EventWheel:
      if evt.delta.y < 0:
        cont.zoom *= cont.zoom_speed
      else:
        cont.zoom /= cont.zoom_speed
    else: discard

proc update*(cont: ModelCameraController,
             camera: var Camera) =
  let
    translate = new_translate_mat4(Vec3(z: -cont.zoom))
    rot = new_rotate_mat4(cont.rot)
  camera.mat = translate * rot

