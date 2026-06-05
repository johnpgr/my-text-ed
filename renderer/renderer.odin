package renderer

import rfont "font"

MAX_GLYPH_QUADS :: 4096
VERTICES_PER_QUAD :: 4
INDICES_PER_QUAD :: 6
MAX_GLYPH_VERTICES :: MAX_GLYPH_QUADS * VERTICES_PER_QUAD
MAX_GLYPH_INDICES :: MAX_GLYPH_QUADS * INDICES_PER_QUAD

DEFAULT_FONT_SIZE :: f32(18)
DEFAULT_FG :: Color{0.92, 0.92, 0.95, 1.0}
DEFAULT_BG :: Color{0.08, 0.08, 0.1, 1.0}

Slug_Vertex :: struct {
	pos: [4]f32,
	tex: [4]f32,
	jac: [4]f32,
	bnd: [4]f32,
	col: Color,
}

Renderer_Api :: struct {
	font: struct {
		path:       string,
		data:       rfont.Font,
		pack:       rfont.Texture_Pack_Result,
		glyph_count: int,
	},
	style: struct {
		font_size:    f32,
		fg:           Color,
		bg:           Color,
		line_spacing: f32,
	},
	view: struct {
		scroll_y: f32,
	},
	batch: struct {
		max_glyphs: u32,
		quad_count: u32,
		vertices:   [MAX_GLYPH_VERTICES]Slug_Vertex,
	},
	opengl: struct {
		program:       u32,
		vao:           u32,
		vbo:           u32,
		ibo:           u32,
		curve_tex:     u32,
		band_tex:      u32,
		mvp_loc:       i32,
		viewport_loc:  i32,
		curve_tex_loc: i32,
		band_tex_loc:  i32,
	},
	status: struct {
		loaded:      bool,
		initialized: bool,
		last_error:  string,
	},
	stats: struct {
		glyph_lookup_hits:   u64,
		glyph_lookup_misses: u64,
		glyphs_skipped:      u64,
		glyph_quads_emitted: u64,
		glyph_quads_dropped: u64,
	},
}

init :: proc(r: ^Renderer_Api, allocator := context.allocator) -> bool {
	assert(r != nil)
	r.status.last_error = ""

	if r.font.path == "" {
		r.font.path = rfont.DEFAULT_FONT_PATH
	}
	if r.style.font_size <= 0 {
		r.style.font_size = DEFAULT_FONT_SIZE
	}
	if r.style.fg[3] == 0 && r.style.fg[0] == 0 && r.style.fg[1] == 0 && r.style.fg[2] == 0 {
		r.style.fg = DEFAULT_FG
	}
	if r.style.bg[3] == 0 && r.style.bg[0] == 0 && r.style.bg[1] == 0 && r.style.bg[2] == 0 {
		r.style.bg = DEFAULT_BG
	}
	if r.style.line_spacing <= 0 {
		r.style.line_spacing = 1.0
	}
	if r.batch.max_glyphs == 0 {
		r.batch.max_glyphs = MAX_GLYPH_QUADS
	}

	loaded_font, font_ok := rfont.load(r.font.path, allocator)
	if !font_ok {
		r.status.last_error = "failed to load font"
		return false
	}
	r.font.data = loaded_font

	ascii_loaded := rfont.load_ascii(&r.font.data, allocator)
	if ascii_loaded == 0 {
		rfont.destroy(&r.font.data, allocator)
		r.status.last_error = "failed to load ASCII glyphs"
		return false
	}
	r.font.glyph_count = ascii_loaded

	r.font.pack = rfont.process(&r.font.data, allocator)
	r.status.loaded = true

	if !opengl_init(r) {
		rfont.pack_destroy(&r.font.pack)
		rfont.destroy(&r.font.data, allocator)
		r.status.loaded = false
		if r.status.last_error == "" {
			r.status.last_error = "OpenGL renderer initialization failed"
		}
		return false
	}

	r.status.initialized = true
	return true
}

shutdown :: proc(r: ^Renderer_Api, allocator := context.allocator) {
	assert(r != nil)
	opengl_shutdown(r)
	rfont.pack_destroy(&r.font.pack)
	rfont.destroy(&r.font.data, allocator)
	r^ = {}
}

