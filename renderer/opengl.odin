package renderer

import "core:math/linalg"
import gl "vendor:OpenGL"

VERTEX_SIZE :: size_of(Slug_Vertex)
ATTRIB_COUNT :: 5

@(private = "package")
opengl_init :: proc(r: ^Renderer_Api) -> bool {
	assert(r != nil && r.status.loaded)
	program, program_ok := gl.load_shaders_source(VERTEX_SHADER_SOURCE, FRAGMENT_SHADER_SOURCE)
	if !program_ok {
		r.status.last_error = "shader compile or link failed"
		return false
	}
	r.opengl.program = program

	r.opengl.mvp_loc = gl.GetUniformLocation(program, "mvp")
	r.opengl.viewport_loc = gl.GetUniformLocation(program, "viewport")
	r.opengl.curve_tex_loc = gl.GetUniformLocation(program, "curveTexture")
	r.opengl.band_tex_loc = gl.GetUniformLocation(program, "bandTexture")

	gl.GenVertexArrays(1, &r.opengl.vao)
	gl.BindVertexArray(r.opengl.vao)

	gl.GenBuffers(1, &r.opengl.vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, r.opengl.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, MAX_GLYPH_VERTICES * VERTEX_SIZE, nil, gl.DYNAMIC_DRAW)

	for i in u32(0) ..< ATTRIB_COUNT {
		gl.EnableVertexAttribArray(i)
		gl.VertexAttribPointer(
			i,
			4,
			gl.FLOAT,
			false,
			i32(VERTEX_SIZE),
			uintptr(i * 16),
		)
	}

	gl.GenBuffers(1, &r.opengl.ibo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, r.opengl.ibo)

	indices: [MAX_GLYPH_INDICES]u32
	for q in 0 ..< MAX_GLYPH_QUADS {
		base := u32(q) * 4
		off := q * 6
		indices[off + 0] = base + 0
		indices[off + 1] = base + 1
		indices[off + 2] = base + 2
		indices[off + 3] = base + 2
		indices[off + 4] = base + 3
		indices[off + 5] = base + 0
	}

	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		MAX_GLYPH_INDICES * size_of(u32),
		&indices,
		gl.STATIC_DRAW,
	)

	gl.BindVertexArray(0)

	if !upload_textures(r) {
		opengl_shutdown(r)
		return false
	}

	return true
}

@(private = "package")
upload_textures :: proc(r: ^Renderer_Api) -> bool {
	pack := &r.font.pack

	gl.GenTextures(1, &r.opengl.curve_tex)
	gl.BindTexture(gl.TEXTURE_2D, r.opengl.curve_tex)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.NEAREST))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.NEAREST))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		i32(gl.RGBA16F),
		i32(pack.curve_width),
		i32(pack.curve_height),
		0,
		gl.RGBA,
		gl.HALF_FLOAT,
		raw_data(pack.curve_data[:]),
	)

	gl.GenTextures(1, &r.opengl.band_tex)
	gl.BindTexture(gl.TEXTURE_2D, r.opengl.band_tex)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.NEAREST))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.NEAREST))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		i32(gl.RG16UI),
		i32(pack.band_width),
		i32(pack.band_height),
		0,
		gl.RG_INTEGER,
		gl.UNSIGNED_SHORT,
		raw_data(pack.band_data[:]),
	)

	gl.BindTexture(gl.TEXTURE_2D, 0)
	return true
}

@(private = "package")
opengl_flush :: proc(r: ^Renderer_Api, width, height: i32) {
	assert(r != nil && r.status.initialized)
	assert(r.opengl.program != 0)
	assert(width > 0 && height > 0)
	quad_count := r.batch.quad_count
	if quad_count == 0 do return

	vert_count := int(quad_count * VERTICES_PER_QUAD)
	w := f32(width)
	h := f32(height)

	proj := linalg.matrix_ortho3d_f32(0, w, h, 0, -1, 1)

	gl.Viewport(0, 0, width, height)
	gl.Disable(gl.CULL_FACE)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Disable(gl.DEPTH_TEST)
	gl.Enable(gl.FRAMEBUFFER_SRGB)

	gl.UseProgram(r.opengl.program)
	gl.UniformMatrix4fv(r.opengl.mvp_loc, 1, false, &proj[0][0])
	gl.Uniform2f(r.opengl.viewport_loc, w, h)

	gl.BindVertexArray(r.opengl.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, r.opengl.vbo)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, vert_count * VERTEX_SIZE, &r.batch.vertices[0])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, r.opengl.curve_tex)
	gl.Uniform1i(r.opengl.curve_tex_loc, 0)

	gl.ActiveTexture(gl.TEXTURE0 + 1)
	gl.BindTexture(gl.TEXTURE_2D, r.opengl.band_tex)
	gl.Uniform1i(r.opengl.band_tex_loc, 1)

	index_count := quad_count * INDICES_PER_QUAD
	gl.DrawElements(gl.TRIANGLES, i32(index_count), gl.UNSIGNED_INT, nil)

	gl.BindVertexArray(0)
	gl.UseProgram(0)
	gl.Disable(gl.FRAMEBUFFER_SRGB)
}

@(private = "package")
opengl_shutdown :: proc(r: ^Renderer_Api) {
	if r.opengl.band_tex != 0 {
		gl.DeleteTextures(1, &r.opengl.band_tex)
	}
	if r.opengl.curve_tex != 0 {
		gl.DeleteTextures(1, &r.opengl.curve_tex)
	}
	if r.opengl.ibo != 0 {
		gl.DeleteBuffers(1, &r.opengl.ibo)
	}
	if r.opengl.vbo != 0 {
		gl.DeleteBuffers(1, &r.opengl.vbo)
	}
	if r.opengl.vao != 0 {
		gl.DeleteVertexArrays(1, &r.opengl.vao)
	}
	if r.opengl.program != 0 {
		gl.DeleteProgram(r.opengl.program)
	}
	r.opengl = {}
}
