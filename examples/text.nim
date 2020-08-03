import geometryutils/[utils, window, render2]

let
  win = new_window("Text")
  font = load_font("assets/font.ttf", 24)

var
  ren = new_render2(win)
  is_running = true

while is_running:
  for event in win.poll():
    case event.kind:
      of EventQuit:
        is_running = false
        break
      else:
        discard
  
  ren.background(grey(1))
  let tex = font.render_static("Hello, world")
  ren.add(tex, Vec2(x: 100, y: 100))
  
  ren.render()
  win.swap()
