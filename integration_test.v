module openai

import os

// These tests talk to the real API and only run when OPENAI_API_KEY is set,
// e.g.: `OPENAI_API_KEY=sk-... v test .`

fn test_real_response() {
	key := os.getenv('OPENAI_API_KEY')
	if key == '' {
		return
	}
	base_url := os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	model := os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
	client := new_client(
		api_key:  key
		base_url: base_url
	)
	response := client.create_response(CreateResponseRequest{
		model: model
		input: 'Reply with exactly: pong'
	})!
	assert response.output_text() != ''
}

fn test_real_chat_completion() {
	key := os.getenv('OPENAI_API_KEY')
	if key == '' {
		return
	}
	base_url := os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	model := os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
	client := new_client(
		api_key:  key
		base_url: base_url
	)
	response := client.create_chat_completion(ChatCompletionRequest{
		model:       model
		messages:    [user_message('Reply with exactly: pong')]
		temperature: 0.0
	})!
	assert response.choices.len != 0
	assert response.choices[0].message.content or { '' } != ''
}

// StreamCounter counts chunks and concatenates their content.
struct StreamCounter {
mut:
	pieces int
	text   string
}

fn count_chunk(ctx voidptr, chunk ChatCompletionChunk) {
	mut counter := unsafe { &StreamCounter(ctx) }
	if chunk.choices.len != 0 {
		counter.pieces++
		counter.text += chunk.choices[0].delta.content
	}
}

fn test_real_chat_completion_stream() {
	key := os.getenv('OPENAI_API_KEY')
	if key == '' {
		return
	}
	base_url := os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	model := os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
	client := new_client(
		api_key:  key
		base_url: base_url
	)
	mut counter := &StreamCounter{}
	client.create_chat_completion_stream(ChatCompletionRequest{
		model:    model
		messages: [user_message('Count to three, one word per chunk.')]
	}, counter, count_chunk)!
	assert counter.pieces != 0
	assert counter.text != ''
}
