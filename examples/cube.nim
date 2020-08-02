import utils/[utils, window, render3]

let
  win = new_window("Cube", resizable=true)
  cube = new_cube_mesh(
    Vec3(x: -1, y: -1, z: -1),
    Vec3(x: 2, y: 2, z: 2)
  )

var
  cont = new_orbit_camera_controller()
  ren = new_render3(win)
  stats = Stats()
  is_running = true

while is_running:
  for event in win.poll():
    case event.kind:
      of EventQuit:
        is_running = false
        break
      of EventWheel, EventMove:
        cont.process(event)
      else: echo event
  
  cont.update(ren.camera)

  ren.background(grey(1))
  ren.add(cube)
  ren.add(Light(kind: LightSun,
    direction: Vec3(x: 1, y: 0.3, z: 0.5)
  ))
  ren.add(Light(kind: LightPoint,
    pos: Vec3(x: -3, y: -2, z: -4),
    intensity: 1
  ))
  ren.add(Light(kind: LightAmbient,
    ambient: 0.2
  ))
  ren.render(stats)
  win.swap()

  echo stats.average_fps()
