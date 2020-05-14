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
import sdl2 except Color, rgb, Event
import opengl
import utils, shader, window

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

proc apply*(vert: var Vertex, mat: Mat4) =
  vert.pos = xyz(mat * new_vec4(vert.pos, 1))
  vert.normal = normalize(xyz(mat * new_vec4(vert.normal, 1)))

proc apply*(mesh: Mesh, mat: Mat4) =
  for it in low(mesh.verts)..high(mesh.verts):
    mesh.verts[it].apply(mat)

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

proc render_size(mesh: Mesh): GLsizei = GLSizei(mesh.tris.len * 3)
proc render_type(mesh: Mesh): GLenum = GL_TRIANGLES

type
  WireframeVertex* = object
    pos: Vec3

  Wireframe* = ref object
    verts*: seq[WireframeVertex]
    lines*: seq[array[2, int]]

proc to_wireframe*(mesh: Mesh): Wireframe =
  result = Wireframe()
  for vert in mesh.verts:
    result.verts.add(WireframeVertex(pos: vert.pos))
  
  for tri in mesh.tris:
    for it in 0..<3:
      let it2 = (it + 1) mod 3
      result.lines.add([tri[it], tri[it2]])

proc add_line*(wireframe: Wireframe, a, b: Vec3) =
  wireframe.verts.add(WireframeVertex(pos: a))
  wireframe.verts.add(WireframeVertex(pos: b))

  wireframe.lines.add([
    wireframe.verts.len - 2,
    wireframe.verts.len - 1
  ])

proc add_cube*(wireframe: Wireframe, pos, size: Vec3) =
  let idx = wireframe.verts.len
  for x in 0..1:  
    for y in 0..1:
      for z in 0..1:
        wireframe.verts.add(WireframeVertex(pos:
          pos + Vec3(x: x.float64, y: y.float64, z: z.float64) * size
        ))

  wireframe.lines &= [
    [0, 1], [2, 3], [4, 5], [6, 7],
    [0, 4], [2, 6], [1, 5], [3, 7],
    [0, 2], [4, 6], [5, 7], [1, 3]
  ]
  
proc new_cube_wireframe*(pos, size: Vec3): Wireframe =
  result = Wireframe()
  result.add_cube(pos, size)

proc vert_data(wireframe: Wireframe): seq[GLfloat] =
  for vertex in wireframe.verts:
    result.add(vertex.pos)

proc index_data(wireframe: Wireframe): seq[GLuint] =
  for line in wireframe.lines:
    for idx in line:
      result.add(idx.GLuint)

proc render_size(wireframe: Wireframe): GLsizei =
  GLSizei(wireframe.lines.len * 2)

proc render_type(wireframe: Wireframe): GLenum = GL_LINES

proc clear*(wireframe: Wireframe) =
  wireframe.verts = @[]
  wireframe.lines = @[]

proc clear*(mesh: Mesh) =
  mesh.verts = @[]
  mesh.tris = @[]

type
  RenderError* = ref object of Exception

  Instance* = object
    mat*: Mat4
    color*: Color

  Batch[T] = object
    render_obj: T
    
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
    window: BaseWindow
  
    shader_prog: ShaderProgram
    wireframe_shader_prog: ShaderProgram
    
    meshes: Table[Mesh, Batch[Mesh]]
    wireframes: Table[Wireframe, Batch[Wireframe]]
    
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

proc hash(mesh: Mesh): Hash = return !$ mesh[].addr.hash()
proc `==`(a, b: Mesh): bool = a[].addr == b[].addr

proc hash(wireframe: Wireframe): Hash = return !$ wireframe[].addr.hash()
proc `==`(a, b: Wireframe): bool = a[].addr == b[].addr

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

const
  WIREFRAME_VERTEX_SHADER_SOURCE = """
    #version 450 core
    
    in vec3 pos;
    
    out vec4 p_color;
    out vec3 p_world_pos;
    
    uniform mat4 u_camera_mat;
    uniform mat4 u_model_mat[128];
    uniform vec4 u_color[128];
    
    void main() {
      p_color = u_color[gl_InstanceID];
      vec4 world_pos = u_model_mat[gl_InstanceID] * vec4(pos, 1);
      p_world_pos = world_pos.xyz;
      gl_Position = u_camera_mat * world_pos;
    }
  """
  WIREFRAME_FRAGMENT_SHADER_SOURCE = """
    #version 450 core
  
    in vec4 p_color;
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
      color = p_color;
    }
  """

proc new_render3*(window: BaseWindow): Render3 =
  let
    shader_prog = link_program([
      compile_shader(ShaderVertex, VERTEX_SHADER_SOURCE),
      compile_shader(ShaderFragment, FRAGMENT_SHADER_SOURCE)
    ], @[
      Attribute(name: "pos", count: 3, kind: AttribFloat),
      Attribute(name: "normal", count: 3, kind: AttribFloat)
    ])
    wireframe_shader_prog = link_program([
      compile_shader(ShaderVertex, WIREFRAME_VERTEX_SHADER_SOURCE),
      compile_shader(ShaderFragment, WIREFRAME_FRAGMENT_SHADER_SOURCE)
    ], @[
      Attribute(name: "pos", count: 3, kind: AttribFloat)
    ])
  
  gl_enable(GL_DEPTH_TEST)
  gl_enable(GL_CULL_FACE)
  
  return Render3(
    window: window,
    shader_prog: shader_prog,
    wireframe_shader_prog: wireframe_shader_prog,
    camera: new_camera(),
    max_point_lights: 32,
    max_sun_lights: 1
  )

