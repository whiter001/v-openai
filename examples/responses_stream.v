module main

import os
import openai

fn print_event(_ voidptr, event openai.ResponseStreamEvent) {
	if event.@type == openai.response_event_output_text_delta {
		print(event.delta)
		flush_stdout()
	}
}

fn main() {
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	)
	client.create_response_stream(openai.CreateResponseRequest{
		model: os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
		input: 'Write a haiku about a compiler.'
	}, unsafe { nil }, print_event)!
	println('')
}
