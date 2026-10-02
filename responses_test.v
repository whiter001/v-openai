// vtest retry: 3
module openai

import x.json2 as json

fn test_encode_response_request_minimal() {
	encoded := encode_response_request(CreateResponseRequest{
		model: 'gpt-4o-mini'
		input: 'Why is the sky blue?'
	})
	assert encoded == '{"model":"gpt-4o-mini","input":"Why is the sky blue?"}'
}

fn test_encode_response_request_full() {
	encoded := encode_response_request(CreateResponseRequest{
		model:                'gpt-5'
		input:                'hi'
		instructions:         'Be brief.'
		previous_response_id: 'resp_123'
		store:                true
		tools:                [
			function_tool('get_weather', 'weather', '{"type":"object"}'),
		]
		tool_choice:          'auto'
		parallel_tool_calls:  false
		temperature:          0.5
		max_output_tokens:    100
		reasoning:            Reasoning{
			effort: 'high'
		}
		text_format:          json_schema_format('answer', '{"type":"object"}', true)
		metadata:             {
			'k': 'v'
		}
		stream:               true
	})
	assert encoded.contains('"instructions":"Be brief."')
	assert encoded.contains('"previous_response_id":"resp_123"')
	assert encoded.contains('"store":true')
	assert encoded.contains('"tools":[{"type":"function"')
	assert encoded.contains('"parallel_tool_calls":false')
	assert encoded.contains('"temperature":0.5')
	assert encoded.contains('"max_output_tokens":100')
	assert encoded.contains('"reasoning":{"effort":"high"}')
	assert encoded.contains('"text":{"format":{"type":"json_schema"')
	assert encoded.contains('"metadata":{"k":"v"}')
	assert encoded.contains('"stream":true')
}

fn test_encode_response_input_items_take_precedence() {
	encoded := encode_response_request(CreateResponseRequest{
		model:       'gpt-4o-mini'
		input:       'ignored'
		input_items: [response_image_input('What is this?', 'https://example.com/x.png')]
	})
	assert encoded.contains('"input":[{"type":"message","role":"user","content":[{"type":"input_text","text":"What is this?"},{"type":"input_image","image_url":"https://example.com/x.png"}]}]')
	assert !encoded.contains('ignored')
}

fn test_decode_response_and_output_text() {
	body := '{"id":"resp_1","object":"response","created_at":1740000000,"status":"completed","model":"gpt-4o-mini","output":[{"type":"reasoning","id":"rs_1","status":"completed"},{"type":"message","id":"msg_1","role":"assistant","status":"completed","content":[{"type":"output_text","text":"The sky is blue."}]}],"usage":{"input_tokens":10,"output_tokens":6,"total_tokens":16}}'
	response := json.decode[Response](body)!
	assert response.status == 'completed'
	assert response.output.len == 2
	assert response.output_text() == 'The sky is blue.'
	assert response.usage.total_tokens == 16
}

fn test_decode_response_with_function_call_item() {
	body := '{"id":"resp_2","object":"response","created_at":1740000000,"status":"completed","model":"gpt-4o-mini","output":[{"type":"function_call","id":"fc_1","status":"completed","name":"get_weather","call_id":"call_1","arguments":"{\\"city\\":\\"Paris\\"}"}],"usage":{"input_tokens":10,"output_tokens":6,"total_tokens":16}}'
	response := json.decode[Response](body)!
	call := response.output[0]
	assert call.@type == 'function_call'
	assert call.name == 'get_weather'
	assert call.call_id == 'call_1'
	assert response.output_text() == ''
}

// ResponseEventSink records the types and text of stream events.
struct ResponseEventSink {
mut:
	types  []string
	deltas []string
	status string
}

fn sink_response_event(ctx voidptr, event ResponseStreamEvent) {
	mut sink := unsafe { &ResponseEventSink(ctx) }
	sink.types << event.@type
	if event.delta != '' {
		sink.deltas << event.delta
	}
	if event.@type == response_event_completed {
		sink.status = event.response.status
	}
}

const mock_response_stream_body = 'event: response.created\ndata: {"type":"response.created","response":{"id":"resp_9","object":"response","created_at":1740000000,"status":"in_progress","model":"gpt-4o-mini"}}\n\nevent: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":"Hel"}\n\nevent: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":"lo"}\n\nevent: response.completed\ndata: {"type":"response.completed","response":{"id":"resp_9","object":"response","created_at":1740000000,"status":"completed","model":"gpt-4o-mini","output":[{"type":"message","id":"msg_1","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Hello"}]}],"usage":{"input_tokens":3,"output_tokens":1,"total_tokens":4}}}\n\n'

fn test_create_response_stream_against_a_loopback_server() {
	mut mock := start_mock_server('HTTP/1.1 200 OK', 'text/event-stream', mock_response_stream_body)
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:                  'sk-test'
		base_url:                 mock.base_url()
		// The mocks below are one-purpose loopback servers; keep net.http's
		// keep-alive pool from reusing a stale connection across them.
		disable_connection_reuse: true
	)

	mut sink := &ResponseEventSink{}
	client.create_response_stream(CreateResponseRequest{
		model: 'gpt-4o-mini'
		input: 'hi'
	}, sink, sink_response_event)!

	assert sink.types == [response_event_created, response_event_output_text_delta,
		response_event_output_text_delta, response_event_completed]
	assert sink.deltas == ['Hel', 'lo']
	assert sink.status == 'completed'
	assert mock.request_head()[0] == 'POST /v1/responses HTTP/1.1'
}
