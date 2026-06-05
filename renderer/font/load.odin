package font

import "core:c"
import "core:os"
import stbtt "vendor:stb/truetype"

STBTT_VMOVE :: 1
STBTT_VLINE :: 2
STBTT_VCURVE :: 3
STBTT_VCUBIC :: 4

load :: proc(path: string, allocator := context.allocator) -> (font: Font, ok: bool) {
	data, read_err := os.read_entire_file(path, allocator)
	if read_err != nil {
		return {}, false
	}
	font.font_data = data

	info := &font.info
	if stbtt.InitFont(info, raw_data(data), 0) == false {
		delete(data, allocator)
		return {}, false
	}

	units_per_em := read_units_per_em(data)
	if units_per_em <= 0 {
		ascent_raw, descent_raw: c.int
		stbtt.GetFontVMetrics(info, &ascent_raw, &descent_raw, nil)
		units_per_em = f32(ascent_raw - descent_raw)
		if units_per_em <= 0 do units_per_em = 1000
	}
	font.units_per_em = units_per_em
	font.em_scale = 1.0 / units_per_em

	ascent_raw, descent_raw, line_gap_raw: c.int
	stbtt.GetFontVMetrics(info, &ascent_raw, &descent_raw, &line_gap_raw)
	font.ascent = f32(ascent_raw) * font.em_scale
	font.descent = f32(descent_raw) * font.em_scale
	font.line_gap = f32(line_gap_raw) * font.em_scale

	return font, true
}

load_glyph :: proc(font: ^Font, codepoint: rune, allocator := context.allocator) -> bool {
	if existing, found := &font.glyphs[codepoint]; found && existing.valid {
		return true
	}

	if font.glyphs == nil {
		font.glyphs = make(map[rune]Glyph_Data, 128, allocator)
	}

	font.glyphs[codepoint] = {}
	g := &font.glyphs[codepoint]

	info := &font.info
	glyph_index := stbtt.FindGlyphIndex(info, codepoint)
	if glyph_index == 0 && codepoint != 0 {
		return false
	}

	g.codepoint = codepoint
	g.glyph_index = c.int(glyph_index)

	advance_raw, lsb_raw: c.int
	stbtt.GetGlyphHMetrics(info, c.int(glyph_index), &advance_raw, &lsb_raw)
	g.advance_width = f32(advance_raw) * font.em_scale
	g.left_bearing = f32(lsb_raw) * font.em_scale

	x0, y0, x1, y1: c.int
	if stbtt.GetGlyphBox(info, c.int(glyph_index), &x0, &y0, &x1, &y1) == 0 {
		g.bbox_min = {0, 0}
		g.bbox_max = {g.advance_width, font.ascent - font.descent}
		g.valid = true
		return true
	}

	g.bbox_min = {f32(x0) * font.em_scale, f32(y0) * font.em_scale}
	g.bbox_max = {f32(x1) * font.em_scale, f32(y1) * font.em_scale}

	extract_glyph_shape(g, info, c.int(glyph_index), font.em_scale)
	g.valid = true
	return true
}

load_ascii :: proc(font: ^Font, allocator := context.allocator) -> int {
	return load_range(font, 32, 126, allocator)
}

load_range :: proc(font: ^Font, first, last: rune, allocator := context.allocator) -> int {
	loaded := 0
	for cp := first; cp <= last; cp += 1 {
		if load_glyph(font, cp, allocator) {
			loaded += 1
		}
	}
	update_mono_advance(font)
	return loaded
}

update_mono_advance :: proc(font: ^Font) {
	max_advance: f32 = 0
	for _, &g in font.glyphs {
		if g.valid && g.advance_width > max_advance {
			max_advance = g.advance_width
		}
	}
	font.mono_advance = max_advance
}

get_glyph :: proc(font: ^Font, ch: rune) -> ^Glyph_Data {
	g, ok := &font.glyphs[ch]
	if !ok || !g.valid do return nil
	return g
}

metrics_line_height :: proc(font: ^Font, font_size: f32, line_spacing: f32 = 1.0) -> f32 {
	return (font.ascent - font.descent + font.line_gap) * font_size * line_spacing
}

glyph_destroy :: proc(g: ^Glyph_Data) {
	delete(g.curves)
	delete(g.h_bands)
	delete(g.v_bands)
	delete(g.h_curve_lists)
	delete(g.v_curve_lists)
	g^ = {}
}

destroy :: proc(font: ^Font, allocator := context.allocator) {
	for _, &g in font.glyphs {
		glyph_destroy(&g)
	}
	delete(font.glyphs)
	delete(font.font_data, allocator)
	font^ = {}
}

pack_destroy :: proc(pack: ^Texture_Pack_Result) {
	delete(pack.curve_data)
	delete(pack.band_data)
	pack^ = {}
}