proc update[T](batch: Batch[T]) =
  var data = batch.render_obj.vert_data()
  if data.len == 0:
    return
  gl_bind_buffer(GL_ARRAY_BUFFER, batch.buffer)
  gl_buffer_data(GL_ARRAY_BUFFER,
    data.len * sizeof GLfloat, data[0].addr,
    GL_STATIC_DRAW
  )
  
  var elems = batch.render_obj.index_data()
  if elems.len == 0:
    return
  gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, batch.indices)
  gl_buffer_data(GL_ELEMENT_ARRAY_BUFFER,
    elems.len * sizeof GLuint, elems[0].addr,
    GL_STATIC_DRAW
  )

proc new_batch[T](render_obj: T, prog: ShaderProgram): Batch[T] =
  var
    attribs: GLuint
    buffer: GLuint
    indices: GLuint
  gl_gen_vertex_arrays(1, attribs.addr)
  gl_bind_vertex_array(attribs)

  gl_gen_buffers(1, buffer.addr)
  gl_gen_buffers(1, indices.addr)
  gl_bind_buffer(GL_ARRAY_BUFFER, buffer)
  gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, indices)

  prog.config_attribs()

  result = Batch[T](
    render_obj: render_obj,
    buffer: buffer,
    attribs: attribs,
    indices: indices,
    prog: prog,
    batch_size: 128
  )
  result.update()

proc add*(ren: var Render3, mesh: Mesh, inst: Instance) =
  if mesh notin ren.meshes:
    ren.meshes[mesh] = new_batch[Mesh](mesh, ren.shader_prog)

  ren.meshes[mesh].instances.add(inst)

proc add*(ren: var Render3, wireframe: Wireframe, inst: Instance) =
  if wireframe notin ren.wireframes:
    ren.wireframes[wireframe] = new_batch[Wireframe](wireframe, ren.wireframe_shader_prog)

  ren.wireframes[wireframe].instances.add(inst)

proc update*(ren: var Render3, wireframe: Wireframe) =
  if wireframe notin ren.wireframes:
    return
  ren.wireframes[wireframe].update()

proc update*(ren: var Render3, mesh: Mesh) =
  if mesh notin ren.meshes:
    return
  ren.meshes[mesh].update()

proc add*[T: Wireframe | Mesh](ren: var Render3,
                               render_obj: T,
                               pos: Vec3 = Vec3(),
                               rot: Quat = new_quat(),
                               scale: float64 = 1,
                               color: Color = grey(0.8)) =
  ren.add(render_obj, Instance(
    mat: new_translate_mat4(pos) * new_rotate_mat4(rot) * new_scale_mat4(scale),
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

proc render[T](ren: var Render3,
               batch: var Batch[T],
               stats: var Stats) =
  gl_bind_vertex_array(batch.attribs)
  batch.prog.use()
  
  gl_bind_buffer(GL_ARRAY_BUFFER, batch.buffer)
  gl_bind_buffer(GL_ELEMENT_ARRAY_BUFFER, batch.indices)

  for it, light in ren.point_lights:
    batch.prog.uniform("u_point_pos[" & $it & "]", light.pos)
    batch.prog.uniform("u_point_intensity[" & $it & "]", light.intensity)
  batch.prog.uniform("u_point_light_count", ren.point_lights.len.int)

  for it, light in ren.sun_lights:
    batch.prog.uniform("u_suns[" & $it & "]", light.direction)
  batch.prog.uniform("u_sun_light_count", ren.sun_lights.len.int)
  batch.prog.uniform("u_light_ratio", 0.2)
  
  batch.prog.uniform("u_ambient_light", ren.ambient_light)

  var it = 0
  while it < batch.instances.len:
    batch.prog.uniform("u_camera_mat",
      ren.camera.make_matrix(ren.window.size)
    )
    batch.prog.uniform("u_light_dir", Vec3(x: 0.5, y: 0.2, z: 1).normalize())

    var count = 0
    for it2 in 0..<min(batch.batch_size, batch.instances.len - it):
      let inst = batch.instances[it2 + it]
      batch.prog.uniform("u_color[" & $it2 & "]", inst.color)
      batch.prog.uniform("u_model_mat[" & $it2 & "]", inst.mat)
      count += 1
    
    gl_draw_elements_instanced(
      batch.render_obj.render_type(),
      batch.render_obj.render_size(),
      GL_UNSIGNED_INT, nil, GLsizei(count)
    )
    stats.triangles += batch.render_obj.render_size() div 3 * count
    stats.batches += 1
    stats.instances += count
    it += batch.batch_size
  
  batch.instances = @[]

proc render*(ren: var Render3,
             stats: var Stats) =
  stats.reset()
  
  block compute_fps:
    let
      cur_time = get_time()
      dtime = in_microseconds(cur_time - stats.ptime).int / 1_000_000
    stats.ptime = cur_time
    stats.push_fps(1 / dtime)
  
  for mesh, batch in ren.meshes:
    ren.render(ren.meshes[mesh], stats)
  
  for wireframe, batch in ren.wireframes:
    ren.render(ren.wireframes[wireframe], stats)
  
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
    button*: range[0..2]

proc new_orbit_camera_controller*(zoom: float64 = 10,
                                  rotation_speed: float64 = 0.5,
                                  zoom_speed: float64 = 1.2,
                                  button: range[0..2] = 0): OrbitCameraController =
  return OrbitCameraController(
    x: Deg(0),
    y: Deg(0),
    zoom: zoom,
    zoom_speed: zoom_speed,
    rotation_speed: rotation_speed,
    button: button
  )

proc process*(cont: var OrbitCameraController,
              evt: Event) =
  case evt.kind:
    of EventMove:
      if evt.buttons[cont.button]:
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

