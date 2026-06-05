package platform

@(private)
_state: struct {
	api: ^Platform_Api,
	last_resizable: bool,
}

init :: proc(p_api: ^Platform_Api) -> bool {
	_state.api = p_api
	_state.last_resizable = _state.api.window.resizable
	// Stub for Windows
	return false
}

shutdown :: proc() {
	// Stub for Windows
}

update :: proc() {
	// Stub for Windows
}

swap_buffers :: proc() {
	// Stub for Windows
}

message_box :: proc(title, message: string, kind: Message_Box_Kind, has_display := true) {
	// Stub for Windows
}
