module main

import os
import openai

fn print_chunk(_ voidptr, chunk openai.ChatCompletionChunk) {
	if chunk.choices.len != 0 {
		print(chunk.choices[0].delta.content)
		flush_stdout()
	}
}

fn main() {
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	)
	client.create_chat_completion_stream(openai.ChatCompletionRequest{
		model:    os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
		messages: [openai.user_message('Tell me a short story about a compiler.')]
	}, unsafe { nil }, print_chunk)!
	println('')
}