@(private = "file")
extract_glyph_shape :: proc(g: ^Glyph_Data, info: ^stbtt.fontinfo, glyph_index: c.int, em_scale: f32) {
	vertices: [^]stbtt.vertex
	num_vertices := stbtt.GetGlyphShape(info, glyph_index, &vertices)
	if num_vertices <= 0 do return
	defer stbtt.FreeShape(info, vertices)

	verts := vertices[:num_vertices]

	contour_start: Vec2f
	contour_start_set: bool
	current: Vec2f
	current_set: bool

	for i in 0 ..< len(verts) {
		v := verts[i]

		switch v.type {
		case STBTT_VMOVE:
			if contour_start_set && current_set {
				current = close_glyph_contour(g, current, contour_start)
			}
			current = {f32(v.x) * em_scale, f32(v.y) * em_scale}
			contour_start = current
			contour_start_set = true
			current_set = true

		case STBTT_VLINE:
			if !current_set do continue
			p1 := current
			p3 := Vec2f{f32(v.x) * em_scale, f32(v.y) * em_scale}
			p2 := (p1 + p3) * 0.5
			append_bezier(g, p1, p2, p3)
			current = p3

		case STBTT_VCURVE:
			if !current_set do continue
			p1 := current
			p2 := Vec2f{f32(v.cx) * em_scale, f32(v.cy) * em_scale}
			p3 := Vec2f{f32(v.x) * em_scale, f32(v.y) * em_scale}
			append_bezier(g, p1, p2, p3)
			current = p3

		case STBTT_VCUBIC:
			if !current_set do continue
			cp0 := current
			cp1 := Vec2f{f32(v.cx) * em_scale, f32(v.cy) * em_scale}
			cp2 := Vec2f{f32(v.cx1) * em_scale, f32(v.cy1) * em_scale}
			cp3 := Vec2f{f32(v.x) * em_scale, f32(v.y) * em_scale}
			cubic_to_quadratics(cp0, cp1, cp2, cp3, &g.curves, CUBIC_TO_QUAD_TOLERANCE)
			current = cp3
		}
	}

	if contour_start_set && current_set {
		close_glyph_contour(g, current, contour_start)
	}
}

@(private = "file")
append_bezier :: proc(g: ^Glyph_Data, p1, p2, p3: Vec2f) {
	curve: Bezier_Curve
	curve.start = p1
	curve.control = p2
	curve.end = p3
	append(&g.curves, curve)
}

@(private = "file")
close_glyph_contour :: proc(g: ^Glyph_Data, current, contour_start: Vec2f) -> Vec2f {
	if current == contour_start do return current
	p1 := current
	p3 := contour_start
	p2 := (p1 + p3) * 0.5
	append_bezier(g, p1, p2, p3)
	return p3
}

@(private = "file")
cubic_to_quadratics :: proc(
	p0, p1, p2, p3: Vec2f,
	output: ^[dynamic]Bezier_Curve,
	tolerance: f32,
	depth: int = 0,
) {
	MAX_DEPTH :: 8

	mid01 := (p0 + p1) * 0.5
	mid12 := (p1 + p2) * 0.5
	mid23 := (p2 + p3) * 0.5
	mid012 := (mid01 + mid12) * 0.5
	mid123 := (mid12 + mid23) * 0.5
	cubic_mid := (mid012 + mid123) * 0.5

	q1 := (p1 * 3.0 - p0 + p2 * 3.0 - p3) * 0.25
	quad_mid := (p0 + q1 * 2.0 + p3) * 0.25

	err := cubic_mid - quad_mid
	error_sq := err.x * err.x + err.y * err.y

	if error_sq <= tolerance * tolerance || depth >= MAX_DEPTH {
		curve: Bezier_Curve
		curve.start = p0
		curve.control = q1
		curve.end = p3
		append(output, curve)
		return
	}

	cubic_to_quadratics(p0, mid01, mid012, cubic_mid, output, tolerance, depth + 1)
	cubic_to_quadratics(cubic_mid, mid123, mid23, p3, output, tolerance, depth + 1)
}

@(private = "file")
read_units_per_em :: proc(font_data: []u8) -> f32 {
	if len(font_data) < 12 do return 0

	num_tables := read_u16_be(font_data, 4)
	for i in 0 ..< int(num_tables) {
		entry_offset := 12 + i * 16
		if entry_offset + 16 > len(font_data) do break

		tag := read_u32_be(font_data, entry_offset)
		if tag != 0x68656164 do continue // 'head'

		table_offset := int(read_u32_be(font_data, entry_offset + 8))
		table_length := int(read_u32_be(font_data, entry_offset + 12))
		if table_length < 20 || table_offset + 20 > len(font_data) do return 0

		return f32(read_u16_be(font_data, table_offset + 18))
	}
	return 0
}

@(private = "file")
read_u16_be :: proc(data: []u8, offset: int) -> u16 {
	return u16(data[offset]) << 8 | u16(data[offset + 1])
}

@(private = "file")
read_u32_be :: proc(data: []u8, offset: int) -> u32 {
	return u32(data[offset]) << 24 |
	       u32(data[offset + 1]) << 16 |
	       u32(data[offset + 2]) << 8 |
	       u32(data[offset + 3])
}
