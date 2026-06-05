package arena

import "core:mem"
import "core:mem/virtual"

Main_Arena :: struct {
	arena: virtual.Arena,
}

Scratch :: struct {
	arena: ^virtual.Arena,
	temp:  virtual.Arena_Temp,
}

init :: proc(size: uint) -> (ma: Main_Arena, allocator: mem.Allocator, err: mem.Allocator_Error) {
	err = virtual.arena_init_static(&ma.arena, size)
	if err == nil {
		allocator = virtual.arena_allocator(&ma.arena)
	}
	return
}

destroy :: proc(ma: ^Main_Arena) {
	virtual.arena_destroy(&ma.arena)
}

begin_scratch :: proc(arena: ^virtual.Arena) -> (scratch: Scratch, allocator: mem.Allocator) {
	scratch.arena = arena
	scratch.temp = virtual.arena_temp_begin(arena)
	allocator = virtual.arena_allocator(arena)
	return
}

end_scratch :: proc(scratch: Scratch) {
	virtual.arena_temp_end(scratch.temp)
}
