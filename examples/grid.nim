import times
import geometryutils/[utils, window, render3]

proc new_grid_element(size: float64): Wireframe =
  result = Wireframe()
  for it in 0..int(size):
    let x = float64(it) - size / 2
    result.add_line(
      Vec3(x: x, z: -size / 2),
      Vec3(x: x, z: size / 2)
    )
  
    result.add_line(
      Vec3(z: x, x: -size / 2),
      Vec3(z: x, x: size / 2)
    )

let
  win = new_window("Grid", resizable=true)
  grid_element = new_grid_element(10)
  cube = new_cube_mesh(new_vec3(-1), new_vec3(2))
  cube_wireframe = cube.to_wireframe()
  start = get_time()

var
  ren = new_render3(win)
  cont = new_orbit_camera_controller()
  show_wireframe = false
  is_running = true

while is_running:
  for event in win.poll():
    case event.kind:
      of EventQuit:
        is_running = false
        break
      of EventWheel, EventMove:
        cont.process(event)
      of EventKeyDown:
        if event.keycode == ord('w'):
          show_wireframe = not show_wireframe
      else: discard
  
  let time = in_milliseconds(get_time() - start).int / 1000
  
  cont.update(ren.camera)
  ren.background(grey(1))
  ren.add(grid_element, color=grey(0.2))
  
  let
    color = rgb(0xff0000)
    rot = new_quat(Vec3(y: 1), Deg(90 * time))
  if show_wireframe:
    ren.add(cube_wireframe, rot=rot, color=color)
  else:
    ren.add(cube, rot=rot, color=color)
  
  ren.add(Light(kind: LightAmbient, ambient: 0.2))
  ren.add(Light(kind: LightSun,
    direction: Vec3(x: 1, y: 0.3, z: 0.8)
  ))
  ren.render()
  win.swap()
