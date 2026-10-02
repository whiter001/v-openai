# openai

An OpenAI-compatible LLM API client for V, with first-class streaming.

Works with **OpenAI** and any compatible endpoint — **DeepSeek, Kimi, GLM,
Ollama**, vLLM, etc. — by changing `base_url`.

## Features

- Chat completions: `create_chat_completion`
- Streaming (SSE) with incremental chunk callbacks: `create_chat_completion_stream`
- Tool calling (function definitions, tool call history, tool results)
- Embeddings: `create_embedding`
- Typed `ApiError` with HTTP status and provider error code
- Zero dependencies beyond V's standard library

## Install

```sh
v install whiter001.openai
```

Then import it with its full vpm name (the module binds as `openai`):

```v
import whiter001.openai
```

(Inside this repository, `v link` lets the examples use plain `import openai`.)

## Quick start

```v
import os
import openai

fn main() {
	client := openai.new_client(
		api_key:  os.getenv('OPENAI_API_KEY')
		base_url: os.getenv_opt('OPENAI_BASE_URL') or { 'https://api.openai.com/v1' }
	)
	response := client.create_chat_completion(
		model:       'gpt-4o-mini'
		messages:    [openai.user_message('Hello!')]
		temperature: 0.0
	)!
	println(response.choices[0].message.content or { '' })
}
```

## Streaming

Streaming callbacks take an explicit context (V closures cannot be stored in
struct fields); pass a reference type to observe mutations:

```v
struct Printer {}

fn print_chunk(_ Printer, chunk openai.ChatCompletionChunk) {
	if chunk.choices.len != 0 {
		print(chunk.choices[0].delta.content)
		flush_stdout()
	}
}

client.create_chat_completion_stream(openai.ChatCompletionRequest{
	model:    'gpt-4o-mini'
	messages: [openai.user_message('Tell me a story.')]
}, Printer{}, print_chunk)!
```

## Tool calling

```v
tools := [
	openai.function_tool('get_weather', 'Get the current weather in a city',
		'{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}'),
]
first := client.create_chat_completion(model: model, messages: messages, tools: tools)!
// answer the tool calls, then continue the conversation:
messages << first.choices[0].message
for call in first.choices[0].message.tool_calls {
	messages << openai.tool_message(call.id, '{"temperature":12,"unit":"C"}')
}
final := client.create_chat_completion(model: model, messages: messages, tools: tools)!
```

See `examples/` for complete programs: `chat.v`, `stream.v`, `tool_call.v`,
`backends.v`.

## Other providers

| Provider | `base_url`                              |
|----------|------------------------------------------|
| OpenAI   | `https://api.openai.com/v1` (default)    |
| DeepSeek | `https://api.deepseek.com/v1`            |
| Kimi     | `https://api.moonshot.cn/v1`             |
| GLM      | `https://open.bigmodel.cn/api/paas/v4`   |
| Ollama   | `http://localhost:11434/v1`              |

Extra provider headers (for example Azure-style keys) can be passed via
`ClientConfig.headers`.

## Design notes

- Request encoding is deliberate about defaults: only options you set are
  sent. `temperature: 0.0` stays on the wire; an unset option lets the API
  default apply.
- Streaming reassembles server-sent events from arbitrary TCP chunks, so
  chunk boundaries never corrupt events.
- Streaming uses plain-function callbacks with an explicit context parameter,
  because V closures stored in struct fields lose their captured variables.
- Errors from the API are decoded into `openai.ApiError`:

```v
client.create_chat_completion(... ) or {
	if err is openai.ApiError {
		eprintln('HTTP ${err.status} (${err.code}): ${err.message}')
	}
	return
}
```

## Development

```sh
v fmt -w .
v test .
v link                    # symlink the module into VMODULES (needed for examples)
v -check examples/chat.v
```

The loopback tests need no credentials. The integration tests only run when
`OPENAI_API_KEY` is set (`OPENAI_BASE_URL` / `OPENAI_MODEL` optional):

```sh
OPENAI_API_KEY=sk-... v test .
```

## License

MIT
