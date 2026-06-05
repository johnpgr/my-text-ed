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

p: platform.Platform_Api
r: renderer.Renderer_Api

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
		scratch_arena, temp_allocator := arena.begin_scratch(&main_arena)
		defer arena.end_scratch(scratch_arena)
		context.temp_allocator = temp_allocator

		p.window.title = "my-text-ed"
		p.window.size = {960, 540}
		p.window.resizable = true
		p.opengl.major = 4
		p.opengl.minor = 6
		p.opengl.debug_context = true
		p.opengl.vsync = true

		if !platform.init(&p) {
			fmt.eprintln("Failed to initialize platform")
			os.exit(1)
		}
	}

	defer platform.shutdown()

	r.style.font_size = 18
	r.style.fg = {0.92, 0.92, 0.95, 1.0}
	r.style.bg = {0.08, 0.08, 0.1, 1.0}
	r.style.line_spacing = 1.0

	if !renderer.init(&r, allocator) {
		fmt.eprintln(r.status.last_error)
		os.exit(1)
	}
	defer renderer.shutdown(&r, allocator)

	fmt.println("Platform & OpenGL initialized successfully!")
	fmt.printf("Loaded %d ASCII glyphs from %s\n", r.font.glyph_count, r.font.path)
	fmt.println("Press 'V' to toggle VSync. Esc to quit.")

	scroll_page_lines: f32 = 20

	for !p.quit {
		scratch_arena, temp_allocator := arena.begin_scratch(&main_arena)
		defer arena.end_scratch(scratch_arena)
		context.temp_allocator = temp_allocator

		platform.update()

		if p.keys[platform.Key_Code.Esc].is_pressed {
			p.quit = true
		}

		if p.keys[platform.Key_Code.V].is_pressed {
			p.opengl.vsync = !p.opengl.vsync
			fmt.printf("Toggled VSync. New state: %v\n", p.opengl.vsync)
		}

		line_h := renderer.line_height(&r)
		scroll_delta: f32 = 0

		if p.mouse.wheel_delta != 0 {
			scroll_delta -= p.mouse.wheel_delta * line_h * 3
		}
		if p.keys[platform.Key_Code.Page_Up].is_pressed {
			scroll_delta -= line_h * scroll_page_lines
		}
		if p.keys[platform.Key_Code.Page_Down].is_pressed {
			scroll_delta += line_h * scroll_page_lines
		}

		r.view.scroll_y += scroll_delta

		line_count := 1
		if has_file {
			line_count = len(text_buf.lines)
		}

		content_height := f32(line_count) * line_h
		max_scroll := max(0, content_height - f32(p.draw.size.y))
		r.view.scroll_y = clamp(r.view.scroll_y, 0, max_scroll)

		bg := r.style.bg
		gl.ClearColor(bg[0], bg[1], bg[2], bg[3])
		gl.Clear(gl.COLOR_BUFFER_BIT)

		renderer.begin(&r)

		margin_x: f32 = 8
		first_line := int(r.view.scroll_y / line_h)
		overscan := 1
		last_line := min(
			line_count - 1,
			first_line + int(f32(p.draw.size.y) / line_h) + overscan,
		)

		for line_idx in first_line ..= last_line {
			baseline_y :=
				f32(line_idx) * line_h -
				r.view.scroll_y +
				r.font.data.ascent * r.style.font_size

			if has_file {
				renderer.draw_text_line(&r, text_buf.lines[line_idx], margin_x, baseline_y)
			} else if line_idx == 0 {
				renderer.draw_text_line(&r, FALLBACK_TEXT, margin_x, baseline_y)
			}
		}

		renderer.flush(&r, p.draw.size)
		platform.swap_buffers()
	}
}
