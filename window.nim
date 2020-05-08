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

import sdl2 except Color, rgb
import opengl
import utils

type
  EventKind* = enum
    EventQuit, EventResize,
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

  Window* = ref object
    win: WindowPtr
    size*: Index2
    
    events: seq[Event]
    pos*: Index2
    buttons*: array[3, bool]
    

proc new_window*(title: string = "Window",
                 size: Index2 = Index2(x: 640, y: 480),
                 pos: Index2 = Index2(x: 100, y: 100),
                 resizable: bool = false): Window =
  ## Creates a new window. Note that using multiple windows
  ## is currently not supported.
  
  if sdl2.was_init(INIT_EVERYTHING) != INIT_EVERYTHING:
    echo "Initializing..."
    discard sdl2.init(INIT_EVERYTHING)
    discard sdl2.gl_set_attribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4)
    discard sdl2.gl_set_attribute(SDL_GL_CONTEXT_MINOR_VERSION, 5)

    discard sdl2.gl_set_attribute(SDL_GL_RED_SIZE, 8)
    discard sdl2.gl_set_attribute(SDL_GL_GREEN_SIZE, 8)
    discard sdl2.gl_set_attribute(SDL_GL_BLUE_SIZE, 8)
    discard sdl2.gl_set_attribute(SDL_GL_DEPTH_SIZE, 24)
    
    discard sdl2.gl_set_attribute(SDL_GL_DOUBLEBUFFER, 1)
    discard sdl2.gl_set_attribute(SDL_GL_MULTISAMPLEBUFFERS, 1)
    discard sdl2.gl_set_attribute(SDL_GL_MULTISAMPLESAMPLES, 16)
    
  
  var flags = SDL_WINDOW_OPENGL
  if resizable:
    flags = flags or SDL_WINDOW_RESIZABLE
  
  let win = create_window(
    title.cstring,
    pos.x.cint, pos.y.cint,
    size.x.cint, size.y.cint, flags
  )
  discard win.gl_create_context()
  load_extensions()
  gl_clear_color(0, 0, 0, 1)
  return Window(win: win, size: size)

proc add_stateful(event: Event, window: Window): Event =
  result = event
  result.buttons = window.buttons
  result.pos = window.pos

proc add(window: Window, event: Event) =
  window.events.add(event.add_stateful(window))

proc poll*(window: Window): seq[Event] =
  ## Reads new events associated with the given window
  var evt = sdl2.default_event
  while poll_event(evt):
    case evt.kind:
      of QuitEvent:
        window.add(Event(kind: EventQuit))
      of WindowEvent:
        let event = cast[WindowEventPtr](evt.addr)
        case event.event:
          of WindowEvent_Resized:
            window.size = Index2(x: event.data1.int, y: event.data2.int)
            gl_viewport(0, 0, window.size.x.cint, window.size.y.cint)
            window.add(Event(kind: EventResize, size: window.size))
          else:
            discard
      of KeyDown, KeyUp:
        let
          event = cast[KeyboardEventPtr](evt.addr)
          keycode = event.keysym.sym.int

        if evt.kind == KeyDown:
          window.add(Event(kind: EventKeyDown, keycode: keycode))
        else:
          window.add(Event(kind: EventKeyUp, keycode: keycode))
      of MouseMotion:
        let
          event = cast[MouseMotionEventPtr](evt.addr)
          prev_pos = window.pos
        window.pos = Index2(x: event.x.int, y: event.y.int)
        window.add(Event(kind: EventMove, prev_pos: prev_pos))
      of MouseButtonDown, MouseButtonUp:
        let
          event = cast[MouseButtonEventPtr](evt.addr)
          button = event.button.int - 1 
        if button >= 0 and button < window.buttons.len:
          window.buttons[button] = evt.kind == MouseButtonDown
        
        if evt.kind == MouseButtonDown:
          window.add(Event(kind: EventButtonDown, button: button))
        else:
          window.add(Event(kind: EventButtonUp, button: button))
      of MouseWheel:
        let event = cast[MouseWheelEventPtr](evt.addr)
        window.add(Event(kind: EventWheel, delta: Index2(
          x: event.x.int, y: event.y.int
        )))
      else:
        discard
  
  result = window.events
  window.events = @[]
  return

proc swap*(window: Window) =
  ## Swap window
  window.win.gl_swap_window()

