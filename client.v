module openai

import net.http
import net.urllib
import time

// AuthStyle selects how the API key is sent: the usual
// `Authorization: Bearer` header, or Azure's `api-key` header.
pub enum AuthStyle {
	bearer
	api_key
}

// ClientConfig configures a Client. Point `base_url` at any OpenAI-compatible
// endpoint (DeepSeek, Kimi, GLM, Ollama, ...) to use it instead of OpenAI.
pub struct ClientConfig {
pub:
	api_key      string @[required]
	base_url     string = 'https://api.openai.com/v1'
	organization string
	auth_style   AuthStyle = .bearer
	// query_params are appended to every request URL (Azure's api-version).
	query_params map[string]string
	// read_timeout bounds reading one response; keep it generous, streams are
	// long-lived by design.
	read_timeout  i64 = 300 * time.second
	write_timeout i64 = 30 * time.second
	// headers are added to every request, e.g. provider specific keys.
	headers map[string]string
	// disable_connection_reuse opens a fresh connection per request instead
	// of using net.http's keep-alive pool.
	disable_connection_reuse bool
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
	url := c.config.base_url.trim_right('/') + path
	if c.config.query_params.len == 0 {
		return url
	}
	mut pairs := []string{cap: c.config.query_params.len}
	for key, value in c.config.query_params {
		pairs << '${urllib.query_escape(key)}=${urllib.query_escape(value)}'
	}
	return '${url}?${pairs.join('&')}'
}

fn (c &Client) header() http.Header {
	mut header := http.new_header()
	header.set(.content_type, 'application/json')
	match c.config.auth_style {
		.bearer {
			header.set(.authorization, 'Bearer ${c.config.api_key}')
		}
		.api_key {
			header.set_custom('api-key', c.config.api_key) or {}
		}
	}
	if c.config.organization != '' {
		header.set_custom('OpenAI-Organization', c.config.organization) or {}
	}
	header.add_custom_map(c.config.headers) or {}
	return header
}

// get sends a GET and returns the response body. HTTP errors are decoded
// into ApiError.
fn (c &Client) get(path string) !string {
	response := http.fetch(
		method:                   .get
		url:                      c.url(path)
		header:                   c.header()
		read_timeout:             c.config.read_timeout
		write_timeout:            c.config.write_timeout
		disable_connection_reuse: c.config.disable_connection_reuse
	)!
	if response.status_code >= 400 {
		return decode_error_response(response.status_code, response.body)
	}
	return response.body
}

// delete sends a DELETE and returns the response body.
fn (c &Client) delete(path string) !string {
	response := http.fetch(
		method:                   .delete
		url:                      c.url(path)
		header:                   c.header()
		read_timeout:             c.config.read_timeout
		write_timeout:            c.config.write_timeout
		disable_connection_reuse: c.config.disable_connection_reuse
	)!
	if response.status_code >= 400 {
		return decode_error_response(response.status_code, response.body)
	}
	return response.body
}

// post_with_content_type posts a pre-encoded body with an explicit content
// type (multipart uploads).
fn (c &Client) post_with_content_type(path string, payload string, content_type string) !string {
	mut header := c.header()
	header.set(.content_type, content_type)
	response := http.fetch(
		method:                   .post
		url:                      c.url(path)
		data:                     payload
		header:                   header
		read_timeout:             c.config.read_timeout
		write_timeout:            c.config.write_timeout
		disable_connection_reuse: c.config.disable_connection_reuse
	)!
	if response.status_code >= 400 {
		return decode_error_response(response.status_code, response.body)
	}
	return response.body
}

// post sends a JSON POST and returns the response body. HTTP errors are
// decoded into ApiError.
fn (c &Client) post(path string, payload string) !string {
	response := http.fetch(
		method:                   .post
		url:                      c.url(path)
		data:                     payload
		header:                   c.header()
		read_timeout:             c.config.read_timeout
		write_timeout:            c.config.write_timeout
		disable_connection_reuse: c.config.disable_connection_reuse
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
// why the API takes an explicit context instead of a closure. Everything
// past this boundary is type-erased: passing a generic fn as a value does
// not compile on older V versions.)
struct StreamContext {
mut:
	context  voidptr
	on_chunk fn (voidptr, string) = unsafe { nil }
}

fn stream_trampoline(req &http.Request, chunk []u8, _ u64, _ u64, _ int) ! {
	mut ctx := unsafe { &StreamContext(req.user_ptr) }
	ctx.on_chunk(ctx.context, chunk.bytestr())
}

// post_stream sends a JSON POST and forwards every response body chunk to
// `on_chunk` as it arrives, which is what `stream: true` endpoints need.
fn (c &Client) post_stream(path string, payload string, context voidptr, on_chunk fn (voidptr, string)) !string {
	mut ctx := &StreamContext{
		context:  context
		on_chunk: on_chunk
	}
	response := http.fetch(
		method:                   .post
		url:                      c.url(path)
		data:                     payload
		header:                   c.header()
		read_timeout:             c.config.read_timeout
		write_timeout:            c.config.write_timeout
		user_ptr:                 ctx
		on_progress_body:         stream_trampoline
		disable_connection_reuse: c.config.disable_connection_reuse
	)!
	if response.status_code >= 400 {
		return decode_error_response(response.status_code, response.body)
	}
	return response.body
}
