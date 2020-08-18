import geometryutils/[utils, window, render2]

let win = new_window("Draw")

var
  ren = new_render2(win)
  is_running = true
  stats = Stats2()
  paths: seq[seq[Vec2]]

while is_running:
  for event in win.poll():
    case event.kind:
      of EventQuit:
        is_running = false
        break
      of EventKeyDown:
        case event.keycode:
          of ord('c'): paths = @[]
          else: discard
      of EventButtonDown:
        if event.button == 0:
          paths.add(@[])
      of EventMove:
        if not event.buttons[0]:
          continue
        if paths.len == 0:
          paths.add(@[])
        if paths[^1].len == 0 or
           paths[^1][^1].dist(event.pos.to_vec2()) > 10:
          paths[^1].add(event.pos.to_vec2())
      else: discard
  
  ren.background(grey(1))
  for path in paths:
    ren.path(path, width=10)
  ren.render(stats)
  win.swap()
  
  #echo stats.triangles
  echo paths.len
  echo stats.average_fps()