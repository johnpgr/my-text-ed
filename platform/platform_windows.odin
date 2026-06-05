package platform

import "base:runtime"
import "core:c"
import "core:fmt"
import win "core:sys/windows"
import gl "vendor:OpenGL"

WINDOW_CLASS :: "my_text_ed_platform"
BOOTSTRAP_CLASS :: "my_text_ed_wgl_bootstrap"

PROCESS_MEMORY_COUNTERS_EX :: struct {
	cb:                         win.DWORD,
	PageFaultCount:             win.DWORD,
	PeakWorkingSetSize:         win.SIZE_T,
	WorkingSetSize:             win.SIZE_T,
	QuotaPeakPagedPoolUsage:    win.SIZE_T,
	QuotaPagedPoolUsage:        win.SIZE_T,
	QuotaPeakNonPagedPoolUsage: win.SIZE_T,
	QuotaNonPagedPoolUsage:     win.SIZE_T,
	PagefileUsage:              win.SIZE_T,
	PeakPagefileUsage:          win.SIZE_T,
	PrivateUsage:               win.SIZE_T,
}

foreign import psapi "system:Psapi.lib"

@(default_calling_convention = "system")
foreign psapi {
	GetProcessMemoryInfo :: proc(hProcess: win.HANDLE, ppsmemCounters: ^PROCESS_MEMORY_COUNTERS_EX, cb: win.DWORD) -> win.BOOL ---
}

@(private)
set_vsync :: proc(vsync: bool) {
	if win.wglSwapIntervalEXT != nil {
		win.wglSwapIntervalEXT(c.int(1 if vsync else 0))
	}
}

