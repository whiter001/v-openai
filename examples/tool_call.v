module main

import json2 as json
import os
import openai

struct WeatherArgs {
	city string
}

fn main() {
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	)
	model := os.getenv_opt('OPENAI_MODEL') or { 'gpt-4o-mini' }
	tools := [
		openai.function_tool('get_weather', 'Get the current weather in a city',
			'{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}'),
	]
	mut messages := [openai.user_message('How is the weather in Paris?')]

	first := client.create_chat_completion(openai.ChatCompletionRequest{
		model:    model
		messages: messages
		tools:    tools
	})!
	tool_calls := first.choices[0].message.tool_calls
	if tool_calls.len == 0 {
		println(first.choices[0].message.content or { '' })
		return
	}

	// Answer every tool call, then ask again with the results attached.
	messages << first.choices[0].message
	for call in tool_calls {
		args := json.decode[WeatherArgs](call.function.arguments)!
		println('model called ${call.function.name}(${args.city})')
		messages << openai.tool_message(call.id, '{"temperature":12,"unit":"C"}')
	}
	final := client.create_chat_completion(openai.ChatCompletionRequest{
		model:    model
		messages: messages
		tools:    tools
	})!
	println(final.choices[0].message.content or { '' })
}
