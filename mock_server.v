module openai

// Test helpers. This file is compiled into every test binary (V test files
// do not see each other), and stays private to the module.

import io
import net
import time

// MockServer is a one-shot HTTP server on a loopback port: it records the
// request head, then replies with a fixed response.
struct MockServer {
mut:
	listener      &net.TcpListener
	request_lines chan string
}

const mock_chat_body = '{"id":"chatcmpl-mock","object":"chat.completion","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"message":{"role":"assistant","content":"Hello!"},"finish_reason":"stop"}],"usage":{"prompt_tokens":8,"completion_tokens":11,"total_tokens":19}}'

const mock_stream_body = 'data: {"id":"chatcmpl-mock","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"delta":{"role":"assistant","content":"Hel"},"finish_reason":null}]}\n\ndata: {"id":"chatcmpl-mock","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"delta":{"content":"lo"},"finish_reason":null}]}\n\ndata: {"id":"chatcmpl-mock","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n'

fn start_mock_server(status_line string, content_type string, response_body string) &MockServer {
	mut listener := net.listen_tcp(.ip, ':0') or { panic(err) }
	mut mock := &MockServer{
		listener:      listener
		// Roomy enough for several HTTP client retries; a full channel would
		// deadlock the serve thread against the client's response wait.
		request_lines: chan string{cap: 512}
	}
	spawn mock.serve(status_line, content_type, response_body)
	return mock
}

fn (mut mock MockServer) serve(status_line string, content_type string, response_body string) {
	// Serve until the listener is closed: the HTTP client may legitimately
	// open more than one connection (retries, pool probes).
	for {
		mut conn := mock.listener.accept() or { break }
		mock.serve_one(mut conn, status_line, content_type, response_body)
		conn.close() or {}
	}
}

fn (mut mock MockServer) serve_one(mut conn net.TcpConn, status_line string, content_type string, response_body string) {
	mut reader := io.new_buffered_reader(reader: conn)
	mut content_length := 0
	mut first := true
	for {
		line := reader.read_line() or { break }
		trimmed := line.trim_right('\r\n')
		if trimmed == '' {
			break
		}
		if trimmed.to_lower().starts_with('content-length:') {
			content_length = trimmed.all_after(':').trim_space().int()
		}
		if first {
			first = false
			eprintln('[mock ${mock.listener.addr() or { return }}] ${trimmed}')
		}
		mock.request_lines <- trimmed
	}
	// Drain the request body before responding: closing an exchange with
	// unread request bytes lets the kernel RST the connection, which eats
	// the response on some platforms.
	if content_length > 0 {
		mut drain := []u8{len: 4096}
		mut remaining := content_length
		for remaining > 0 {
			n := reader.read(mut drain) or { break }
			if n == 0 {
				break
			}
			remaining -= n
		}
	}
	response := '${status_line}\r\nContent-Type: ${content_type}\r\nContent-Length: ${response_body.len}\r\nConnection: close\r\n\r\n${response_body}'
	conn.write_string(response) or {}
}

fn (mock &MockServer) base_url() string {
	port := mock.listener.addr() or { panic(err) }.port() or { panic(err) }
	return 'http://127.0.0.1:${port}/v1'
}

// request_head drains the recorded request lines.
fn (mock &MockServer) request_head() []string {
	mut head := []string{}
	for {
		select {
			line := <-mock.request_lines {
				head << line
			}
			300 * time.millisecond {
				break
			}
		}
	}
	return head
}
