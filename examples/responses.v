module main

import os
import openai

// Multi-turn conversation via previous_response_id chaining.
fn main() {
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	)
	model := os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }

	first := client.create_response(openai.CreateResponseRequest{
		model:        model
		instructions: 'Answer as a travel guide, one sentence per answer.'
		input:        'What should I see in Lisbon?'
		store:        true
	})!
	println(first.output_text())

	second := client.create_response(openai.CreateResponseRequest{
		model:                model
		instructions:         'Answer as a travel guide, one sentence per answer.'
		input:                'Which one is best on a rainy day?'
		previous_response_id: first.id
		store:                true
	})!
	println(second.output_text())
}
