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
	seed              ?int
	service_tier      string
	store             ?bool
	metadata          map[string]string
	logprobs          ?bool
	top_logprobs      ?int
	tools             []Tool
	// tool_choice is 'auto', 'none' or 'required'; empty uses the API default.
	tool_choice string
	// tool_choice_function forces one named tool and takes precedence over
	// tool_choice.
	tool_choice_function string
	parallel_tool_calls  ?bool
	response_format      ?ResponseFormat
	// reasoning_effort is 'low', 'medium' or 'high'; empty uses the API default.
	reasoning_effort string
	stream           bool
	// stream_options adds e.g. usage reporting to the final stream chunk.
	stream_options ?StreamOptions
}

// StreamOptions configures a streaming request.
pub struct StreamOptions {
pub:
	include_usage bool
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
	logprobs      LogProbs
}

// LogProbs carries the log probability information of a choice.
pub struct LogProbs {
pub:
	content []LogProb
}

// LogProb is one sampled token with its most likely alternatives.
pub struct LogProb {
pub:
	token        string
	logprob      f64
	bytes        []int
	top_logprobs []TopLogProb
}

// TopLogProb is one alternative token and its log probability.
pub struct TopLogProb {
pub:
	token   string
	logprob f64
	bytes   []int
}

// ChatCompletionChunk is one server-sent event of a streaming completion.
// `usage` is set only on the final chunk of a stream requested with
// `StreamOptions{ include_usage: true }`.
pub struct ChatCompletionChunk {
pub:
	id      string
	object  string
	created i64
	model   string
	choices []ChatChunkChoice
	usage   ?Usage
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
	if seed := request.seed {
		fields << '"seed":${seed}'
	}
	if request.service_tier != '' {
		fields << '"service_tier":${json.encode(request.service_tier)}'
	}
	if store := request.store {
		fields << '"store":${store}'
	}
	if request.metadata.len != 0 {
		fields << '"metadata":${json.encode(request.metadata)}'
	}
	if logprobs := request.logprobs {
		fields << '"logprobs":${logprobs}'
	}
	if top_logprobs := request.top_logprobs {
		fields << '"top_logprobs":${top_logprobs}'
	}
	if request.tools.len != 0 {
		fields << '"tools":${encode_tools(request.tools)}'
	}
	if request.tool_choice_function != '' {
		fields << '"tool_choice":{"type":"function","function":{"name":${json.encode(request.tool_choice_function)}}}'
	} else if request.tool_choice != '' {
		fields << '"tool_choice":${json.encode(request.tool_choice)}'
	}
	if parallel_tool_calls := request.parallel_tool_calls {
		fields << '"parallel_tool_calls":${parallel_tool_calls}'
	}
	if format := request.response_format {
		fields << '"response_format":${encode_response_format(format)}'
	}
	if request.reasoning_effort != '' {
		fields << '"reasoning_effort":${json.encode(request.reasoning_effort)}'
	}
	if request.stream {
		fields << '"stream":true'
	}
	if options := request.stream_options {
		fields << '"stream_options":{"include_usage":${options.include_usage}}'
	}
	return '{${fields.join(',')}}'
}

// encode_response_format renders a ResponseFormat, embedding the raw schema
// document of a 'json_schema' format verbatim.
fn encode_response_format(format ResponseFormat) string {
	mut fields := ['"type":${json.encode(format.@type)}']
	if format.json_schema.name != '' {
		mut schema_fields := ['"name":${json.encode(format.json_schema.name)}']
		if format.json_schema.description != '' {
			schema_fields << '"description":${json.encode(format.json_schema.description)}'
		}
		schema := format.json_schema.schema.trim_space()
		if schema.starts_with('{') {
			schema_fields << '"schema":${schema}'
		}
		if strict := format.json_schema.strict {
			schema_fields << '"strict":${strict}'
		}
		fields << '"json_schema":{${schema_fields.join(',')}}'
	}
	return '{${fields.join(',')}}'
}

fn encode_chat_messages(messages []ChatMessage) string {
	mut encoded := []string{cap: messages.len}
	for message in messages {
		mut fields := ['"role":${json.encode(message.role)}']
		if message.multi_content.len != 0 {
			fields << '"content":${encode_content_parts(message.multi_content)}'
		} else if content := message.content {
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

// encode_content_parts renders a multimodal content array.
fn encode_content_parts(parts []ContentPart) string {
	mut encoded := []string{cap: parts.len}
	for part in parts {
		encoded << match part.@type {
			'image_url' {
				mut payload := ['"url":${json.encode(part.image_url.url)}']
				if part.image_url.detail != '' {
					payload << '"detail":${json.encode(part.image_url.detail)}'
				}
				'{"type":"image_url","image_url":{${payload.join(',')}}}'
			}
			'input_audio' {
				'{"type":"input_audio","input_audio":{"data":${json.encode(part.input_audio.data)},"format":${json.encode(part.input_audio.format)}}}'
			}
			else {
				'{"type":${json.encode(part.@type)},"text":${json.encode(part.text)}}'
			}
		}
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
