package stats

import "core:fmt"
import "core:math"
import "core:mem"

TITLE_INTERVAL_MS :: u64(#config(MY_TEXT_ED_DEBUG_TITLE_INTERVAL_MS, 1000))
TITLE_BUF_SIZE :: 512

Memory_Stats :: struct {
	virtual_bytes:  u64,
	resident_bytes: u64,
	ok:             bool,
}

Frame_Stats :: struct {
	glyph_lookup_hits:   u64,
	glyph_lookup_misses: u64,
	glyphs_skipped:      u64,
	glyph_quads_emitted: u64,
	glyph_quads_dropped: u64,
}

Title_Input :: struct {
	now_ms:           u64,
	draw_width:       i32,
	draw_height:      i32,
	max_batch_glyphs: u32,
	memory:           Memory_Stats,
	arena_used:       uint,
	arena_reserved:   uint,
}

Debug_Title_State :: struct {
	buf:                 [TITLE_BUF_SIZE]byte,
	last_update_ms:      u64,
	frame_count:         u64,
	frame_ms_sum:        f64,
	frame_ms_min:        f32,
	frame_ms_max:        f32,
	glyph_lookup_hits:   u64,
	glyph_lookup_misses: u64,
	glyphs_skipped:      u64,
	glyph_quads_emitted: u64,
	glyph_quads_dropped: u64,
}

reset_sample :: proc(s: ^Debug_Title_State) {
	s.frame_count = 0
	s.frame_ms_sum = 0
	s.frame_ms_min = math.F32_MAX
	s.frame_ms_max = 0
	s.glyph_lookup_hits = 0
	s.glyph_lookup_misses = 0
	s.glyphs_skipped = 0
	s.glyph_quads_emitted = 0
	s.glyph_quads_dropped = 0
}

accumulate_frame :: proc(s: ^Debug_Title_State, frame_ms: f32, frame_stats: Frame_Stats) {
	s.frame_count += 1
	s.frame_ms_sum += f64(frame_ms)
	if frame_ms < s.frame_ms_min do s.frame_ms_min = frame_ms
	if frame_ms > s.frame_ms_max do s.frame_ms_max = frame_ms
	s.glyph_lookup_hits += frame_stats.glyph_lookup_hits
	s.glyph_lookup_misses += frame_stats.glyph_lookup_misses
	s.glyphs_skipped += frame_stats.glyphs_skipped
	s.glyph_quads_emitted += frame_stats.glyph_quads_emitted
	s.glyph_quads_dropped += frame_stats.glyph_quads_dropped
}

@(private)
format_bytes :: proc(buf: []byte, bytes: u64) -> string {
	if bytes >= mem.Gigabyte {
		return fmt.bprintf(buf, "%.1fGiB", f64(bytes) / f64(mem.Gigabyte))
	}
	return fmt.bprintf(buf, "%.1fMiB", f64(bytes) / f64(mem.Megabyte))
}

update_title :: proc(
	s: ^Debug_Title_State,
	input: Title_Input,
) -> string {
	elapsed_ms := input.now_ms - s.last_update_ms
	if elapsed_ms == 0 do elapsed_ms = 1
	elapsed_s := f64(elapsed_ms) / 1000.0

	fps := f64(s.frame_count) / elapsed_s
	avg_ms := s.frame_ms_sum / f64(s.frame_count) if s.frame_count > 0 else 0.0
	min_ms := s.frame_ms_min if s.frame_count > 0 else 0.0
	max_ms := s.frame_ms_max if s.frame_count > 0 else 0.0

	rss_buf: [32]byte
	vm_buf: [32]byte
	rss_str := "n/a"
	vm_str := "n/a"
	if input.memory.ok {
		rss_str = format_bytes(rss_buf[:], input.memory.resident_bytes)
		vm_str = format_bytes(vm_buf[:], input.memory.virtual_bytes)
	}

	arena_used_mib := f64(input.arena_used) / f64(mem.Megabyte)
	arena_reserved_mib := f64(input.arena_reserved) / f64(mem.Megabyte)

	glyph_lookups := s.glyph_lookup_hits + s.glyph_lookup_misses
	hit_rate := 100.0 * f64(s.glyph_lookup_hits) / f64(glyph_lookups) if glyph_lookups > 0 else 0.0
	glyph_rate := f64(glyph_lookups + s.glyphs_skipped) / elapsed_s
	glyph_rate_str: string
	glyph_rate_buf: [16]byte
	if glyph_rate >= 1000.0 {
		glyph_rate_str = fmt.bprintf(glyph_rate_buf[:], "%.0fk/s", glyph_rate / 1000.0)
	} else {
		glyph_rate_str = fmt.bprintf(glyph_rate_buf[:], "%.0f/s", glyph_rate)
	}

	avg_quads := f64(s.glyph_quads_emitted) / f64(s.frame_count) if s.frame_count > 0 else 0.0

	title := fmt.bprintf(
		s.buf[:],
		"my-text-ed | %.0f fps %.1fms avg %.1f-%.1f | mem rss %s vm %s arena %.1f/%.0fMiB | glyph %.1f%% %s q %.0f/%d | %dx%d",
		fps,
		avg_ms,
		min_ms,
		max_ms,
		rss_str,
		vm_str,
		arena_used_mib,
		arena_reserved_mib,
		hit_rate,
		glyph_rate_str,
		avg_quads,
		input.max_batch_glyphs,
		input.draw_width,
		input.draw_height,
	)

	s.last_update_ms = input.now_ms
	reset_sample(s)
	return title
}
