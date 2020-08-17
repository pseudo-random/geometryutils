import geometryutils/[utils, window]
import opengl

const COLORS = [
  rgb(1, 0, 0),
  rgb(0, 1, 0),
  rgb(0, 0, 1)
]

var wins: seq[Window] = @[]
for it in 0..<COLORS.len:
  wins.add(new_window("Window " & $it, resizable=true))

var is_running = true
while is_running:
  var closed_windows: seq[int] = @[]
  
  for it, win in wins:
    for evt in win.poll():
      case evt.kind:
        of EventQuit:
          is_running = false
          break
        of EventClose:
          closed_windows.add(it)
        else:
          echo "Window " & $it & ": " & $evt
    
    if not is_running:
      break
    
    win.use()
    let col = COLORS[it]
    gl_clear_color(col.r.GLfloat, col.g.GLfloat, col.b.GLfloat, col.a.GLfloat)
    gl_clear(GL_COLOR_BUFFER_BIT)
    win.swap()
  
  if closed_windows.len > 0:
    for id in closed_windows:
      wins[id].close()
      wins.del(id)
    for it, win in wins:
      win.title = "Window " & $it

