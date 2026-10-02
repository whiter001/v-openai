module openai

import json2 as json

// ChatCompletionRequest is the payload of POST /chat/completions. Option
// fields left as none and empty collections are not sent at all, so the API
// defaults apply.
pub struct ChatCompletionRequest {
pub mut:
	model             string        @[required]
	messages          []ChatMessage @[required]
	temperature       ?f64
	top_p             ?f64
	n                 ?int
	max_tokens        ?int
	stop              []string
	presence_penalty  ?f64
	frequency_penalty ?f64
	logit_bias        map[string]int
	user              string
	tools             []Tool
	// tool_choice is 'auto', 'none' or 'required'; empty uses the API default.
	tool_choice     string
	response_format ?ResponseFormat
	// reasoning_effort is 'low', 'medium' or 'high'; empty uses the API default.
	reasoning_effort string
	stream           bool
}

// ChatCompletionResponse is the non-streaming answer of the chat endpoint.
pub struct ChatCompletionResponse {
pub:
	id      string
	object  string
	created i64
	model   string
	choices []ChatChoice
	usage   Usage
}

// ChatChoice is one completion choice of a ChatCompletionResponse.
pub struct ChatChoice {
pub:
	index         int
	message       ChatMessage
	finish_reason string
}

// ChatCompletionChunk is one server-sent event of a streaming completion.
pub struct ChatCompletionChunk {
pub:
	id      string
	object  string
	created i64
	model   string
	choices []ChatChunkChoice
}

// ChatChunkChoice is one choice of a ChatCompletionChunk.
pub struct ChatChunkChoice {
pub:
	index         int
	delta         ChatDelta
	finish_reason string
}

// ChatDelta is the incremental content of a streaming choice.
pub struct ChatDelta {
pub:
	role       string          @[omitempty]
	content    string          @[omitempty]
	tool_calls []ToolCallChunk @[omitempty]
}

// ToolCallChunk is the streaming form of a ToolCall: every field may arrive
// spread over several chunks.
pub struct ToolCallChunk {
pub:
	index    int
	id       string @[omitempty]
	@type    string @[json: 'type'; omitempty]
	function ToolCallFunctionChunk
}

// ToolCallFunctionChunk is the streaming form of ToolCallFunction.
pub struct ToolCallFunctionChunk {
pub:
	name      string @[omitempty]
	arguments string @[omitempty]
}

// ChatStreamState threads the SSE parser and the caller's context through
// post_stream. `done` latches once the server sends `[DONE]`.
struct ChatStreamState[T] {
mut:
	parser   SseParser
	context  T
	callback fn (T, ChatCompletionChunk) = unsafe { nil }
	done     bool
}

fn chat_chunk_adapter[T](mut state ChatStreamState[T], raw_chunk string) {
	if state.done {
		return
	}
	for payload in state.parser.feed(raw_chunk) {
		if payload.trim_space() == '[DONE]' {
			state.done = true
			return
		}
		if completion_chunk := json.decode[ChatCompletionChunk](payload) {
			state.callback(state.context, completion_chunk)
		}
	}
}

// create_chat_completion runs a non-streaming chat completion.
pub fn (c &Client) create_chat_completion(request ChatCompletionRequest) !ChatCompletionResponse {
	body := c.post('/chat/completions', encode_chat_request(request))!
	return json.decode[ChatCompletionResponse](body)!
}

// create_chat_completion_stream runs a streaming chat completion, invoking
// `callback` with `context` for every chunk until the server sends `[DONE]`.
// Pass a reference type as `context` to observe mutations; the callback must
// be a plain function (closures in struct fields lose their captures).
pub fn (c &Client) create_chat_completion_stream[T](request ChatCompletionRequest, context T, callback fn (T, ChatCompletionChunk)) ! {
	mut state := &ChatStreamState[T]{
		context:  context
		callback: callback
	}
	payload := encode_chat_request(ChatCompletionRequest{
		...request
		stream: true
	})
	c.post_stream('/chat/completions', payload, state, chat_chunk_adapter[T])!
}

// encode_chat_request renders the request by hand: only explicitly set
// options are sent, so `temperature: 0.0` stays on the wire while an unset
// option lets the API default apply.
fn encode_chat_request(request ChatCompletionRequest) string {
	mut fields := ['"model":${json.encode(request.model)}',
		'"messages":${encode_chat_messages(request.messages)}']
	if temperature := request.temperature {
		fields << '"temperature":${temperature}'
	}
	if top_p := request.top_p {
		fields << '"top_p":${top_p}'
	}
	if n := request.n {
		fields << '"n":${n}'
	}
	if max_tokens := request.max_tokens {
		fields << '"max_tokens":${max_tokens}'
	}
	if request.stop.len != 0 {
		fields << '"stop":${json.encode(request.stop)}'
	}
	if presence_penalty := request.presence_penalty {
		fields << '"presence_penalty":${presence_penalty}'
	}
	if frequency_penalty := request.frequency_penalty {
		fields << '"frequency_penalty":${frequency_penalty}'
	}
	if request.logit_bias.len != 0 {
		fields << '"logit_bias":${json.encode(request.logit_bias)}'
	}
	if request.user != '' {
		fields << '"user":${json.encode(request.user)}'
	}
	if request.tools.len != 0 {
		fields << '"tools":${encode_tools(request.tools)}'
	}
	if request.tool_choice != '' {
		fields << '"tool_choice":${json.encode(request.tool_choice)}'
	}
	if format := request.response_format {
		fields << '"response_format":{"type":${json.encode(format.@type)}}'
	}
	if request.reasoning_effort != '' {
		fields << '"reasoning_effort":${json.encode(request.reasoning_effort)}'
	}
	if request.stream {
		fields << '"stream":true'
	}
	return '{${fields.join(',')}}'
}

fn encode_chat_messages(messages []ChatMessage) string {
	mut encoded := []string{cap: messages.len}
	for message in messages {
		mut fields := ['"role":${json.encode(message.role)}']
		if content := message.content {
			fields << '"content":${json.encode(content)}'
		} else {
			fields << '"content":null'
		}
		if message.name != '' {
			fields << '"name":${json.encode(message.name)}'
		}
		if message.tool_calls.len != 0 {
			fields << '"tool_calls":${encode_tool_calls(message.tool_calls)}'
		}
		if message.tool_call_id != '' {
			fields << '"tool_call_id":${json.encode(message.tool_call_id)}'
		}
		encoded << '{${fields.join(',')}}'
	}
	return '[${encoded.join(',')}]'
}

fn encode_tool_calls(tool_calls []ToolCall) string {
	mut encoded := []string{cap: tool_calls.len}
	for tool_call in tool_calls {
		encoded << '{"id":${json.encode(tool_call.id)},"type":${json.encode(tool_call.@type)},"function":{"name":${json.encode(tool_call.function.name)},"arguments":${json.encode(tool_call.function.arguments)}}}'
	}
	return '[${encoded.join(',')}]'
}

fn encode_tools(tools []Tool) string {
	mut encoded := []string{cap: tools.len}
	for tool in tools {
		definition := tool.function
		parameters := definition.parameters.trim_space()
		mut fields := ['"name":${json.encode(definition.name)}']
		if definition.description != '' {
			fields << '"description":${json.encode(definition.description)}'
		}
		if parameters.starts_with('{') {
			fields << '"parameters":${parameters}'
		} else {
			fields << '"parameters":{}'
		}
		encoded << '{"type":${json.encode(tool.@type)},"function":{${fields.join(',')}}}'
	}
	return '[${encoded.join(',')}]'
}
