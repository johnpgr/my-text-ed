package renderer

import stbtt "vendor:stb/truetype"

Vec2f :: [2]f32
Color :: [4]f32

DEFAULT_FONT_PATH :: "/home/joao/.fonts/ComicCode/Comic Code Regular.otf"

BAND_TEXTURE_WIDTH_LOG2 :: 12
BAND_TEXTURE_WIDTH :: 1 << BAND_TEXTURE_WIDTH_LOG2 // 4096

CUBIC_TO_QUAD_TOLERANCE :: f32(0.001)
DILATION_SCALE :: f32(1.0)

Bezier_Curve :: struct #raw_union {
	p:           [3]Vec2f,
	using named: struct {
		start:   Vec2f,
		control: Vec2f,
		end:     Vec2f,
	},
}

Band :: struct {
	curve_count: u16,
	data_offset: u16,
}

Glyph_Data :: struct {
	bbox_min:      Vec2f,
	bbox_max:      Vec2f,
	advance_width: f32,
	left_bearing:  f32,

	curves:        [dynamic]Bezier_Curve,

	h_bands:       [dynamic]Band,
	v_bands:       [dynamic]Band,
	h_curve_lists: [dynamic]u16,
	v_curve_lists: [dynamic]u16,

	curve_tex_x:   u16,
	curve_tex_y:   u16,
	band_tex_x:    u16,
	band_tex_y:    u16,
	band_max_x:    u16,
	band_max_y:    u16,

	band_scale:    Vec2f,
	band_offset:   Vec2f,

	codepoint:     rune,
	glyph_index:   i32,
	valid:         bool,
}

Font :: struct {
	info:          stbtt.fontinfo,
	font_data:     []u8,

	ascent:        f32,
	descent:       f32,
	line_gap:      f32,
	em_scale:      f32,
	units_per_em:  f32,
	mono_advance:  f32,

	glyphs:        map[rune]Glyph_Data,
}

Texture_Pack_Result :: struct {
	curve_data:   [dynamic][4]u16,
	curve_width:  u32,
	curve_height: u32,
	band_data:    [dynamic][2]u16,
	band_width:   u32,
	band_height:  u32,
}
