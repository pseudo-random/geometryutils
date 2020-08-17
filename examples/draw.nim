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
      of EventButtonDown:
        if event.button == 0:
          paths.add(@[])
      of EventMove:
        if not event.buttons[0]:
          continue
        paths[^1].add(event.pos.to_vec2())
      else: discard
  
  ren.background(grey(1))
  for path in paths:
    for it in 1..<path.len:
      ren.line(path[it - 1], path[it])
  ren.render(stats)
  win.swap()
  
  echo stats.triangles
  echo stats.average_fps()