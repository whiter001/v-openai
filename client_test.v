module openai

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

const mock_chat_body = '{"id":"chatcmpl-mock","object":"chat.completion","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"message":{"role":"assistant","content":"Hello!"},"finish_reason":"stop"}],"usage":{"prompt_tokens":8,"completion_tokens":11,"total_tokens":19}}'

const mock_stream_body = 'data: {"id":"chatcmpl-mock","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"delta":{"role":"assistant","content":"Hel"},"finish_reason":null}]}\n\ndata: {"id":"chatcmpl-mock","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"delta":{"content":"lo"},"finish_reason":null}]}\n\ndata: {"id":"chatcmpl-mock","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n'

fn test_create_chat_completion_against_a_loopback_server() {
	mock := start_mock_server('HTTP/1.1 200 OK', 'application/json', mock_chat_body)
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:  'sk-test'
		base_url: mock.base_url()
	)

	response := client.create_chat_completion(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [user_message('hi')]
	})!

	assert response.choices[0].message.content or { '' } == 'Hello!'
	assert response.usage.total_tokens == 19

	head := mock.request_head()
	assert head.len != 0
	assert head[0] == 'POST /v1/chat/completions HTTP/1.1'
	assert head.any(it.to_lower() == 'authorization: bearer sk-test')
	assert head.any(it.to_lower() == 'content-type: application/json')
}

// ChunkSink collects streamed content pieces for the stream test.
struct ChunkSink {
mut:
	pieces []string
}

fn sink_chunk(mut sink ChunkSink, chunk ChatCompletionChunk) {
	sink.pieces << chunk.choices[0].delta.content
}

fn test_create_chat_completion_stream_against_a_loopback_server() {
	mock := start_mock_server('HTTP/1.1 200 OK', 'text/event-stream', mock_stream_body)
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:  'sk-test'
		base_url: mock.base_url()
	)

	mut sink := &ChunkSink{}
	client.create_chat_completion_stream(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [user_message('hi')]
	}, sink, sink_chunk)!

	assert sink.pieces == ['Hel', 'lo', '']
}

fn test_http_error_is_decoded_into_an_api_error() {
	mock := start_mock_server('HTTP/1.1 429 Too Many Requests', 'application/json',
		'{"error":{"message":"slow down","type":"rate_limit_exceeded","code":"rate_limited"}}')
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:  'sk-test'
		base_url: mock.base_url()
	)

	client.create_chat_completion(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [user_message('hi')]
	}) or {
		api_err := err as ApiError
		assert api_err.status == 429
		assert api_err.code == 'rate_limited'
		assert api_err.message == 'slow down'
		return
	}
	assert false, 'expected an ApiError'
}
