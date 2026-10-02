module main

import os
import openai

fn main() {
	image := os.getenv_opt('EXAMPLE_IMAGE_URL') or { 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/640px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg' }
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	)
	response := client.create_chat_completion(openai.ChatCompletionRequest{
		model:    os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
		messages: [
			openai.user_message_parts([
				openai.text_part('Describe this image in one sentence.'),
				openai.image_part(image),
			]),
		]
	})!
	println(response.choices[0].message.content or { '' })
}
