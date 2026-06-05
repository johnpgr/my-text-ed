package platform

import "core:time"

Time_Info :: struct {
	seconds_delta: f32,
	seconds:       f64,
	ns:            u64,
	ns_delta:      u64,
	ms:            u64,
	ms_delta:      u64,
}

Button :: struct {
	is_pressed:        bool,
	is_pressed_repeat: bool,
	is_down:           bool,
	is_released:       bool,
	is_up:             bool,
}

Mouse_Button :: enum {
	Left   = 0,
	Middle = 1,
	Right  = 2,
}

MAX_CHARS_PER_FRAME :: 32

Mouse_State :: struct {
	position:       Vec2,
	delta_position: Vec2,
	raw_delta:      Vec2,
	buttons:        [3]Button,
	left:           Button,
	middle:         Button,
	right:          Button,
	wheel_delta:    f32,
	x, y:           i32,
}

Gamepad_Stick :: struct {
	raw:            Vec2f,
	value:          Vec2f,
	magnitude:      f32,
	deadzone_inner: f32,
	deadzone_outer: f32,
	bias:           f32,
}

Gamepad_State :: struct {
	connected:     bool,
	left_stick:    Gamepad_Stick,
	right_stick:   Gamepad_Stick,
	buttons:       [12]Button,
	left_trigger:  f32,
	right_trigger: f32,
}

Platform_Api :: struct {
	quit: bool,

	window: struct {
		size:          Vec2,
		fullscreen:    bool,
		title:         string,
		position:      Vec2,
		resizable:     bool,
		focused:       bool,
		dpi:           f32,
		content_scale: f32,
	},

	draw: struct {
		size:      Vec2,
		pixelate:  bool,
		lock_size: bool,
		x, y:      i32,
	},

	time: struct {
		now:                       Time_Info,
		clamped_max_seconds_delta: f32,
		clamped:                   Time_Info,
		paused:                    bool,
		pausable:                  Time_Info,
	},

	mouse:      Mouse_State,
	keys:       [512]Button,
	gamepads:   [4]Gamepad_State,
	typing:     [MAX_CHARS_PER_FRAME]rune,
	typing_len: int,

	input: struct {
		shift:   bool,
		control: bool,
		alt:     bool,
	},

	opengl: struct {
		major, minor:  int,
		debug_context: bool,
		vsync:         bool,
	},
}

Key_Code :: enum int {
	Unknown   = 0,
	Backspace = 8,
	Tab       = 9,
	Enter     = 13,
	Shift     = 16,
	Control   = 17,
	Alt       = 18,
	Esc       = 27,
	Space     = 32,
	
	// Characters
	Num0 = 48, Num1 = 49, Num2 = 50, Num3 = 51, Num4 = 52, Num5 = 53, Num6 = 54, Num7 = 55, Num8 = 56, Num9 = 57,
	A = 97, B = 98, C = 99, D = 100, E = 101, F = 102, G = 103, H = 104, I = 105,
	J = 106, K = 107, L = 108, M = 109, N = 110, O = 111, P = 112, Q = 113, R = 114,
	S = 115, T = 116, U = 117, V = 118, W = 119, X = 120, Y = 121, Z = 122,

	// Non-ASCII
	Left = 256,
	Up,
	Right,
	Down,
	Insert,
	Delete,
	Home,
	End,
	Page_Up,
	Page_Down,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
}

Message_Box_Kind :: enum {
	Info,
	Warning,
	Error,
}

Memory_Stats :: struct {
	virtual_bytes:  u64,
	resident_bytes: u64,
	ok:             bool,
}

@(private)
_time_start: time.Time
@(private)
_time_last:  time.Time

@(private)
init_time :: proc() {
	_time_start = time.now()
	_time_last = _time_start
}

