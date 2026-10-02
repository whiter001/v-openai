module main

// Any OpenAI-compatible endpoint works by changing base_url (and api_key):
//
//   DeepSeek  https://api.deepseek.com/v1            (DEEPSEEK_API_KEY)
//   Kimi      https://api.moonshot.cn/v1             (MOONSHOT_API_KEY)
//   GLM       https://open.bigmodel.cn/api/paas/v4   (ZHIPU_API_KEY)
//   Ollama    http://localhost:11434/v1              (any non-empty key)
//
// export OPENAI_BASE_URL=https://api.deepseek.com/v1
// export OPENAI_API_KEY=$DEEPSEEK_API_KEY
// export OPENAI_MODEL=deepseek-chat
// v run examples/chat.v

import os
import openai

fn main() {
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv('OPENAI_BASE_URL')
	)
	response := client.create_chat_completion(
		model:    os.getenv('OPENAI_MODEL')
		messages: [openai.user_message('Say hello in one word.')]
	)!
	println(response.choices[0].message.content or { '' })
}