begin :: proc(r: ^Renderer_Api) {
	assert(r != nil && r.status.initialized)
	r.batch.quad_count = 0
	r.stats = {}
}

draw_text_line :: proc(r: ^Renderer_Api, line: string, x, baseline_y: f32) {
	assert(r != nil && r.status.initialized)
	font_size := r.style.font_size
	color := r.style.fg
	pen_x := x

	for ch in line {
		if ch < 32 && ch != '\t' do continue

		if ch == '\t' {
			tab_w := r.font.data.mono_advance * font_size * 4
			rel := pen_x - x
			pen_x = x + (f32(int(rel / tab_w) + 1) * tab_w)
			continue
		}

		if ch > 126 {
			r.stats.glyphs_skipped += 1
			continue
		}

		g := rfont.get_glyph(&r.font.data, ch)
		if g == nil {
			r.stats.glyph_lookup_misses += 1
			pen_x += r.font.data.mono_advance * font_size
			continue
		}

		r.stats.glyph_lookup_hits += 1

		glyph_x := pen_x + g.bbox_min.x * font_size
		glyph_y := baseline_y - g.bbox_max.y * font_size
		glyph_w := (g.bbox_max.x - g.bbox_min.x) * font_size
		glyph_h := (g.bbox_max.y - g.bbox_min.y) * font_size

		if len(g.curves) > 0 {
			if r.batch.quad_count < r.batch.max_glyphs {
				emit_glyph_quad(r, g, glyph_x, glyph_y, glyph_w, glyph_h, color)
			} else {
				r.stats.glyph_quads_dropped += 1
			}
		}

		pen_x += g.advance_width * font_size
	}
}

flush :: proc(r: ^Renderer_Api, draw_size: [2]i32) {
	assert(r != nil)
	if !r.status.initialized do return
	opengl_flush(r, draw_size.x, draw_size.y)
}

line_height :: proc(r: ^Renderer_Api) -> f32 {
	assert(r != nil && r.status.loaded)
	return rfont.metrics_line_height(&r.font.data, r.style.font_size, r.style.line_spacing)
}

@(private = "file")
emit_glyph_quad :: proc(
	r: ^Renderer_Api,
	g: ^rfont.Glyph_Data,
	x, y, w, h: f32,
	color: Color,
) {
	assert(r != nil && g != nil)
	assert(r.batch.quad_count < r.batch.max_glyphs)
	base := r.batch.quad_count * VERTICES_PER_QUAD
	if base + VERTICES_PER_QUAD > MAX_GLYPH_VERTICES do return

	em_min := g.bbox_min
	em_max := g.bbox_max

	glyph_loc := transmute(f32)(u32(g.band_tex_x) | (u32(g.band_tex_y) << 16))
	band_max := transmute(f32)(u32(g.band_max_x) | (u32(g.band_max_y) << 16))

	em_w := em_max.x - em_min.x
	em_h := em_max.y - em_min.y
	jac_00 := em_w / w if w > 0 else 0
	jac_11 := -(em_h / h) if h > 0 else 0

	corners := [4][2]f32 {
		{x, y},
		{x + w, y},
		{x + w, y + h},
		{x, y + h},
	}

	normals := [4][2]f32 {
		{-rfont.DILATION_SCALE, -rfont.DILATION_SCALE},
		{rfont.DILATION_SCALE, -rfont.DILATION_SCALE},
		{rfont.DILATION_SCALE, rfont.DILATION_SCALE},
		{-rfont.DILATION_SCALE, rfont.DILATION_SCALE},
	}

	em_coords := [4][2]f32 {
		{em_min.x, em_max.y},
		{em_max.x, em_max.y},
		{em_max.x, em_min.y},
		{em_min.x, em_min.y},
	}

	for vi in 0 ..< 4 {
		r.batch.vertices[base + u32(vi)] = Slug_Vertex {
			pos = {corners[vi].x, corners[vi].y, normals[vi].x, normals[vi].y},
			tex = {em_coords[vi].x, em_coords[vi].y, glyph_loc, band_max},
			jac = {jac_00, 0, 0, jac_11},
			bnd = {g.band_scale.x, g.band_scale.y, g.band_offset.x, g.band_offset.y},
			col = color,
		}
	}

	r.batch.quad_count += 1
	r.stats.glyph_quads_emitted += 1
}
