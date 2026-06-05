package arena

import "core:mem"
import "core:mem/virtual"

Scratch :: struct {
	arena: ^virtual.Arena,
	temp:  virtual.Arena_Temp,
}

init :: proc(arena: ^virtual.Arena, size: uint) -> (allocator: mem.Allocator, err: mem.Allocator_Error) {
	assert(arena != nil)
	err = virtual.arena_init_static(arena, size)
	if err == nil {
		allocator = virtual.arena_allocator(arena)
	}
	return
}

destroy :: proc(arena: ^virtual.Arena) {
	assert(arena != nil)
	virtual.arena_destroy(arena)
}

begin_scratch :: proc(arena: ^virtual.Arena) -> (scratch: Scratch, allocator: mem.Allocator) {
	assert(arena != nil)
	scratch.arena = arena
	scratch.temp = virtual.arena_temp_begin(arena)
	allocator = virtual.arena_allocator(arena)
	return
}

end_scratch :: proc(scratch: Scratch) {
	assert(scratch.arena != nil)
	virtual.arena_temp_end(scratch.temp)
}
