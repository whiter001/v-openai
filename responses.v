module openai

import x.json2 as json
import strings

// CreateResponseRequest is the payload of POST /responses, the API OpenAI
// recommends for new integrations. `input` covers plain text; `input_items`
// carries structured multi-turn input and takes precedence when set.
pub struct CreateResponseRequest {
pub mut:
	model                string @[required]
	input                string
	input_items          []ResponseInputItem
	instructions         string
	previous_response_id string
	store                ?bool
	tools                []Tool
	// tool_choice is 'auto', 'none' or 'required'; empty uses the API default.
	tool_choice         string
	parallel_tool_calls ?bool
	temperature         ?f64
	top_p               ?f64
	max_output_tokens   ?int
	reasoning           ?Reasoning
	// text_format selects the output format, e.g. json_schema_format(...).
	text_format ?ResponseFormat
	metadata    map[string]string
	stream      bool
}

// Reasoning configures a reasoning model. `effort` is 'none', 'minimal',
// 'low', 'medium', 'high', 'xhigh' or 'max' (model dependent).
pub struct Reasoning {
pub:
	effort string
}

// ResponseInputItem is one item of structured response input: a message with
// typed content parts.
pub struct ResponseInputItem {
pub:
	@type   string = 'message' @[json: 'type']
	role    string
	content []ResponseContentPart
}

// ResponseContentPart is one part of input or output content. `type` is
// 'input_text', 'input_image' or 'output_text'.
pub struct ResponseContentPart {
pub:
	@type     string @[json: 'type']
	text      string @[omitempty]
	image_url string @[omitempty]
}

// response_text_input builds a user message input item with one text part.
pub fn response_text_input(text string) ResponseInputItem {
	return ResponseInputItem{
		role:    'user'
		content: [
			ResponseContentPart{
				@type: 'input_text'
				text:  text
			},
		]
	}
}

// response_image_input builds a user message input item with text and image
// parts.
pub fn response_image_input(text string, image_url string) ResponseInputItem {
	return ResponseInputItem{
		role:    'user'
		content: [
			ResponseContentPart{
				@type: 'input_text'
				text:  text
			},
			ResponseContentPart{
				@type:     'input_image'
				image_url: image_url
			},
		]
	}
}

// Response is the answer of POST /responses.
pub struct Response {
pub:
	id         string
	object     string
	created_at i64
	status     string
	model      string
	output     []ResponseOutputItem
	usage      ResponseUsage
}

// ResponseUsage is the token accounting of a Response.
pub struct ResponseUsage {
pub:
	input_tokens  int
	output_tokens int
	total_tokens  int
}

// ResponseOutputItem is one output item: a 'message' with content parts, a
// 'reasoning' trace, or a 'function_call' request.
pub struct ResponseOutputItem {
pub:
	@type     string @[json: 'type']
	id        string
	role      string @[omitempty]
	status    string @[omitempty]
	content   []ResponseContentPart
	name      string @[omitempty]
	call_id   string @[omitempty]
	arguments string @[omitempty]
}

// output_text concatenates the text of every output message, the common
// case of reading a Response.
pub fn (r &Response) output_text() string {
	mut sb := strings.new_builder(256)
	for item in r.output {
		if item.@type != 'message' {
			continue
		}
		for part in item.content {
			if part.@type == 'output_text' {
				sb.write_string(part.text)
			}
		}
	}
	return sb.str()
}

// Responses stream event types (the `type` field of every event).
pub const response_event_created = 'response.created'
pub const response_event_output_item_added = 'response.output_item.added'
pub const response_event_output_text_delta = 'response.output_text.delta'
pub const response_event_function_call_arguments_delta = 'response.function_call_arguments.delta'
pub const response_event_completed = 'response.completed'
pub const response_event_failed = 'response.failed'
pub const response_event_error = 'error'

// ResponseStreamEvent is one server-sent event of a streaming response.
// `delta` carries incremental text for *.delta events; `response` carries
// the full Response on response.completed/failed; `item` carries output
// items on response.output_item.* events.
pub struct ResponseStreamEvent {
pub:
	@type    string @[json: 'type']
	delta    string @[omitempty]
	text     string @[omitempty]
	response Response
	item     ResponseOutputItem
}

// is_terminal reports whether the event ends the stream.
pub fn (event &ResponseStreamEvent) is_terminal() bool {
	return event.@type in [response_event_completed, response_event_failed, response_event_error]
}

