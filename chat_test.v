module openai

import json2 as json

fn test_encode_chat_request_sends_only_what_was_set() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [user_message('hi')]
	})
	assert encoded == '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"hi"}]}'
}

fn test_encode_chat_request_keeps_an_explicit_zero_temperature() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:       'gpt-4o-mini'
		messages:    [user_message('hi')]
		temperature: 0.0
	})
	assert encoded.contains('"temperature":0')
}

fn test_encode_chat_request_renders_tools_and_stream() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [user_message('weather?')]
		tools:    [
			function_tool('get_weather', 'Read the weather', '{"type":"object","properties":{"city":{"type":"string"}}}'),
		]
		stream:   true
	})
	assert encoded.contains('"stream":true')
	assert encoded.contains('"name":"get_weather"')
	assert encoded.contains('"parameters":{"type":"object","properties":{"city":{"type":"string"}}}')
	assert encoded.contains('"type":"function"')
}

fn test_encode_chat_request_renders_tool_call_history() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [
			ChatMessage{
				role:       'assistant'
				tool_calls: [
					ToolCall{
						id:       'call_1'
						@type:    'function'
						function: ToolCallFunction{
							name:      'get_weather'
							arguments: '{"city":"Paris"}'
						}
					},
				]
			},
			tool_message('call_1', '{"temp":12}'),
		]
	})
	assert encoded.contains('"content":null')
	assert encoded.contains('"tool_calls":[{"id":"call_1","type":"function","function":{"name":"get_weather","arguments":"{\\"city\\":\\"Paris\\"}"}}]')
	assert encoded.contains('"tool_call_id":"call_1"')
}

fn test_encode_chat_request_renders_multimodal_content() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [
			user_message_parts([
				text_part('What is in this image?'),
				image_part('https://example.com/cat.png'),
				image_part_with_detail('data:image/png;base64,aGVsbG8=', 'high'),
			]),
		]
	})
	assert encoded.contains('"content":[{"type":"text","text":"What is in this image?"}')
	assert encoded.contains('{"type":"image_url","image_url":{"url":"https://example.com/cat.png"}}')
	assert encoded.contains('{"type":"image_url","image_url":{"url":"data:image/png;base64,aGVsbG8=","detail":"high"}}')
}

fn test_encode_chat_request_renders_audio_content() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:    'gpt-4o-audio-preview'
		messages: [user_message_parts([audio_part('aGVsbG8=', 'wav')])]
	})
	assert encoded.contains('{"type":"input_audio","input_audio":{"data":"aGVsbG8=","format":"wav"}}')
}

fn test_encode_chat_request_renders_json_schema_format() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:           'gpt-4o-mini'
		messages:        [user_message('extract')]
		response_format: json_schema_format('person', '{"type":"object","properties":{"name":{"type":"string"}}}',
			true)
	})
	assert encoded.contains('"response_format":{"type":"json_schema"')
	assert encoded.contains('"name":"person"')
	assert encoded.contains('"schema":{"type":"object","properties":{"name":{"type":"string"}}}')
	assert encoded.contains('"strict":true')
}

fn test_encode_chat_request_renders_tool_choice_function_and_parallel_flag() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:                'gpt-4o-mini'
		messages:             [user_message('hi')]
		tool_choice:          'auto'
		tool_choice_function: 'get_weather'
		parallel_tool_calls:  false
	})
	assert encoded.contains('"tool_choice":{"type":"function","function":{"name":"get_weather"}}')
	assert encoded.contains('"parallel_tool_calls":false')
	assert !encoded.contains('"tool_choice":"auto"')
}

fn test_encode_chat_request_renders_misc_knobs() {
	encoded := encode_chat_request(ChatCompletionRequest{
		model:          'gpt-4o-mini'
		messages:       [user_message('hi')]
		seed:           42
		service_tier:   'flex'
		store:          true
		metadata:       {
			'trace': 't-1'
		}
		logprobs:       true
		top_logprobs:   3
		stream:         true
		stream_options: StreamOptions{
			include_usage: true
		}
	})
	assert encoded.contains('"seed":42')
	assert encoded.contains('"service_tier":"flex"')
	assert encoded.contains('"store":true')
	assert encoded.contains('"metadata":{"trace":"t-1"}')
	assert encoded.contains('"logprobs":true')
	assert encoded.contains('"top_logprobs":3')
	assert encoded.contains('"stream_options":{"include_usage":true}')
}

fn test_decode_chat_completion_response_with_logprobs() {
	body := '{"id":"chatcmpl-4","object":"chat.completion","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"message":{"role":"assistant","content":"Hi"},"finish_reason":"stop","logprobs":{"content":[{"token":"Hi","logprob":-0.001,"bytes":[72,105],"top_logprobs":[{"token":"Hi","logprob":-0.001,"bytes":[72,105]}]}]}}],"usage":{"prompt_tokens":8,"completion_tokens":11,"total_tokens":19}}'
	response := json.decode[ChatCompletionResponse](body)!
	probs := response.choices[0].logprobs.content
	assert probs.len == 1
	assert probs[0].token == 'Hi'
	assert probs[0].bytes == [72, 105]
	assert probs[0].top_logprobs[0].logprob == -0.001
}

fn test_decode_stream_chunk_with_usage() {
	body := '{"id":"chatcmpl-5","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[],"usage":{"prompt_tokens":8,"completion_tokens":11,"total_tokens":19}}'
	chunk := json.decode[ChatCompletionChunk](body)!
	assert chunk.choices.len == 0
	if usage := chunk.usage {
		assert usage.total_tokens == 19
	} else {
		assert false, 'usage should be set'
	}
}

fn test_decode_chat_completion_response() {
	body := '{"id":"chatcmpl-1","object":"chat.completion","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"message":{"role":"assistant","content":"Hello!"},"finish_reason":"stop"}],"usage":{"prompt_tokens":8,"completion_tokens":11,"total_tokens":19}}'
	response := json.decode[ChatCompletionResponse](body)!
	assert response.choices.len == 1
	assert response.choices[0].message.content or { '' } == 'Hello!'
	assert response.usage.total_tokens == 19
}

fn test_decode_chat_completion_response_with_tool_calls_and_null_content() {
	body := '{"id":"chatcmpl-2","object":"chat.completion","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"get_weather","arguments":"{\\"city\\":\\"Paris\\"}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":8,"completion_tokens":11,"total_tokens":19}}'
	response := json.decode[ChatCompletionResponse](body)!
	message := response.choices[0].message
	assert message.content == none
	assert message.tool_calls.len == 1
	assert message.tool_calls[0].function.name == 'get_weather'
}

fn test_decode_chat_completion_chunk_with_null_finish_reason() {
	body := '{"id":"chatcmpl-3","object":"chat.completion.chunk","created":1740000000,"model":"gpt-4o-mini","choices":[{"index":0,"delta":{"content":"Hel"},"finish_reason":null}]}'
	chunk := json.decode[ChatCompletionChunk](body)!
	assert chunk.choices[0].delta.content == 'Hel'
	assert chunk.choices[0].finish_reason == ''
}

fn test_decode_embedding_response() {
	body := '{"object":"list","data":[{"object":"embedding","index":0,"embedding":[0.5,-1.25,2.0]}],"model":"text-embedding-3-small","usage":{"prompt_tokens":5,"total_tokens":5}}'
	response := json.decode[EmbeddingResponse](body)!
	assert response.data.len == 1
	assert response.data[0].embedding == [f32(0.5), -1.25, 2.0]
}
