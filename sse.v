module openai

// SseParser incrementally reassembles server-sent-event frames from arbitrary
// chunks: TCP chunk boundaries do not align with event boundaries, so partial
// frames are buffered until the blank line that terminates an event arrives.
struct SseParser {
mut:
	buffer string
}

// feed appends a chunk and returns the `data` payloads of every event that
// became complete with it. Multi-line `data:` fields are joined with a
// newline, per the SSE spec; comment and control lines are ignored.
fn (mut parser SseParser) feed(chunk string) []string {
	parser.buffer += chunk.replace('\r\n', '\n').replace('\r', '\n')
	mut events := []string{}
	for {
		frame_end := parser.buffer.index('\n\n') or { break }
		frame := parser.buffer[..frame_end]
		parser.buffer = parser.buffer[frame_end + 2..]
		mut data_lines := []string{}
		for line in frame.split('\n') {
			if line.starts_with('data:') {
				mut value := line[5..]
				if value.starts_with(' ') {
					value = value[1..]
				}
				data_lines << value
			}
		}
		if data_lines.len != 0 {
			events << data_lines.join('\n')
		}
	}
	return events
}
