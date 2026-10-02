# openai

An OpenAI-compatible LLM API client for V, with first-class streaming.

Works with **OpenAI** and any compatible endpoint — **DeepSeek, Kimi, GLM,
Ollama**, vLLM, etc. — by changing `base_url`.

## Features

- **Responses API** (recommended for new integrations): `create_response` +
  `create_response_stream` with typed stream events, `previous_response_id`
  multi-turn chaining, reasoning effort, structured outputs
- **Chat Completions**: `create_chat_completion` +
  `create_chat_completion_stream` (SSE with incremental chunk callbacks)
- **Multimodal input**: text, image (URL/base64) and audio content parts
- **Tool calling**: function definitions, named `tool_choice`, parallel
  calls, tool call history
- **Structured outputs**: JSON mode and `json_schema` with strict flag
- **Embeddings**: `create_embedding`
- **Images**: `create_image` (DALL-E / gpt-image)
- **Audio**: `create_speech` (TTS), `create_transcription` (Whisper)
- **Moderations**: `create_moderation`
- **Models**: `list_models` / `get_model`
- **Files / Batches / Vector stores / Fine-tuning**: upload, list, get,
  delete, cancel
- **Azure OpenAI**: `new_azure_client` (deployment URLs, `api-key` header,
  `api-version` query)
- **Typed `ApiError`** with HTTP status and provider error code
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
	response := client.create_response(openai.CreateResponseRequest{
		model: 'gpt-4o-mini'
		input: 'Hello!'
	)!
	println(response.output_text())
}
```

Chat Completions remains fully supported for existing integrations:

```v
	response := client.create_chat_completion(
		model:       'gpt-4o-mini'
		messages:    [openai.user_message('Hello!')]
		temperature: 0.0
	)!
	println(response.choices[0].message.content or { '' })
```

## Azure OpenAI

```v
	client := openai.new_azure_client(
		api_key:    os.getenv('AZURE_OPENAI_API_KEY')
		endpoint:   'https://myresource.openai.azure.com'
		deployment: 'my-deployment'
	)
	// requests go to {endpoint}/openai/deployments/{deployment}/...
	// with an api-key header and ?api-version=2024-10-21
```

## Streaming

Stream callbacks are plain functions with a `voidptr` context (the shape
that compiles and runs identically across V toolchains); cast the context
inside the callback:

```v
fn print_chunk(_ voidptr, chunk openai.ChatCompletionChunk) {
	if chunk.choices.len != 0 {
		print(chunk.choices[0].delta.content)
		flush_stdout()
	}
}

client.create_chat_completion_stream(openai.ChatCompletionRequest{
	model:    'gpt-4o-mini'
	messages: [openai.user_message('Tell me a story.')]
}, unsafe { nil }, print_chunk)!
```

To observe mutations, pass a pointer and cast it back:

```v
fn sink_chunk(ctx voidptr, chunk openai.ChatCompletionChunk) {
	mut sink := unsafe { &ChunkSink(ctx) }
	sink.pieces << chunk.choices[0].delta.content
}
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
`backends.v`, `vision.v`, `responses.v`, `responses_stream.v`.

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
