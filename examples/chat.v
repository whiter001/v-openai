module main

import os
import openai

fn main() {
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	)
	response := client.create_chat_completion(openai.ChatCompletionRequest{
		model:       os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
		messages:    [openai.user_message('Explain V (the language) in one sentence.')]
		temperature: 0.0
	})!
	println(response.choices[0].message.content or { '' })
	println('tokens: ${response.usage.total_tokens}')
}
