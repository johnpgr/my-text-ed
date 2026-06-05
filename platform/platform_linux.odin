package platform

import "core:c"
import "core:strings"
import "core:fmt"
import "core:os"
import "base:runtime"
import gl "vendor:OpenGL"
import "vendor:x11/xlib"

GLXContext :: distinct rawptr
GLXFBConfig :: distinct rawptr
GLXDrawable :: xlib.Drawable

glXSwapIntervalEXTProc :: #type proc "c" (dpy: ^xlib.Display, drawable: GLXDrawable, interval: c.int)
glXSwapIntervalMESAProc :: #type proc "c" (interval: c.int) -> c.int
glXSwapIntervalSGIProc :: #type proc "c" (interval: c.int) -> c.int

@(private)
glx_swap_interval_ext: glXSwapIntervalEXTProc
@(private)
glx_swap_interval_mesa: glXSwapIntervalMESAProc
@(private)
glx_swap_interval_sgi: glXSwapIntervalSGIProc

@(private)
set_vsync :: proc(vsync: bool) {
	interval := c.int(1 if vsync else 0)
	if glx_swap_interval_ext != nil {
		glx_swap_interval_ext(_state.display, GLXDrawable(_state.window), interval)
	} else if glx_swap_interval_mesa != nil {
		glx_swap_interval_mesa(interval)
	} else if glx_swap_interval_sgi != nil {
		glx_swap_interval_sgi(interval)
	}
}

@(private)
opengl_debug_callback :: proc "c" (source, type_, id, severity: u32, length: i32, message: cstring, userParam: rawptr) {
	context = _state.odin_context

	source_str: string
	switch source {
	case gl.DEBUG_SOURCE_API:             source_str = "API"
	case gl.DEBUG_SOURCE_WINDOW_SYSTEM:   source_str = "Window System"
	case gl.DEBUG_SOURCE_SHADER_COMPILER: source_str = "Shader Compiler"
	case gl.DEBUG_SOURCE_THIRD_PARTY:     source_str = "Third Party"
	case gl.DEBUG_SOURCE_APPLICATION:     source_str = "Application"
	case gl.DEBUG_SOURCE_OTHER:           source_str = "Other"
	case:                                 source_str = "Unknown"
	}

	type_str: string
	switch type_ {
	case gl.DEBUG_TYPE_ERROR:               type_str = "Error"
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR: type_str = "Deprecated Behavior"
	case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:  type_str = "Undefined Behavior"
	case gl.DEBUG_TYPE_PORTABILITY:         type_str = "Portability"
	case gl.DEBUG_TYPE_PERFORMANCE:         type_str = "Performance"
	case gl.DEBUG_TYPE_MARKER:              type_str = "Marker"
	case gl.DEBUG_TYPE_PUSH_GROUP:          type_str = "Push Group"
	case gl.DEBUG_TYPE_POP_GROUP:           type_str = "Pop Group"
	case gl.DEBUG_TYPE_OTHER:               type_str = "Other"
	case:                                   type_str = "Unknown"
	}

	severity_str: string
	switch severity {
	case gl.DEBUG_SEVERITY_HIGH:         severity_str = "High"
	case gl.DEBUG_SEVERITY_MEDIUM:       severity_str = "Medium"
	case gl.DEBUG_SEVERITY_LOW:          severity_str = "Low"
	case gl.DEBUG_SEVERITY_NOTIFICATION: severity_str = "Notification"
	case:                                severity_str = "Unknown"
	}

	fmt.eprintfln("[GL Debug] Source: %s | Type: %s | ID: %d | Severity: %s\nMessage: %s",
		source_str, type_str, id, severity_str, message)
}

@(private)
_state: struct {
	odin_context:     runtime.Context,
	api:              ^Platform_Api,
	display:          ^xlib.Display,
	window:           xlib.Window,
	gl_context:       GLXContext,
	xim:              xlib.XIM,
	xic:              xlib.XIC,
	wm_delete_window: xlib.Atom,
	last: struct {
		title:     string,
		resizable: bool,
		vsync:     bool,
	},
}

foreign import libGL "system:GL"