@(private)
opengl_debug_callback :: proc "c" (
	source, type_, id, severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {
	context = _state.odin_context

	source_str: string
	switch source {
	case gl.DEBUG_SOURCE_API:
		source_str = "API"
	case gl.DEBUG_SOURCE_WINDOW_SYSTEM:
		source_str = "Window System"
	case gl.DEBUG_SOURCE_SHADER_COMPILER:
		source_str = "Shader Compiler"
	case gl.DEBUG_SOURCE_THIRD_PARTY:
		source_str = "Third Party"
	case gl.DEBUG_SOURCE_APPLICATION:
		source_str = "Application"
	case gl.DEBUG_SOURCE_OTHER:
		source_str = "Other"
	case:
		source_str = "Unknown"
	}

	type_str: string
	switch type_ {
	case gl.DEBUG_TYPE_ERROR:
		type_str = "Error"
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		type_str = "Deprecated Behavior"
	case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		type_str = "Undefined Behavior"
	case gl.DEBUG_TYPE_PORTABILITY:
		type_str = "Portability"
	case gl.DEBUG_TYPE_PERFORMANCE:
		type_str = "Performance"
	case gl.DEBUG_TYPE_MARKER:
		type_str = "Marker"
	case gl.DEBUG_TYPE_PUSH_GROUP:
		type_str = "Push Group"
	case gl.DEBUG_TYPE_POP_GROUP:
		type_str = "Pop Group"
	case gl.DEBUG_TYPE_OTHER:
		type_str = "Other"
	case:
		type_str = "Unknown"
	}

	severity_str: string
	switch severity {
	case gl.DEBUG_SEVERITY_HIGH:
		severity_str = "High"
	case gl.DEBUG_SEVERITY_MEDIUM:
		severity_str = "Medium"
	case gl.DEBUG_SEVERITY_LOW:
		severity_str = "Low"
	case gl.DEBUG_SEVERITY_NOTIFICATION:
		severity_str = "Notification"
	case:
		severity_str = "Unknown"
	}

	fmt.eprintfln(
		"[GL Debug] Source: %s | Type: %s | ID: %d | Severity: %s\nMessage: %s",
		source_str,
		type_str,
		id,
		severity_str,
		message,
	)
}

@(private)
_state: struct {
	odin_context: runtime.Context,
	api:          ^Platform_Api,
	hinstance:    win.HINSTANCE,
	hwnd:         win.HWND,
	hdc:          win.HDC,
	hglrc:        win.HGLRC,
	bootstrap:    struct {
		hwnd:  win.HWND,
		hdc:   win.HDC,
		hglrc: win.HGLRC,
	},
	last:         struct {
		title:     string,
		resizable: bool,
		vsync:     bool,
	},
}

@(private)
map_virtual_key :: proc(vk: win.WPARAM) -> Key_Code {
	switch vk {
	case win.VK_ESCAPE:
		return .Esc
	case win.VK_BACK:
		return .Backspace
	case win.VK_DELETE:
		return .Delete
	case win.VK_RETURN:
		return .Enter
	case win.VK_TAB:
		return .Tab
	case win.VK_SPACE:
		return .Space
	case win.VK_LEFT:
		return .Left
	case win.VK_RIGHT:
		return .Right
	case win.VK_UP:
		return .Up
	case win.VK_DOWN:
		return .Down
	case win.VK_HOME:
		return .Home
	case win.VK_END:
		return .End
	case win.VK_PRIOR:
		return .Page_Up
	case win.VK_NEXT:
		return .Page_Down
	case win.VK_SHIFT, win.VK_LSHIFT, win.VK_RSHIFT:
		return .Shift
	case win.VK_CONTROL, win.VK_LCONTROL, win.VK_RCONTROL:
		return .Control
	case win.VK_MENU, win.VK_LMENU, win.VK_RMENU:
		return .Alt
	case win.VK_A:
		return .A
	case win.VK_B:
		return .B
	case win.VK_C:
		return .C
	case win.VK_D:
		return .D
	case win.VK_E:
		return .E
	case win.VK_F:
		return .F
	case win.VK_G:
		return .G
	case win.VK_H:
		return .H
	case win.VK_I:
		return .I
	case win.VK_J:
		return .J
	case win.VK_K:
		return .K
	case win.VK_L:
		return .L
	case win.VK_M:
		return .M
	case win.VK_N:
		return .N
	case win.VK_O:
		return .O
	case win.VK_P:
		return .P
	case win.VK_Q:
		return .Q
	case win.VK_R:
		return .R
	case win.VK_S:
		return .S
	case win.VK_T:
		return .T
	case win.VK_U:
		return .U
	case win.VK_V:
		return .V
	case win.VK_W:
		return .W
	case win.VK_X:
		return .X
	case win.VK_Y:
		return .Y
	case win.VK_Z:
		return .Z
	case win.VK_0:
		return .Num0
	case win.VK_1:
		return .Num1
	case win.VK_2:
		return .Num2
	case win.VK_3:
		return .Num3
	case win.VK_4:
		return .Num4
	case win.VK_5:
		return .Num5
	case win.VK_6:
		return .Num6
	case win.VK_7:
		return .Num7
	case win.VK_8:
		return .Num8
	case win.VK_9:
		return .Num9
	case win.VK_F1:
		return .F1
	case win.VK_F2:
		return .F2
	case win.VK_F3:
		return .F3
	case win.VK_F4:
		return .F4
	case win.VK_F5:
		return .F5
	case win.VK_F6:
		return .F6
	case win.VK_F7:
		return .F7
	case win.VK_F8:
		return .F8
	case win.VK_F9:
		return .F9
	case win.VK_F10:
		return .F10
	case win.VK_F11:
		return .F11
	case win.VK_F12:
		return .F12
	}
	return .Unknown
}

@(private)
window_style :: proc(resizable: bool) -> win.DWORD {
	if resizable {
		return win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE
	}
	return(
		win.WS_OVERLAPPED |
		win.WS_CAPTION |
		win.WS_SYSMENU |
		win.WS_MINIMIZEBOX |
		win.WS_VISIBLE \
	)
}

@(private)
apply_resizable :: proc(resizable: bool) {
	if _state.hwnd == nil do return

	style := win.GetWindowLongW(_state.hwnd, win.GWL_STYLE)
	if resizable {
		style |= i32(win.WS_THICKFRAME | win.WS_MAXIMIZEBOX)
	} else {
		style &= ~i32(win.WS_THICKFRAME | win.WS_MAXIMIZEBOX)
	}
	win.SetWindowLongW(_state.hwnd, win.GWL_STYLE, style)

	r: win.RECT
	win.GetWindowRect(_state.hwnd, &r)
	win.SetWindowPos(
		_state.hwnd,
		nil,
		r.left,
		r.top,
		r.right - r.left,
		r.bottom - r.top,
		win.SWP_NOZORDER | win.SWP_NOOWNERZORDER | win.SWP_FRAMECHANGED | win.SWP_NOMOVE,
	)
}

@(private)
sync_draw_size_from_client :: proc() {
	if _state.hwnd == nil do return

	rect: win.RECT
	win.GetClientRect(_state.hwnd, &rect)
	width := i32(rect.right - rect.left)
	height := i32(rect.bottom - rect.top)
	if width < 0 do width = 0
	if height < 0 do height = 0

	_state.api.window.size = {width, height}
	_state.api.draw.size = _state.api.window.size
	_state.api.draw.x = _state.api.draw.size.x
	_state.api.draw.y = _state.api.draw.size.y
}

@(private)
sync_dpi :: proc() {
	if _state.hwnd == nil do return
	dpi := win.GetDpiForWindow(_state.hwnd)
	if dpi == 0 do dpi = 96
	_state.api.window.dpi = f32(dpi)
	_state.api.window.content_scale = f32(dpi) / 96.0
}

@(private)
release_all_input :: proc() {
	for i in 0 ..< len(_state.api.keys) {
		set_button(&_state.api.keys[i], false)
	}
	for i in 0 ..< len(_state.api.mouse.buttons) {
		set_button(&_state.api.mouse.buttons[i], false)
	}
	set_button(&_state.api.mouse.left, false)
	set_button(&_state.api.mouse.middle, false)
	set_button(&_state.api.mouse.right, false)
}

@(private)
append_typing_rune :: proc(r: rune) {
	ch := r
	if ch == '\r' do ch = '\n'
	if ch >= 32 || ch == '\t' || ch == '\n' {
		if _state.api.typing_len < len(_state.api.typing) {
			_state.api.typing[_state.api.typing_len] = ch
			_state.api.typing_len += 1
		}
	}
}

@(private)
set_mouse_button :: proc(btn: Mouse_Button, is_down: bool) {
	set_button(&_state.api.mouse.buttons[btn], is_down)
	switch btn {
	case .Left:
		set_button(&_state.api.mouse.left, is_down)
	case .Middle:
		set_button(&_state.api.mouse.middle, is_down)
	case .Right:
		set_button(&_state.api.mouse.right, is_down)
	}
}

@(private)
window_proc :: proc "stdcall" (
	hwnd: win.HWND,
	msg: win.UINT,
	wparam: win.WPARAM,
	lparam: win.LPARAM,
) -> win.LRESULT {
	context = _state.odin_context

	switch msg {
	case win.WM_CLOSE, win.WM_DESTROY:
		_state.api.quit = true

	case win.WM_SIZE:
		sync_draw_size_from_client()

	case win.WM_SETFOCUS:
		_state.api.window.focused = true

	case win.WM_KILLFOCUS:
		_state.api.window.focused = false
		release_all_input()
		win.ReleaseCapture()

	case win.WM_MOUSEMOVE:
		x := win.GET_X_LPARAM(lparam)
		y := win.GET_Y_LPARAM(lparam)
		_state.api.mouse.position = {x, y}

	case win.WM_LBUTTONDOWN:
		set_mouse_button(.Left, true)
		win.SetCapture(hwnd)

	case win.WM_LBUTTONUP:
		set_mouse_button(.Left, false)
		win.ReleaseCapture()

	case win.WM_MBUTTONDOWN:
		set_mouse_button(.Middle, true)
		win.SetCapture(hwnd)

	case win.WM_MBUTTONUP:
		set_mouse_button(.Middle, false)
		win.ReleaseCapture()

	case win.WM_RBUTTONDOWN:
		set_mouse_button(.Right, true)
		win.SetCapture(hwnd)

	case win.WM_RBUTTONUP:
		set_mouse_button(.Right, false)
		win.ReleaseCapture()

	case win.WM_MOUSEWHEEL:
		delta := f32(cast(i16)win.HIWORD(cast(win.DWORD)wparam)) / f32(win.WHEEL_DELTA)
		_state.api.mouse.wheel_delta += delta

	case win.WM_KEYDOWN, win.WM_SYSKEYDOWN:
		key := map_virtual_key(wparam)
		repeat := (lparam & (1 << 30)) != 0
		if repeat {
			set_key_repeat(key)
		} else {
			set_key(key, true)
		}

	case win.WM_KEYUP, win.WM_SYSKEYUP:
		key := map_virtual_key(wparam)
		set_key(key, false)

	case win.WM_CHAR:
		ch := rune(wparam)
		append_typing_rune(ch)

	case win.WM_DPICHANGED:
		new_dpi := win.LOWORD(wparam)
		_state.api.window.dpi = f32(new_dpi)
		_state.api.window.content_scale = f32(new_dpi) / 96.0
		suggested := cast(^win.RECT)cast(uintptr)lparam
		if suggested != nil {
			win.SetWindowPos(
				hwnd,
				nil,
				suggested.left,
				suggested.top,
				suggested.right - suggested.left,
				suggested.bottom - suggested.top,
				win.SWP_NOZORDER | win.SWP_NOACTIVATE,
			)
		}
		sync_draw_size_from_client()

	case win.WM_GETMINMAXINFO:
		if !_state.api.window.resizable {
			info := cast(^win.MINMAXINFO)cast(uintptr)lparam
			info.ptMinTrackSize.x = _state.api.window.size.x
			info.ptMinTrackSize.y = _state.api.window.size.y
			info.ptMaxTrackSize.x = _state.api.window.size.x
			info.ptMaxTrackSize.y = _state.api.window.size.y
		}
	}

	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}

@(private)
destroy_bootstrap :: proc() {
	if _state.bootstrap.hglrc != nil {
		win.wglMakeCurrent(nil, nil)
		win.wglDeleteContext(_state.bootstrap.hglrc)
		_state.bootstrap.hglrc = nil
	}
	if _state.bootstrap.hdc != nil && _state.bootstrap.hwnd != nil {
		win.ReleaseDC(_state.bootstrap.hwnd, _state.bootstrap.hdc)
		_state.bootstrap.hdc = nil
	}
	if _state.bootstrap.hwnd != nil {
		win.DestroyWindow(_state.bootstrap.hwnd)
		_state.bootstrap.hwnd = nil
	}
}

@(private)
load_wgl_extensions :: proc() -> bool {
	bootstrap_wc := win.WNDCLASSW {
		style         = win.CS_OWNDC,
		lpfnWndProc   = win.DefWindowProcW,
		hInstance     = _state.hinstance,
		lpszClassName = BOOTSTRAP_CLASS,
	}
	if win.RegisterClassW(&bootstrap_wc) == 0 {
		message_box(
			"Initialization Error",
			"Failed to register the WGL bootstrap window class.",
			.Error,
		)
		return false
	}
	defer win.UnregisterClassW(BOOTSTRAP_CLASS, _state.hinstance)

	_state.bootstrap.hwnd = win.CreateWindowExW(
		0,
		BOOTSTRAP_CLASS,
		win.L("bootstrap"),
		0,
		0,
		0,
		1,
		1,
		nil,
		nil,
		_state.hinstance,
		nil,
	)
	if _state.bootstrap.hwnd == nil {
		message_box("Initialization Error", "Failed to create the WGL bootstrap window.", .Error)
		return false
	}

	_state.bootstrap.hdc = win.GetDC(_state.bootstrap.hwnd)
	if _state.bootstrap.hdc == nil {
		message_box(
			"Initialization Error",
			"Failed to get the WGL bootstrap device context.",
			.Error,
		)
		destroy_bootstrap()
		return false
	}

	pfd := win.PIXELFORMATDESCRIPTOR {
		nSize      = win.WORD(size_of(win.PIXELFORMATDESCRIPTOR)),
		nVersion   = 1,
		dwFlags    = win.PFD_DRAW_TO_WINDOW | win.PFD_SUPPORT_OPENGL | win.PFD_DOUBLEBUFFER,
		iPixelType = win.PFD_TYPE_RGBA,
		cColorBits = 32,
		iLayerType = win.PFD_MAIN_PLANE,
	}
	fmt_index := win.ChoosePixelFormat(_state.bootstrap.hdc, &pfd)
	if fmt_index == 0 || !win.SetPixelFormat(_state.bootstrap.hdc, fmt_index, &pfd) {
		message_box(
			"Initialization Error",
			"Failed to set a legacy pixel format on the WGL bootstrap context.",
			.Error,
		)
		destroy_bootstrap()
		return false
	}

	_state.bootstrap.hglrc = win.wglCreateContext(_state.bootstrap.hdc)
	if _state.bootstrap.hglrc == nil ||
	   !win.wglMakeCurrent(_state.bootstrap.hdc, _state.bootstrap.hglrc) {
		message_box(
			"Initialization Error",
			"Failed to create the WGL bootstrap OpenGL context.",
			.Error,
		)
		destroy_bootstrap()
		return false
	}

	win.gl_set_proc_address(&win.wglChoosePixelFormatARB, "wglChoosePixelFormatARB")
	win.gl_set_proc_address(&win.wglCreateContextAttribsARB, "wglCreateContextAttribsARB")
	win.gl_set_proc_address(&win.wglSwapIntervalEXT, "wglSwapIntervalEXT")

	if win.wglChoosePixelFormatARB == nil {
		message_box(
			"Initialization Error",
			"wglChoosePixelFormatARB is not supported by your OpenGL driver.",
			.Error,
		)
		destroy_bootstrap()
		return false
	}
	if win.wglCreateContextAttribsARB == nil {
		message_box(
			"Initialization Error",
			"wglCreateContextAttribsARB is not supported by your OpenGL driver.",
			.Error,
		)
		destroy_bootstrap()
		return false
	}
	if win.wglSwapIntervalEXT == nil {
		message_box(
			"Initialization Error",
			"wglSwapIntervalEXT is not supported by your OpenGL driver.",
			.Error,
		)
		destroy_bootstrap()
		return false
	}

	destroy_bootstrap()
	return true
}

@(private)
create_opengl_context :: proc() -> bool {
	_state.hdc = win.GetDC(_state.hwnd)
	if _state.hdc == nil {
		message_box("Initialization Error", "Failed to get the window device context.", .Error)
		return false
	}

	pfd := win.PIXELFORMATDESCRIPTOR {
		nSize        = win.WORD(size_of(win.PIXELFORMATDESCRIPTOR)),
		nVersion     = 1,
		dwFlags      = win.PFD_DRAW_TO_WINDOW | win.PFD_SUPPORT_OPENGL | win.PFD_DOUBLEBUFFER,
		iPixelType   = win.PFD_TYPE_RGBA,
		cColorBits   = 32,
		cAlphaBits   = 8,
		cDepthBits   = 24,
		cStencilBits = 8,
		iLayerType   = win.PFD_MAIN_PLANE,
	}

	pixel_format_attribs := [?]c.int {
		win.WGL_DRAW_TO_WINDOW_ARB,
		1,
		win.WGL_SUPPORT_OPENGL_ARB,
		1,
		win.WGL_DOUBLE_BUFFER_ARB,
		1,
		win.WGL_PIXEL_TYPE_ARB,
		win.WGL_TYPE_RGBA_ARB,
		win.WGL_COLOR_BITS_ARB,
		32,
		win.WGL_ALPHA_BITS_ARB,
		8,
		win.WGL_DEPTH_BITS_ARB,
		24,
		win.WGL_STENCIL_BITS_ARB,
		8,
		win.WGL_ACCELERATION_ARB,
		win.WGL_FULL_ACCELERATION_ARB,
		0,
	}

	pixel_format: c.int
	num_formats: win.DWORD
	if !win.wglChoosePixelFormatARB(
		   _state.hdc,
		   &pixel_format_attribs[0],
		   nil,
		   1,
		   &pixel_format,
		   &num_formats,
	   ) ||
	   num_formats == 0 {
		message_box(
			"Initialization Error",
			"Failed to choose a suitable ARB pixel format with OpenGL support.",
			.Error,
		)
		return false
	}

	if !win.SetPixelFormat(_state.hdc, c.int(pixel_format), &pfd) {
		message_box("Initialization Error", "Failed to apply the chosen ARB pixel format.", .Error)
		return false
	}

	gl_major := _state.api.opengl.major if _state.api.opengl.major > 0 else 4
	gl_minor := _state.api.opengl.minor if _state.api.opengl.major > 0 else 6

	attribs: [16]c.int
	n := 0
	attribs[n] = win.WGL_CONTEXT_MAJOR_VERSION_ARB; n += 1
	attribs[n] = c.int(gl_major); n += 1
	attribs[n] = win.WGL_CONTEXT_MINOR_VERSION_ARB; n += 1
	attribs[n] = c.int(gl_minor); n += 1
	attribs[n] = win.WGL_CONTEXT_PROFILE_MASK_ARB; n += 1
	attribs[n] = win.WGL_CONTEXT_CORE_PROFILE_BIT_ARB; n += 1
	if _state.api.opengl.debug_context {
		attribs[n] = win.WGL_CONTEXT_FLAGS_ARB; n += 1
		attribs[n] = win.WGL_CONTEXT_DEBUG_BIT_ARB; n += 1
	}
	attribs[n] = 0

	_state.hglrc = win.wglCreateContextAttribsARB(_state.hdc, nil, &attribs[0])
	if _state.hglrc == nil || !win.wglMakeCurrent(_state.hdc, _state.hglrc) {
		message_box(
			"Initialization Error",
			fmt.tprintf("Failed to create OpenGL context (version %v.%v).", gl_major, gl_minor),
			.Error,
		)
		return false
	}

	gl.load_up_to(gl_major, gl_minor, win.gl_set_proc_address)
	set_vsync(_state.api.opengl.vsync)

	if _state.api.opengl.debug_context {
		gl.Enable(gl.DEBUG_OUTPUT)
		gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
		gl.DebugMessageCallback(opengl_debug_callback, nil)
		gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, true)
	}

	return true
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

	if _state.api.draw.size.x <= 0 || _state.api.draw.size.y <= 0 {
		_state.api.draw.size = _state.api.window.size
	}
	_state.api.draw.x = _state.api.draw.size.x
	_state.api.draw.y = _state.api.draw.size.y

	win.SetProcessDpiAwarenessContext(win.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

	_state.hinstance = win.HINSTANCE(win.GetModuleHandleW(nil))

	wc := win.WNDCLASSW {
		style         = win.CS_OWNDC | win.CS_HREDRAW | win.CS_VREDRAW,
		lpfnWndProc   = window_proc,
		hInstance     = _state.hinstance,
		hCursor       = win.LoadCursorA(nil, win.IDC_ARROW),
		lpszClassName = WINDOW_CLASS,
	}
	if win.RegisterClassW(&wc) == 0 {
		message_box(
			"Initialization Error",
			"Failed to register the application window class.",
			.Error,
		)
		return false
	}

	dpi := u32(96)
	if mon := win.MonitorFromWindow(nil, .MONITOR_DEFAULTTOPRIMARY); mon != nil {
		dpix, dpiy: win.UINT
		win.GetDpiForMonitor(mon, win.MONITOR_DPI_TYPE.MDT_EFFECTIVE_DPI, &dpix, &dpiy)
		dpi = u32(dpix)
	}
	_state.api.window.dpi = f32(dpi)
	_state.api.window.content_scale = f32(dpi) / 96.0

	client_rect := win.RECT{0, 0, width, height}
	style := window_style(_state.last.resizable)
	win.AdjustWindowRectExForDpi(&client_rect, style, false, 0, dpi)

	_state.hwnd = win.CreateWindowExW(
		0,
		WINDOW_CLASS,
		win.utf8_to_wstring(title, context.temp_allocator),
		style,
		win.CW_USEDEFAULT,
		win.CW_USEDEFAULT,
		client_rect.right - client_rect.left,
		client_rect.bottom - client_rect.top,
		nil,
		nil,
		_state.hinstance,
		nil,
	)
	if _state.hwnd == nil {
		message_box("Initialization Error", "Failed to create the application window.", .Error)
		shutdown()
		return false
	}

	apply_resizable(_state.last.resizable)
	win.ShowWindow(_state.hwnd, win.SW_SHOW)
	sync_dpi()
	sync_draw_size_from_client()

	if !load_wgl_extensions() {
		shutdown()
		return false
	}
	if !create_opengl_context() {
		shutdown()
		return false
	}

	init_time()
	return true
}

shutdown :: proc() {
	if _state.hglrc != nil {
		win.wglMakeCurrent(nil, nil)
		win.wglDeleteContext(_state.hglrc)
		_state.hglrc = nil
	}
	if _state.hdc != nil && _state.hwnd != nil {
		win.ReleaseDC(_state.hwnd, _state.hdc)
		_state.hdc = nil
	}
	if _state.hwnd != nil {
		win.DestroyWindow(_state.hwnd)
		_state.hwnd = nil
	}
	destroy_bootstrap()

	if _state.hinstance != nil {
		win.UnregisterClassW(WINDOW_CLASS, _state.hinstance)
	}

	_state.api = nil
	_state.hinstance = nil
	_state.last = {}
}

update :: proc() {
	if _state.hwnd == nil do return
	assert(_state.api != nil)

	reset_frame_transitions()
	old_mouse := _state.api.mouse.position

	msg: win.MSG
	for win.PeekMessageW(&msg, nil, 0, 0, win.PM_REMOVE) {
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
	}

	_state.api.mouse.delta_position.x = _state.api.mouse.position.x - old_mouse.x
	_state.api.mouse.delta_position.y = _state.api.mouse.position.y - old_mouse.y
	_state.api.mouse.x = _state.api.mouse.position.x
	_state.api.mouse.y = _state.api.mouse.position.y

	_state.api.input.shift = _state.api.keys[int(Key_Code.Shift)].is_down
	_state.api.input.control = _state.api.keys[int(Key_Code.Control)].is_down
	_state.api.input.alt = _state.api.keys[int(Key_Code.Alt)].is_down

	if _state.api.window.title != _state.last.title {
		_state.last.title = _state.api.window.title
		win.SetWindowTextW(
			_state.hwnd,
			win.utf8_to_wstring(_state.last.title, context.temp_allocator),
		)
	}

	if _state.api.window.resizable != _state.last.resizable {
		_state.last.resizable = _state.api.window.resizable
		apply_resizable(_state.last.resizable)
	}

	update_time()
}

swap_buffers :: proc() {
	assert(_state.hdc != nil)
	assert(_state.hglrc != nil)

	if _state.api.opengl.vsync != _state.last.vsync {
		_state.last.vsync = _state.api.opengl.vsync
		set_vsync(_state.last.vsync)
	}

	win.SwapBuffers(_state.hdc)
}

memory_stats :: proc() -> Memory_Stats {
	stats: Memory_Stats

	counters: PROCESS_MEMORY_COUNTERS_EX
	counters.cb = win.DWORD(size_of(PROCESS_MEMORY_COUNTERS_EX))
	if !GetProcessMemoryInfo(win.GetCurrentProcess(), &counters, counters.cb) {
		return stats
	}

	stats.virtual_bytes = u64(counters.PrivateUsage)
	stats.resident_bytes = u64(counters.WorkingSetSize)
	stats.ok = true
	return stats
}

message_box :: proc(title, message: string, kind: Message_Box_Kind, has_display := true) {
	fmt.eprintln(title, "-", message)
	if !has_display do return

	flags: win.UINT = win.MB_OK
	switch kind {
	case .Info:
		flags |= win.MB_ICONINFORMATION
	case .Warning:
		flags |= win.MB_ICONWARNING
	case .Error:
		flags |= win.MB_ICONERROR
	}

	title_w := win.utf8_to_wstring(title, context.temp_allocator)
	message_w := win.utf8_to_wstring(message, context.temp_allocator)
	if title_w == nil || message_w == nil do return

	win.MessageBoxW(nil, message_w, title_w, flags)
}