@(private)
update_time :: proc() {
	assert(_state.api != nil)
	now := time.now()
	diff := time.diff(_time_last, now)
	_time_last = now

	seconds := f64(diff) / f64(time.Second)
	if seconds < 0 {
		seconds = 0
	}

	_state.api.time.now.seconds_delta = f32(seconds)
	_state.api.time.now.seconds += seconds
	ns_delta := u64(seconds * 1_000_000_000.0)
	_state.api.time.now.ns_delta = ns_delta
	_state.api.time.now.ns += ns_delta
	_state.api.time.now.ms_delta = ns_delta / 1_000_000
	_state.api.time.now.ms = _state.api.time.now.ns / 1_000_000

	_state.api.time.clamped = _state.api.time.now
	if _state.api.time.clamped_max_seconds_delta > 0 && _state.api.time.clamped.seconds_delta > _state.api.time.clamped_max_seconds_delta {
		_state.api.time.clamped.seconds_delta = _state.api.time.clamped_max_seconds_delta
	}
	_state.api.time.clamped.ns_delta = u64(f64(_state.api.time.clamped.seconds_delta) * 1_000_000_000.0)
	_state.api.time.clamped.ms_delta = _state.api.time.clamped.ns_delta / 1_000_000

	if !_state.api.time.paused {
		_state.api.time.pausable.seconds_delta = _state.api.time.clamped.seconds_delta
		_state.api.time.pausable.seconds += f64(_state.api.time.pausable.seconds_delta)
		_state.api.time.pausable.ns_delta = u64(f64(_state.api.time.pausable.seconds_delta) * 1_000_000_000.0)
		_state.api.time.pausable.ns += _state.api.time.pausable.ns_delta
		_state.api.time.pausable.ms_delta = _state.api.time.pausable.ms_delta / 1_000_000
		_state.api.time.pausable.ms = _state.api.time.pausable.ns / 1_000_000
	} else {
		_state.api.time.pausable.seconds_delta = 0
		_state.api.time.pausable.ns_delta = 0
		_state.api.time.pausable.ms_delta = 0
	}
}

@(private)
reset_frame_transitions :: proc() {
	assert(_state.api != nil)
	for i in 0..<len(_state.api.keys) {
		_state.api.keys[i].is_pressed = false
		_state.api.keys[i].is_pressed_repeat = false
		_state.api.keys[i].is_released = false
		_state.api.keys[i].is_up = !_state.api.keys[i].is_down
	}
	for i in 0..<len(_state.api.mouse.buttons) {
		_state.api.mouse.buttons[i].is_pressed = false
		_state.api.mouse.buttons[i].is_pressed_repeat = false
		_state.api.mouse.buttons[i].is_released = false
		_state.api.mouse.buttons[i].is_up = !_state.api.mouse.buttons[i].is_down
	}
	_state.api.mouse.left.is_pressed = false
	_state.api.mouse.left.is_pressed_repeat = false
	_state.api.mouse.left.is_released = false
	_state.api.mouse.left.is_up = !_state.api.mouse.left.is_down

	_state.api.mouse.middle.is_pressed = false
	_state.api.mouse.middle.is_pressed_repeat = false
	_state.api.mouse.middle.is_released = false
	_state.api.mouse.middle.is_up = !_state.api.mouse.middle.is_down

	_state.api.mouse.right.is_pressed = false
	_state.api.mouse.right.is_pressed_repeat = false
	_state.api.mouse.right.is_released = false
	_state.api.mouse.right.is_up = !_state.api.mouse.right.is_down

	for i in 0..<len(_state.api.gamepads) {
		for b in 0..<len(_state.api.gamepads[i].buttons) {
			_state.api.gamepads[i].buttons[b].is_pressed = false
			_state.api.gamepads[i].buttons[b].is_pressed_repeat = false
			_state.api.gamepads[i].buttons[b].is_released = false
			_state.api.gamepads[i].buttons[b].is_up = !_state.api.gamepads[i].buttons[b].is_down
		}
	}

	_state.api.mouse.delta_position.x = 0
	_state.api.mouse.delta_position.y = 0
	_state.api.mouse.raw_delta.x = 0
	_state.api.mouse.raw_delta.y = 0
	_state.api.mouse.wheel_delta = 0

	_state.api.typing_len = 0
	for i in 0..<len(_state.api.typing) {
		_state.api.typing[i] = 0
	}
}

@(private)
set_button :: proc(button: ^Button, is_down: bool) {
	down := is_down
	if button.is_down != down {
		if down {
			button.is_pressed = true
		} else {
			button.is_released = true
		}
		button.is_down = down
	}
	button.is_up = !button.is_down
}

@(private)
set_button_repeat :: proc(button: ^Button) {
	if button.is_down {
		button.is_pressed_repeat = true
	}
}

@(private)
set_key :: proc(key: Key_Code, is_down: bool) {
	idx := int(key)
	if idx >= 0 && idx < len(_state.api.keys) {
		set_button(&_state.api.keys[idx], is_down)
	}
}

@(private)
set_key_repeat :: proc(key: Key_Code) {
	idx := int(key)
	if idx >= 0 && idx < len(_state.api.keys) {
		set_button_repeat(&_state.api.keys[idx])
	}
}