@(default_calling_convention = "c")
foreign libGL {
	glXChooseFBConfig :: proc(dpy: ^xlib.Display, screen: c.int, attrib_list: ^c.int, nelements: ^c.int) -> [^]GLXFBConfig ---
	glXGetVisualFromFBConfig :: proc(dpy: ^xlib.Display, config: GLXFBConfig) -> ^xlib.XVisualInfo ---
	glXMakeCurrent :: proc(dpy: ^xlib.Display, drawable: GLXDrawable, ctx: GLXContext) -> b32 ---
	glXSwapBuffers :: proc(dpy: ^xlib.Display, drawable: GLXDrawable) ---
	glXQueryVersion :: proc(dpy: ^xlib.Display, major: ^c.int, minor: ^c.int) -> b32 ---
	glXGetProcAddress :: proc(procName: cstring) -> rawptr ---
	glXDestroyContext :: proc(dpy: ^xlib.Display, ctx: GLXContext) ---
}

GLX_CONTEXT_MAJOR_VERSION_ARB :: 0x2091
GLX_CONTEXT_MINOR_VERSION_ARB :: 0x2092
GLX_CONTEXT_FLAGS_ARB :: 0x2094
GLX_CONTEXT_DEBUG_BIT_ARB :: 0x00000001
GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB :: 0x00000002

glXCreateContextAttribsARBProc :: #type proc "c" (
	dpy: ^xlib.Display,
	config: GLXFBConfig,
	share_context: GLXContext,
	direct: bool,
	attrib_list: ^c.int,
) -> GLXContext

@(private)
map_keysym :: proc(sym: xlib.KeySym) -> Key_Code {
	#partial switch sym {
	case .XK_Escape:    return .Esc
	case .XK_BackSpace: return .Backspace
	case .XK_Delete:    return .Delete
	case .XK_Return:    return .Enter
	case .XK_Tab:       return .Tab
	case .XK_space:     return .Space
	case .XK_Left:      return .Left
	case .XK_Right:     return .Right
	case .XK_Up:        return .Up
	case .XK_Down:      return .Down
	case .XK_Home:      return .Home
	case .XK_End:       return .End
	case .XK_Page_Up:   return .Page_Up
	case .XK_Page_Down: return .Page_Down
	case .XK_Shift_L, .XK_Shift_R:     return .Shift
	case .XK_Control_L, .XK_Control_R: return .Control
	case .XK_Alt_L, .XK_Alt_R:         return .Alt
	case .XK_a, .XK_A:  return .A
	case .XK_b, .XK_B:  return .B
	case .XK_c, .XK_C:  return .C
	case .XK_d, .XK_D:  return .D
	case .XK_e, .XK_E:  return .E
	case .XK_f, .XK_F:  return .F
	case .XK_g, .XK_G:  return .G
	case .XK_h, .XK_H:  return .H
	case .XK_i, .XK_I:  return .I
	case .XK_j, .XK_J:  return .J
	case .XK_k, .XK_K:  return .K
	case .XK_l, .XK_L:  return .L
	case .XK_m, .XK_M:  return .M
	case .XK_n, .XK_N:  return .N
	case .XK_o, .XK_O:  return .O
	case .XK_p, .XK_P:  return .P
	case .XK_q, .XK_Q:  return .Q
	case .XK_r, .XK_R:  return .R
	case .XK_s, .XK_S:  return .S
	case .XK_t, .XK_T:  return .T
	case .XK_u, .XK_U:  return .U
	case .XK_v, .XK_V:  return .V
	case .XK_w, .XK_W:  return .W
	case .XK_x, .XK_X:  return .X
	case .XK_y, .XK_Y:  return .Y
	case .XK_z, .XK_Z:  return .Z
	case .XK_0:         return .Num0
	case .XK_1:         return .Num1
	case .XK_2:         return .Num2
	case .XK_3:         return .Num3
	case .XK_4:         return .Num4
	case .XK_5:         return .Num5
	case .XK_6:         return .Num6
	case .XK_7:         return .Num7
	case .XK_8:         return .Num8
	case .XK_9:         return .Num9
	case .XK_F1:        return .F1
	case .XK_F2:        return .F2
	case .XK_F3:        return .F3
	case .XK_F4:        return .F4
	case .XK_F5:        return .F5
	case .XK_F6:        return .F6
	case .XK_F7:        return .F7
	case .XK_F8:        return .F8
	case .XK_F9:        return .F9
	case .XK_F10:       return .F10
	case .XK_F11:       return .F11
	case .XK_F12:       return .F12
	}
	return .Unknown
}

