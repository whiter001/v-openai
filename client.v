module openai

import net.http
import time

// ClientConfig configures a Client. Point `base_url` at any OpenAI-compatible
// endpoint (DeepSeek, Kimi, GLM, Ollama, ...) to use it instead of OpenAI.
pub struct ClientConfig {
pub:
	api_key      string @[required]
	base_url     string = 'https://api.openai.com/v1'
	organization string
	// read_timeout bounds reading one response; keep it generous, streams are
	// long-lived by design.
	read_timeout  i64 = 300 * time.second
	write_timeout i64 = 30 * time.second
	// headers are added to every request, e.g. provider specific keys.
	headers map[string]string
}

// Client is an OpenAI-compatible API client. It is safe to copy; all state
// lives in the config.
pub struct Client {
pub mut:
	config ClientConfig
}

// new_client creates a Client from a ClientConfig.
pub fn new_client(config ClientConfig) Client {
	return Client{
		config: config
	}
}

fn (c &Client) url(path string) string {
	return c.config.base_url.trim_right('/') + path
}

fn (c &Client) header() http.Header {
	mut header := http.new_header()
	header.set(.content_type, 'application/json')
	header.set(.authorization, 'Bearer ${c.config.api_key}')
	if c.config.organization != '' {
		header.set_custom('OpenAI-Organization', c.config.organization) or {}
	}
	header.add_custom_map(c.config.headers) or {}
	return header
}

// post sends a JSON POST and returns the response body. HTTP errors are
// decoded into ApiError.
fn (c &Client) post(path string, payload string) !string {
	response := http.fetch(
		method:        .post
		url:           c.url(path)
		data:          payload
		header:        c.header()
		read_timeout:  c.config.read_timeout
		write_timeout: c.config.write_timeout
	)!
	if response.status_code >= 400 {
		return decode_error_response(response.status_code, response.body)
	}
	return response.body
}

// StreamContext carries the caller's context and chunk callback through
// Request.user_ptr: net.http invokes plain function pointers for its
// streaming callbacks, so user state travels via the trampoline below.
// (Closures stored in struct fields lose their captured context, which is
// why the API takes an explicit context instead of a closure.)
struct StreamContext[T] {
mut:
	context  T
	on_chunk fn (T, string) = unsafe { nil }
}

fn stream_trampoline[T](req &http.Request, chunk []u8, _ u64, _ u64, _ int) ! {
	mut ctx := unsafe { &StreamContext[T](req.user_ptr) }
	ctx.on_chunk(ctx.context, chunk.bytestr())
}

// post_stream sends a JSON POST and forwards every response body chunk to
// `on_chunk` as it arrives, which is what `stream: true` endpoints need.
// Pass a reference type as `context` to observe mutations.
fn (c &Client) post_stream[T](path string, payload string, context T, on_chunk fn (T, string)) !string {
	mut ctx := &StreamContext[T]{
		context:  context
		on_chunk: on_chunk
	}
	response := http.fetch(
		method:           .post
		url:              c.url(path)
		data:             payload
		header:           c.header()
		read_timeout:     c.config.read_timeout
		write_timeout:    c.config.write_timeout
		user_ptr:         ctx
		on_progress_body: stream_trampoline[T]
	)!
	if response.status_code >= 400 {
		return decode_error_response(response.status_code, response.body)
	}
	return response.body
}
