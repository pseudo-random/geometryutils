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

import tables
import sdl2 except Color, rgb
import opengl
import utils

type
  EventKind* = enum
    EventQuit,
    EventClose, EventResize,
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

  WindowError* = ref object of Exception

  BaseWindow* = ref object of RootObj
    size*: Index2
    pos*: Index2
    buttons*: array[3, bool]
  
  Window* = ref object of BaseWindow
    win: WindowPtr
    ctx: GlContextPtr
    id: uint32

proc new_window*(title: string = "Window",
                 size: Index2 = Index2(x: 640, y: 480),
                 pos: Index2 = Index2(x: 100, y: 100),
                 resizable: bool = false,
                 benchmark: bool = false,
                 version: tuple[major: int, minor: int] = (4, 3),
                 multisample_samples: int = 8,
                 multisample_buffers: int = 1,
                 doublebuffer: bool = true,
                 stencil_size: int = 1,
                 red_size: int = 8,
                 green_size: int = 8,
                 blue_size: int = 8,
                 depth_size: int = 24): Window =
  ## Creates a new window. Creating multiple windows
  ## is supported.
  
  let required_systems = uint32(INIT_VIDEO or INIT_EVENTS)
  if (sdl2.was_init(INIT_EVERYTHING) and required_systems) != required_systems:
    if sdl2.init(INIT_EVERYTHING) != SdlSuccess:
      raise WindowError(msg: "Failed to initialize sdl")
    discard sdl2.gl_set_attribute(SDL_GL_CONTEXT_MAJOR_VERSION, version.major.cint)
    discard sdl2.gl_set_attribute(SDL_GL_CONTEXT_MINOR_VERSION, version.minor.cint)

    discard sdl2.gl_set_attribute(SDL_GL_RED_SIZE, red_size.cint)
    discard sdl2.gl_set_attribute(SDL_GL_GREEN_SIZE, green_size.cint)
    discard sdl2.gl_set_attribute(SDL_GL_BLUE_SIZE, blue_size.cint)
    discard sdl2.gl_set_attribute(SDL_GL_DEPTH_SIZE, depth_size.cint)
    
    discard sdl2.gl_set_attribute(SDL_GL_DOUBLEBUFFER, ord(doublebuffer).cint)
    discard sdl2.gl_set_attribute(SDL_GL_MULTISAMPLEBUFFERS, multisample_buffers.cint)
    discard sdl2.gl_set_attribute(SDL_GL_MULTISAMPLESAMPLES, multisample_samples.cint)
    
    discard sdl2.gl_set_attribute(SDL_GL_STENCIL_SIZE, stencil_size.cint)
  
  var flags = SDL_WINDOW_OPENGL
  if resizable:
    flags = flags or SDL_WINDOW_RESIZABLE
  
  let
    win = create_window(
      title.cstring,
      pos.x.cint, pos.y.cint,
      size.x.cint, size.y.cint, flags
    )
    ctx = win.gl_create_context()
  
  load_extensions()
  gl_clear_color(0, 0, 0, 1)
  if benchmark:
    discard gl_set_swap_interval(0)
  return Window(win: win, size: size, ctx: ctx, id: win.get_id())

proc use*(window: Window) =
  discard window.win.gl_make_current(window.ctx)

var
  global_events = new_seq[Event]()
  window_events = init_table[uint32, seq[Event]]()

proc add_window_event(id: uint32, event: Event) =
  if id notin window_events:
    window_events[id] = @[]
  window_events[id].add(event)

proc poll_global() =
  var evt = sdl2.default_event
  while poll_event(evt):
    case evt.kind:
      of QuitEvent:
        global_events.add(Event(kind: EventQuit))
      of WindowEvent:
        let event = cast[WindowEventPtr](evt.addr)
        case event.event:
          of WindowEvent_Resized:
            add_window_event(event.window_id, Event(kind: EventResize))
          of WindowEvent_Close:
            add_window_event(event.window_id, Event(kind: EventClose))
          else:
            discard
      of KeyDown, KeyUp:
        let
          event = cast[KeyboardEventPtr](evt.addr)
          keycode = event.keysym.sym.int

        if evt.kind == KeyDown:
          add_window_event(event.window_id, Event(kind: EventKeyDown,
            keycode: keycode
          ))
        else:
          add_window_event(event.window_id, Event(kind: EventKeyUp,
            keycode: keycode
          ))
      of MouseMotion:
        let event = cast[MouseMotionEventPtr](evt.addr)
        add_window_event(event.window_id, Event(kind: EventMove,
          pos: Index2(x: event.x.int, y: event.y.int)
        ))
      of MouseButtonDown, MouseButtonUp:
        let
          event = cast[MouseButtonEventPtr](evt.addr)
          button = event.button.int - 1 
        
        if evt.kind == MouseButtonDown:
          add_window_event(event.window_id, Event(kind: EventButtonDown,
            button: button
          ))
        else:
          add_window_event(event.window_id, Event(kind: EventButtonUp,
            button: button
          ))
      of MouseWheel:
        let event = cast[MouseWheelEventPtr](evt.addr)
        add_window_event(event.window_id, Event(kind: EventWheel,
          delta: Index2(x: event.x.int, y: event.y.int)
        ))
      else:
        discard

proc add_stateful(event: var Event, window: Window) =
  event.buttons = window.buttons
  event.pos = window.pos

proc process_events(window: Window, events: var seq[Event]) =
  for event in events.mitems:
    case event.kind:
      of EventResize:
        window.use()
        var size = get_size(window.win)
        window.size = Index2(x: size.x.int, y: size.y.int)
        event.size = window.size
        gl_viewport(0, 0, window.size.x.cint, window.size.y.cint)
      of EventButtonDown, EventButtonUp:
        if event.button >= 0 and event.button < window.buttons.len:
          window.buttons[event.button] = event.kind == EventButtonDown
      of EventMove:
        event.prev_pos = window.pos
        window.pos = event.pos
      else: discard
    event.add_stateful(window)

proc poll*(window: Window): seq[Event] =
  ## Reads new events associated with the given window
  poll_global()
  result = global_events
  global_events = @[]
  if window.id in window_events:
    window.process_events(window_events[window.id])
    result &= window_events[window.id]
    window_events[window.id] = @[]

proc swap*(window: Window) =
  ## Swap window
  window.win.gl_swap_window()

proc title*(window: Window): string =
  $window.win.get_title()

proc `title=`*(window: Window, title: string) =
  window.win.set_title(title)

proc resize*(window: Window, size: Index2) =
  ## Resize the given window to the given size
  window.size = size
  window.win.set_size(size.x.cint, size.y.cint)
  gl_viewport(0, 0, size.x.cint, size.y.cint)

proc move*(window: Window, pos: Index2) =
  ## Moves the given window to a given position
  window.win.set_position(pos.x.cint, pos.y.cint)

proc minimize*(window: Window) =
  window.win.minimize_window()

proc maximize*(window: Window) =
  window.win.maximize_window()

proc restore*(window: Window) =
  window.win.restore_window()

proc close*(window: Window) =
  ## Closes the window and deletes its associated context
  window.ctx.gl_delete_context()
  window.win.destroy()