@(private)
apply_resizable :: proc(resizable: bool) {
	hints: xlib.XSizeHints
	if !resizable {
		hints.flags = {.PMinSize, .PMaxSize}
		hints.min_width = _state.api.window.size.x
		hints.max_width = _state.api.window.size.x
		hints.min_height = _state.api.window.size.y
		hints.max_height = _state.api.window.size.y
	} else {
		hints.flags = {.PMinSize}
		hints.min_width = 1
		hints.min_height = 1
	}
	xlib.SetWMNormalHints(_state.display, _state.window, &hints)
}

init :: proc(p_api: ^Platform_Api) -> bool {
	assert(p_api != nil)
	_state.api = p_api
	_state.odin_context = context
	_state.last.vsync = _state.api.opengl.vsync
	title := _state.api.window.title
	if title == "" {
		title = "platform"
	}
	width := _state.api.window.size.x
	if width <= 0 do width = 1280
	height := _state.api.window.size.y
	if height <= 0 do height = 720

	_state.api.window.size = {width, height}
	_state.api.window.title = title
	_state.last.title = title
	_state.last.resizable = _state.api.window.resizable
	_state.api.window.dpi = 96.0
	_state.api.window.content_scale = 1.0

	if _state.api.draw.size.x <= 0 || _state.api.draw.size.y <= 0 {
		_state.api.draw.size = _state.api.window.size
	}
	_state.api.draw.x = _state.api.draw.size.x
	_state.api.draw.y = _state.api.draw.size.y

	xlib.InitThreads()

	_state.display = xlib.OpenDisplay(nil)
	if _state.display == nil {
		message_box("Initialization Error", "Failed to open X11 Display. Make sure an X server is running and the DISPLAY environment variable is set.", .Error, false)
		return false
	}

	major, minor: c.int
	if !glXQueryVersion(_state.display, &major, &minor) || (major == 1 && minor < 3) || major < 1 {
		message_box("Initialization Error", "GLX version 1.3 or higher is required. Supported GLX version check failed.", .Error)
		xlib.CloseDisplay(_state.display)
		_state.display = nil
		return false
	}

	fb_attribs := []c.int {
		0x8012, 1, // GLX_X_RENDERABLE (True)
		0x8010, 0x00000001, // GLX_DRAWABLE_TYPE (GLX_WINDOW_BIT)
		0x8011, 0x00000001, // GLX_RENDER_TYPE (GLX_RGBA_BIT)
		0x22, 0x8002, // GLX_X_VISUAL_TYPE (GLX_TRUE_COLOR)
		8, 8, // GLX_RED_SIZE
		9, 8, // GLX_GREEN_SIZE
		10, 8, // GLX_BLUE_SIZE
		11, 8, // GLX_ALPHA_SIZE
		12, 24, // GLX_DEPTH_SIZE
		13, 8, // GLX_STENCIL_SIZE
		5, 1, // GLX_DOUBLEBUFFER (True)
		0, // None
	}

	num_configs: c.int
	configs := glXChooseFBConfig(
		_state.display,
		xlib.DefaultScreen(_state.display),
		&fb_attribs[0],
		&num_configs,
	)
	if configs == nil || num_configs == 0 {
		message_box("Initialization Error", "Failed to choose a suitable GLX Framebuffer configuration with OpenGL support.", .Error)
		xlib.CloseDisplay(_state.display)
		_state.display = nil
		return false
	}
	fb_config := configs[0]
	xlib.Free(configs)

	vi := glXGetVisualFromFBConfig(_state.display, fb_config)
	if vi == nil {
		message_box("Initialization Error", "Failed to get an XVisualInfo structure from the selected framebuffer configuration.", .Error)
		xlib.CloseDisplay(_state.display)
		_state.display = nil
		return false
	}
	defer xlib.Free(vi)

	root := xlib.RootWindow(_state.display, vi.screen)
	cmap := xlib.CreateColormap(_state.display, root, vi.visual, .AllocNone)

	swa: xlib.XSetWindowAttributes
	swa.colormap = cmap
	swa.background_pixmap = 0
	swa.border_pixel = 0
	swa.event_mask = {
		.Exposure,
		.PointerMotion,
		.ButtonPress,
		.ButtonRelease,
		.KeyPress,
		.KeyRelease,
		.FocusChange,
		.StructureNotify,
	}

	_state.window = xlib.CreateWindow(
		_state.display,
		root,
		0, 0,
		u32(width), u32(height),
		0,
		vi.depth,
		.InputOutput,
		vi.visual,
		{.CWColormap, .CWBorderPixel, .CWEventMask},
		&swa,
	)
	if _state.window == 0 {
		message_box("Initialization Error", "Failed to create X11 Window.", .Error)
		xlib.CloseDisplay(_state.display)
		_state.display = nil
		return false
	}

	apply_resizable(_state.last.resizable)

	title_cstr := strings.clone_to_cstring(title, context.temp_allocator)
	xlib.StoreName(_state.display, _state.window, title_cstr)

	xlib.MapWindow(_state.display, _state.window)

	_state.xim = xlib.OpenIM(_state.display, nil, nil, nil)
	if _state.xim != nil {
		_state.xic = xlib.CreateIC(
			_state.xim,
			xlib.XNInputStyle, xlib.XIMPreeditNothing | xlib.XIMStatusNothing,
			xlib.XNClientWindow, _state.window,
			xlib.XNFocusWindow, _state.window,
			nil,
		)
	}

	_state.wm_delete_window = xlib.InternAtom(_state.display, "WM_DELETE_WINDOW", false)
	xlib.SetWMProtocols(_state.display, _state.window, &_state.wm_delete_window, 1)

	glXCreateContextAttribsARB := cast(glXCreateContextAttribsARBProc)glXGetProcAddress(
		"glXCreateContextAttribsARB",
	)
	if glXCreateContextAttribsARB == nil {
		message_box("Initialization Error", "glXCreateContextAttribsARB is not supported by your OpenGL driver/GLX extension.", .Error)
		shutdown()
		return false
	}

	gl_major := _state.api.opengl.major if _state.api.opengl.major > 0 else 4
	gl_minor := _state.api.opengl.minor if _state.api.opengl.major > 0 else 6

	attribs: [16]c.int
	n := 0
	attribs[n] = GLX_CONTEXT_MAJOR_VERSION_ARB; n += 1
	attribs[n] = c.int(gl_major);               n += 1
	attribs[n] = GLX_CONTEXT_MINOR_VERSION_ARB; n += 1
	attribs[n] = c.int(gl_minor);               n += 1
	if _state.api.opengl.debug_context {
		attribs[n] = GLX_CONTEXT_FLAGS_ARB;     n += 1
		attribs[n] = GLX_CONTEXT_DEBUG_BIT_ARB; n += 1
	}
	attribs[n] = 0

	_state.gl_context = glXCreateContextAttribsARB(
		_state.display,
		fb_config,
		nil,
		true,
		&attribs[0],
	)
	if _state.gl_context == nil {
		message_box("Initialization Error", fmt.tprintf("Failed to create OpenGL context (version %v.%v).", gl_major, gl_minor), .Error)
		shutdown()
		return false
	}

	if !glXMakeCurrent(_state.display, GLXDrawable(_state.window), _state.gl_context) {
		shutdown()
		return false
	}

	gl.load_up_to(gl_major, gl_minor, proc(p: rawptr, name: cstring) {
		(cast(^rawptr)p)^ = glXGetProcAddress(name)
	})

	glx_swap_interval_ext = cast(glXSwapIntervalEXTProc)glXGetProcAddress("glXSwapIntervalEXT")
	glx_swap_interval_mesa = cast(glXSwapIntervalMESAProc)glXGetProcAddress("glXSwapIntervalMESA")
	glx_swap_interval_sgi = cast(glXSwapIntervalSGIProc)glXGetProcAddress("glXSwapIntervalSGI")

	set_vsync(_state.api.opengl.vsync)

	if _state.api.opengl.debug_context {
		gl.Enable(gl.DEBUG_OUTPUT)
		gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
		gl.DebugMessageCallback(opengl_debug_callback, nil)
		gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, true)
	}

	init_time()

	return true
}

