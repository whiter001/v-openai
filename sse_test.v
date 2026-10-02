module openai

fn test_sse_feed_returns_complete_events_only() {
	mut parser := &SseParser{}
	assert parser.feed('data: one\n\nda') == ['one']
	assert parser.feed('ta: two\n\n') == ['two']
}

fn test_sse_feed_handles_frames_split_mid_line_and_mid_separator() {
	mut parser := &SseParser{}
	assert parser.feed('data: hel') == []
	assert parser.feed('lo wor') == []
	assert parser.feed('ld\n') == []
	assert parser.feed('\n') == ['hello world']
}

fn test_sse_feed_returns_multiple_events_from_one_chunk() {
	mut parser := &SseParser{}
	events := parser.feed('data: a\n\ndata: b\n\ndata: c\n\n')
	assert events == ['a', 'b', 'c']
}

fn test_sse_feed_joins_multi_line_data_and_ignores_comments() {
	mut parser := &SseParser{}
	events := parser.feed(': keep-alive\nevent: message\ndata: first\ndata: second\n\n')
	assert events == ['first\nsecond']
}

fn test_sse_feed_normalizes_crlf() {
	mut parser := &SseParser{}
	events := parser.feed('data: x\r\n\r\ndata: y\r\n\r\n')
	assert events == ['x', 'y']
}
