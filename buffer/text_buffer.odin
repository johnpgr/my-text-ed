package buffer

import "core:strings"
import "core:os"

Text_Buffer :: struct {
	filepath: string,
	content:  string,
	lines:    [dynamic]string,
}

load :: proc(path: string, allocator := context.allocator) -> (Text_Buffer, bool) {
	assert(path != "")
	buf: Text_Buffer
	buf.filepath = path

	data, err := os.read_entire_file(path, allocator)
	if err != nil {
		return {}, false
	}

	buf.content = string(data)

	buf.lines, err = make([dynamic]string, 0, allocator)
	if err != nil {
		delete(buf.content, allocator)
		return {}, false
	}

	content_copy := buf.content
	for line in strings.split_lines_iterator(&content_copy) {
		append(&buf.lines, line)
	}

	return buf, true
}

destroy :: proc(buf: ^Text_Buffer, allocator := context.allocator) {
	assert(buf != nil)
	delete(buf.content, allocator)
	delete(buf.lines)
	buf^ = {}
}