shutdown :: proc() {
	if _state.display == nil do return

	if _state.gl_context != nil {
		glXMakeCurrent(_state.display, 0, nil)
		glXDestroyContext(_state.display, _state.gl_context)
		_state.gl_context = nil
	}

	if _state.window != 0 {
		xlib.DestroyWindow(_state.display, _state.window)
		_state.window = 0
	}

	xlib.CloseDisplay(_state.display)
	_state.display = nil
}

update :: proc() {
	if _state.display == nil do return
	assert(_state.api != nil)

	reset_frame_transitions()
	old_mouse := _state.api.mouse.position

	for xlib.Pending(_state.display) > 0 {
		evt: xlib.XEvent
		xlib.NextEvent(_state.display, &evt)

		#partial switch evt.type {
		case .KeyPress, .KeyRelease:
			keysym := xlib.LookupKeysym(&evt.xkey, 0)
			key := map_keysym(keysym)
			is_down := evt.type == .KeyPress

			// Detect X11 auto-repeat
			if !is_down && xlib.Pending(_state.display) > 0 {
				next_evt: xlib.XEvent
				xlib.PeekEvent(_state.display, &next_evt)
				if next_evt.type == .KeyPress &&
				   next_evt.xkey.keycode == evt.xkey.keycode &&
				   next_evt.xkey.time == evt.xkey.time {
					// Consume KeyPress
					xlib.NextEvent(_state.display, &next_evt)
					set_key_repeat(key)
					continue
				}
			}

			set_key(key, is_down)

			if is_down {
				// Handle text typing lookup
				status: xlib.LookupStringStatus
				buf: [256]byte
				temp_keysym: xlib.KeySym
				n := xlib.Xutf8LookupString(
					_state.xic,
					&evt.xkey,
					cast(cstring)&buf[0],
					i32(len(buf)),
					&temp_keysym,
					&status,
				)

				if n > 0 && (status == .LookupChars || status == .LookupBoth) {
					str := string(buf[:n])
					for r in str {
						if r >= 32 || r == '\t' || r == '\n' {
							if _state.api.typing_len < len(_state.api.typing) {
								_state.api.typing[_state.api.typing_len] = r
								_state.api.typing_len += 1
							}
						}
					}
				}
			}

		case .ButtonPress, .ButtonRelease:
			is_down := evt.type == .ButtonPress

			if evt.xbutton.button == .Button4 {
				if is_down {
					_state.api.mouse.wheel_delta += 1.0
				}
			} else if evt.xbutton.button == .Button5 {
				if is_down {
					_state.api.mouse.wheel_delta -= 1.0
				}
			} else {
				btn: Mouse_Button
				#partial switch evt.xbutton.button {
				case .Button1: btn = .Left
				case .Button2: btn = .Middle
				case .Button3: btn = .Right
				case: continue
				}

				set_button(&_state.api.mouse.buttons[btn], is_down)
				switch btn {
				case .Left:   set_button(&_state.api.mouse.left, is_down)
				case .Middle: set_button(&_state.api.mouse.middle, is_down)
				case .Right:  set_button(&_state.api.mouse.right, is_down)
				}
			}

		case .MotionNotify:
			_state.api.mouse.position.x = evt.xmotion.x
			_state.api.mouse.position.y = evt.xmotion.y

		case .FocusIn:
			_state.api.window.focused = true

		case .FocusOut:
			_state.api.window.focused = false

		case .ConfigureNotify:
			if evt.xconfigure.width != _state.api.window.size.x || evt.xconfigure.height != _state.api.window.size.y {
				_state.api.window.size.x = evt.xconfigure.width
				_state.api.window.size.y = evt.xconfigure.height
				_state.api.draw.size = _state.api.window.size
				_state.api.draw.x = _state.api.draw.size.x
				_state.api.draw.y = _state.api.draw.size.y
			}

		case .ClientMessage:
			if evt.xclient.data.l[0] == cast(int)_state.wm_delete_window {
				_state.api.quit = true
			}
		}
	}

	_state.api.mouse.delta_position.x = _state.api.mouse.position.x - old_mouse.x
	_state.api.mouse.delta_position.y = _state.api.mouse.position.y - old_mouse.y
	_state.api.mouse.x = _state.api.mouse.position.x
	_state.api.mouse.y = _state.api.mouse.position.y

	// Sync modifier state
	_state.api.input.shift = _state.api.keys[int(Key_Code.Shift)].is_down
	_state.api.input.control = _state.api.keys[int(Key_Code.Control)].is_down
	_state.api.input.alt = _state.api.keys[int(Key_Code.Alt)].is_down

	// Sync window title if changed since last frame
	if _state.api.window.title != _state.last.title {
		_state.last.title = _state.api.window.title
		title_cstr := strings.clone_to_cstring(_state.last.title, context.temp_allocator)
		xlib.StoreName(_state.display, _state.window, title_cstr)
	}

	// Sync window resizability if changed since last frame
	if _state.api.window.resizable != _state.last.resizable {
		_state.last.resizable = _state.api.window.resizable
		apply_resizable(_state.last.resizable)
	}

	update_time()
}

