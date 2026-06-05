package main

import "arena"
import "buffer"
import "core:fmt"
import "core:mem"
import "core:os"
import "platform"
import "renderer"
import "core:mem/virtual"
import gl "vendor:OpenGL"

api: platform.Platform_Api
r_api: renderer.Renderer_Api

FALLBACK_TEXT :: "my-text-ed: pass a file path to render text (e.g. TODO.md)"

main :: proc() {
	main_arena: virtual.Arena
	allocator, err := arena.init(&main_arena, 1 * mem.Gigabyte)
	if err != nil {
		fmt.eprintfln("Buy more RAM lol!")
		os.exit(1)
	}
	defer arena.destroy(&main_arena)
	context.allocator = allocator

	text_buf: buffer.Text_Buffer
	has_file := false

	if len(os.args) > 1 {
		path := os.args[1]
		ok: bool
		text_buf, ok = buffer.load(path, allocator)
		if !ok {
			fmt.eprintfln("Failed to load file: %s", path)
			os.exit(1)
		}
		has_file = true
	}
	defer {
		if has_file {
			buffer.destroy(&text_buf, allocator)
		}
	}

	{
		scratch_arena, temp_allocator := arena.begin_scratch(&main_arena.arena)
		defer arena.end_scratch(scratch_arena)
		context.temp_allocator = temp_allocator

		api.window.title = "my-text-ed"
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

	r_api.style.font_size = 18
	r_api.style.fg = {0.92, 0.92, 0.95, 1.0}
	r_api.style.bg = {0.08, 0.08, 0.1, 1.0}
	r_api.style.line_spacing = 1.0

	if !renderer.init(&r_api, allocator) {
		fmt.eprintln(r_api.status.last_error)
		os.exit(1)
	}
	defer renderer.shutdown(&r_api, allocator)

	fmt.println("Platform & OpenGL initialized successfully!")
	fmt.printf("Loaded %d ASCII glyphs from %s\n", r_api.font.glyph_count, r_api.font.path)
	fmt.println("Press 'V' to toggle VSync. Esc to quit.")
	if has_file {
		fmt.printf("Rendering %d lines from %s\n", len(text_buf.lines), text_buf.filepath)
	} else {
		fmt.println(FALLBACK_TEXT)
	}

	scroll_page_lines: f32 = 20

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

		line_h := renderer.line_height(&r_api)
		scroll_delta: f32 = 0

		if api.mouse.wheel_delta != 0 {
			scroll_delta -= api.mouse.wheel_delta * line_h * 3
		}
		if api.keys[platform.Key_Code.Page_Up].is_pressed {
			scroll_delta -= line_h * scroll_page_lines
		}
		if api.keys[platform.Key_Code.Page_Down].is_pressed {
			scroll_delta += line_h * scroll_page_lines
		}

		r_api.view.scroll_y += scroll_delta

		line_count := 1
		if has_file {
			line_count = len(text_buf.lines)
		}

		content_height := f32(line_count) * line_h
		max_scroll := max(0, content_height - f32(api.draw.size.y))
		r_api.view.scroll_y = clamp(r_api.view.scroll_y, 0, max_scroll)

		bg := r_api.style.bg
		gl.ClearColor(bg[0], bg[1], bg[2], bg[3])
		gl.Clear(gl.COLOR_BUFFER_BIT)

		renderer.begin(&r_api)

		margin_x: f32 = 8
		first_line := int(r_api.view.scroll_y / line_h)
		overscan := 1
		last_line := min(
			line_count - 1,
			first_line + int(f32(api.draw.size.y) / line_h) + overscan,
		)

		for line_idx in first_line ..= last_line {
			baseline_y :=
				f32(line_idx) * line_h -
				r_api.view.scroll_y +
				r_api.font.data.ascent * r_api.style.font_size

			if has_file {
				renderer.draw_text_line(&r_api, text_buf.lines[line_idx], margin_x, baseline_y)
			} else if line_idx == 0 {
				renderer.draw_text_line(&r_api, FALLBACK_TEXT, margin_x, baseline_y)
			}
		}

		renderer.flush(&r_api, api.draw.size)
		platform.swap_buffers()
	}
}
