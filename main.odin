package main

import "core:fmt"
import "core:mem"
import "core:os"
import gl "vendor:OpenGL"
import "platform"
import "arena"

api: platform.Platform_Api

main :: proc() {
	main_arena, allocator, err := arena.init(1 * mem.Gigabyte)
	if err != nil {
		fmt.eprintfln("Buy more RAM lol!")
		os.exit(1)
	}
	defer arena.destroy(&main_arena)
	context.allocator = allocator

	{
		scratch_arena, temp_allocator := arena.begin_scratch(&main_arena.arena)
		defer arena.end_scratch(scratch_arena)
		context.temp_allocator = temp_allocator

		api.window.title = "Window Title"
		api.window.size = {960, 540}
		api.window.resizable = true
		api.opengl.major = 4
		api.opengl.minor = 6
		api.opengl.debug_context = true
		api.opengl.vsync = true

		if !platform.init(&api) {
			fmt.eprintln("Failed to initialize platform")
			os.exit(1)
		}
	}
	defer platform.shutdown()

	fmt.println("Platform & OpenGL initialized successfully!")
	fmt.println("Press 'V' to toggle VSync.")
	fmt.println("Press 'D' to trigger a deliberate OpenGL error for testing the debug context.")

	for !api.quit {
		scratch_arena, temp_allocator := arena.begin_scratch(&main_arena.arena)
		defer arena.end_scratch(scratch_arena)
		context.temp_allocator = temp_allocator

		platform.update()

		if api.keys[platform.Key_Code.Esc].is_pressed {
			api.quit = true
		}

		if api.keys[platform.Key_Code.V].is_pressed {
			api.opengl.vsync = !api.opengl.vsync
			fmt.printf("Toggled VSync. New state: %v\n", api.opengl.vsync)
		}

		if api.keys[platform.Key_Code.D].is_pressed {
			fmt.println("Triggering deliberate OpenGL error to test debug callback...")
			gl.Enable(0) // Invalid enum
		}

		gl.ClearColor(0.08, 0.08, 0.1, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		platform.swap_buffers()
	}
}



