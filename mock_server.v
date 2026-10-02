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

fn start_mock_server(status_line string, content_type string, response_body string) &MockServer {
	mut listener := net.listen_tcp(.ip, ':0') or { panic(err) }
	mock := &MockServer{
		listener:      listener
		request_lines: chan string{cap: 32}
	}
	spawn mock.serve(status_line, content_type, response_body)
	return mock
}

fn (mut mock MockServer) serve(status_line string, content_type string, response_body string) {
	mut conn := mock.listener.accept() or { return }
	defer {
		conn.close() or {}
	}
	mut reader := io.new_buffered_reader(reader: conn)
	for {
		line := reader.read_line() or { break }
		trimmed := line.trim_right('\r\n')
		if trimmed == '' {
			break
		}
		mock.request_lines <- trimmed
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