swap_buffers :: proc() {
	assert(_state.display != nil)
	assert(_state.window != 0)
	assert(_state.gl_context != nil)

	if _state.api.opengl.vsync != _state.last.vsync {
		_state.last.vsync = _state.api.opengl.vsync
		set_vsync(_state.last.vsync)
	}

	glXSwapBuffers(_state.display, GLXDrawable(_state.window))
}

@(private)
run_msgbox :: proc(cmd: []string) -> bool {
	p, err := os.process_start(os.Process_Desc{command = cmd})
	if err != nil {
		return false
	}
	_, _ = os.process_wait(p)
	return true
}

message_box :: proc(title, message: string, kind: Message_Box_Kind, has_display := true) {
	fmt.eprintln(title, "-", message)

	if !has_display {
		return
	}

	de_temp, _ := os.lookup_env("XDG_CURRENT_DESKTOP", context.temp_allocator)
	if de_temp == "" {
		de_temp, _ = os.lookup_env("DESKTOP_SESSION", context.temp_allocator)
	}
	de := strings.to_lower(de_temp, context.temp_allocator)

	is_kde := strings.contains(de, "kde")
	if !is_kde {
		kde_full, _ := os.lookup_env("KDE_FULL_SESSION", context.temp_allocator)
		is_kde = kde_full != ""
	}

	is_gnome_or_gtk := strings.contains(de, "gnome") || 
	                   strings.contains(de, "xfce") || 
	                   strings.contains(de, "lxde")
	if !is_gnome_or_gtk {
		gnome_id, _ := os.lookup_env("GNOME_DESKTOP_SESSION_ID", context.temp_allocator)
		is_gnome_or_gtk = gnome_id != ""
	}

	zenity_type: string
	kdialog_type: string
	yad_type: string

	switch kind {
	case .Info:
		zenity_type = "--info"
		kdialog_type = "--msgbox"
		yad_type = "--info"
	case .Warning:
		zenity_type = "--warning"
		kdialog_type = "--sorry"
		yad_type = "--warning"
	case .Error:
		zenity_type = "--error"
		kdialog_type = "--error"
		yad_type = "--error"
	}

	if is_kde {
		if run_msgbox([]string{"kdialog", "--title", title, kdialog_type, message}) {
			return
		}
	} else if is_gnome_or_gtk {
		if run_msgbox([]string{"zenity", zenity_type, "--title", title, "--text", message, "--no-wrap"}) {
			return
		}
	}

	if run_msgbox([]string{"zenity", zenity_type, "--title", title, "--text", message, "--no-wrap"}) {
		return
	}
	if run_msgbox([]string{"kdialog", "--title", title, kdialog_type, message}) {
		return
	}
	if run_msgbox([]string{"yad", yad_type, "--title", title, "--text", message}) {
		return
	}
	if run_msgbox([]string{"xmessage", "-title", title, "-center", message}) {
		return
	}
}
