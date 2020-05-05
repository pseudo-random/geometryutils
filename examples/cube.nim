import ../utils, ../render3

let
  window = new_window("Cube", resizable=true)
  cube = new_cube_mesh(
    Vec3(x: -1, y: -1, z: -1),
    Vec3(x: 2, y: 2, z: 2)
  )

var
  cont = new_orbit_camera_controller()
  ren = new_render3(window)
  stats = Stats()
  is_running = true

while is_running:
  for event in window.poll():
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

  ren.render(stats)
  window.swap()

  echo stats.average_fps()
