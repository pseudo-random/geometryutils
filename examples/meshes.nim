import sequtils
import ../window, ../render3, ../utils

let
  win = new_window("Meshes")
  meshes = @[
    new_cube_mesh(
      Vec3(x: -1, y: -1, z: -1),
      Vec3(x: 2, y: 2, z: 2)
    ),
    new_sphere_mesh(),
    new_cylinder_mesh(),
    new_cone_mesh()
  ]
  wireframes = meshes.map(to_wireframe)

var
  ren = new_render3(win)
  cont = new_orbit_camera_controller()
  show_wireframes = false
  is_running = true

while is_running:
  for event in win.poll():
    case event.kind:
      of EventQuit:
        is_running = false
        break
      of EventKeyDown:
        case event.keycode:
          of ord('w'): show_wireframes = not show_wireframes
          else: discard
      else: cont.process(event)
  
  cont.update(ren.camera)
  
  ren.background(grey(1))
  if not show_wireframes:
    for it, mesh in meshes:
      ren.add(mesh, pos=Vec3(x: (it.float64 - (meshes.len - 1) / 2) * 3))
  else:
    for it, wireframe in wireframes:
      ren.add(wireframe,
        pos=Vec3(x: (it.float64 - (wireframes.len - 1) / 2) * 3),
        color=grey(0)
      )
  ren.add(Light(kind: LightSun,
    direction: normalize(Vec3(x: 1, y: 0.3, z: 0.5))
  ))
  ren.render()
  win.swap()