// create_response runs a non-streaming Responses API call.
pub fn (c &Client) create_response(request CreateResponseRequest) !Response {
	body := c.post('/responses', encode_response_request(request))!
	return json.decode[Response](body)!
}

// ResponseStreamCaller is the interface between the type-erased stream
// state and the caller's typed callback. Interface dispatch is used
// instead of casting function pointers: generic fn values do not compile
// on older V versions, and raw fn pointer casts crash there at runtime.
interface ResponseStreamCaller {
	call(ResponseStreamEvent)
}

// ResponseCallbackAdapter adapts a (context, callback) pair to
// ResponseStreamCaller.
struct ResponseCallbackAdapter[T] {
	context  T
	callback fn (T, ResponseStreamEvent)
}

fn (adapter ResponseCallbackAdapter[T]) call(event ResponseStreamEvent) {
	adapter.callback(adapter.context, event)
}

// ResponseStreamState threads the SSE parser and the caller through
// post_stream, latching when a terminal event arrives.
struct ResponseStreamState {
mut:
	parser SseParser
	caller ResponseStreamCaller
	done   bool
}

fn response_chunk_adapter(state_ptr voidptr, raw_chunk string) {
	mut state := unsafe { &ResponseStreamState(state_ptr) }
	if state.done {
		return
	}
	for payload in state.parser.feed(raw_chunk) {
		if payload.trim_space() == '[DONE]' {
			state.done = true
			return
		}
		if event := json.decode[ResponseStreamEvent](payload) {
			if event.is_terminal() {
				state.done = true
			}
			state.caller.call(event)
			if state.done {
				return
			}
		}
	}
}

// create_response_stream runs a streaming Responses API call, invoking
// `callback` with `context` for every event until a terminal event
// (response.completed, response.failed or error) arrives.
pub fn (c &Client) create_response_stream[T](request CreateResponseRequest, context T, callback fn (T, ResponseStreamEvent)) ! {
	mut state := &ResponseStreamState{
		caller: ResponseCallbackAdapter[T]{
			context:  context
			callback: callback
		}
	}
	payload := encode_response_request(CreateResponseRequest{
		...request
		stream: true
	})
	c.post_stream('/responses', payload, state, response_chunk_adapter)!
}

fn encode_response_request(request CreateResponseRequest) string {
	mut fields := ['"model":${json.encode(request.model)}']
	if request.input_items.len != 0 {
		fields << '"input":${encode_response_input_items(request.input_items)}'
	} else {
		fields << '"input":${json.encode(request.input)}'
	}
	if request.instructions != '' {
		fields << '"instructions":${json.encode(request.instructions)}'
	}
	if request.previous_response_id != '' {
		fields << '"previous_response_id":${json.encode(request.previous_response_id)}'
	}
	if store := request.store {
		fields << '"store":${store}'
	}
	if request.tools.len != 0 {
		fields << '"tools":${encode_tools(request.tools)}'
	}
	if request.tool_choice != '' {
		fields << '"tool_choice":${json.encode(request.tool_choice)}'
	}
	if parallel_tool_calls := request.parallel_tool_calls {
		fields << '"parallel_tool_calls":${parallel_tool_calls}'
	}
	if temperature := request.temperature {
		fields << '"temperature":${temperature}'
	}
	if top_p := request.top_p {
		fields << '"top_p":${top_p}'
	}
	if max_output_tokens := request.max_output_tokens {
		fields << '"max_output_tokens":${max_output_tokens}'
	}
	if reasoning := request.reasoning {
		fields << '"reasoning":{"effort":${json.encode(reasoning.effort)}}'
	}
	if format := request.text_format {
		fields << '"text":{"format":${encode_response_format(format)}}'
	}
	if request.metadata.len != 0 {
		fields << '"metadata":${json.encode(request.metadata)}'
	}
	if request.stream {
		fields << '"stream":true'
	}
	return '{${fields.join(',')}}'
}

fn encode_response_input_items(items []ResponseInputItem) string {
	mut encoded := []string{cap: items.len}
	for item in items {
		mut parts := []string{cap: item.content.len}
		for part in item.content {
			mut part_fields := ['"type":${json.encode(part.@type)}']
			if part.text != '' {
				part_fields << '"text":${json.encode(part.text)}'
			}
			if part.image_url != '' {
				part_fields << '"image_url":${json.encode(part.image_url)}'
			}
			parts << '{${part_fields.join(',')}}'
		}
		encoded << '{"type":${json.encode(item.@type)},"role":${json.encode(item.role)},"content":[${parts.join(',')}]}'
	}
	return '[${encoded.join(',')}]'
}
