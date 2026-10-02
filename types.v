module openai

// ChatMessage is a single message in a chat conversation. `content` is none
// for assistant messages that only carry tool calls; `multi_content` carries
// multimodal input (text, images, audio) and takes precedence over `content`
// when set.
pub struct ChatMessage {
pub:
	role          string
	content       ?string
	name          string        @[omitempty]
	tool_calls    []ToolCall    @[omitempty]
	tool_call_id  string        @[omitempty]
	multi_content []ContentPart @[omitempty]
}

// ContentPart is one part of a multimodal `content` array. `type` is 'text',
// 'image_url' or 'input_audio'; only the matching payload field is used.
pub struct ContentPart {
pub:
	@type       string
	text        string
	image_url   ImageURL
	input_audio InputAudio
}

// ImageURL addresses an image by URL or base64 data URI. `detail` is 'auto',
// 'low' or 'high'; empty means the API default ('auto').
pub struct ImageURL {
pub:
	url    string
	detail string @[omitempty]
}

// InputAudio carries base64 encoded audio. `format` is 'wav' or 'mp3'.
pub struct InputAudio {
pub:
	data   string
	format string
}

// text_part builds a text ContentPart.
pub fn text_part(text string) ContentPart {
	return ContentPart{
		@type: 'text'
		text:  text
	}
}

// image_part builds an image ContentPart with the default ('auto') detail.
pub fn image_part(url string) ContentPart {
	return ContentPart{
		@type:     'image_url'
		image_url: ImageURL{
			url: url
		}
	}
}

// image_part_with_detail builds an image ContentPart with an explicit detail
// level ('low' or 'high').
pub fn image_part_with_detail(url string, detail string) ContentPart {
	return ContentPart{
		@type:     'image_url'
		image_url: ImageURL{
			url:    url
			detail: detail
		}
	}
}

// audio_part builds an input_audio ContentPart from base64 encoded audio.
pub fn audio_part(data string, format string) ContentPart {
	return ContentPart{
		@type:       'input_audio'
		input_audio: InputAudio{
			data:   data
			format: format
		}
	}
}

// user_message_parts builds a multimodal user ChatMessage.
pub fn user_message_parts(parts []ContentPart) ChatMessage {
	return ChatMessage{
		role:          'user'
		multi_content: parts
	}
}

// system_message builds a system ChatMessage.
pub fn system_message(content string) ChatMessage {
	return ChatMessage{
		role:    'system'
		content: content
	}
}

// user_message builds a user ChatMessage.
pub fn user_message(content string) ChatMessage {
	return ChatMessage{
		role:    'user'
		content: content
	}
}

// assistant_message builds an assistant ChatMessage.
pub fn assistant_message(content string) ChatMessage {
	return ChatMessage{
		role:    'assistant'
		content: content
	}
}

// tool_message builds the tool ChatMessage that answers a ToolCall.
pub fn tool_message(tool_call_id string, content string) ChatMessage {
	return ChatMessage{
		role:         'tool'
		tool_call_id: tool_call_id
		content:      content
	}
}

// ToolCall is a function invocation the model asked for. `arguments` is a
// JSON string, exactly as the API defines it.
pub struct ToolCall {
pub:
	id       string
	@type    string @[json: 'type']
	function ToolCallFunction
}

// ToolCallFunction carries the name and JSON arguments of a ToolCall.
pub struct ToolCallFunction {
pub:
	name      string
	arguments string
}

// Tool is a function the model may call.
pub struct Tool {
pub:
	@type    string = 'function' @[json: 'type']
	function FunctionDefinition
}

// FunctionDefinition describes a callable function. `parameters` is a JSON
// Schema document and is embedded in the request verbatim.
pub struct FunctionDefinition {
pub:
	name        string
	description string
	parameters  string
}

// function_tool builds a function Tool from a JSON Schema object.
pub fn function_tool(name string, description string, parameters_json_schema string) Tool {
	return Tool{
		function: FunctionDefinition{
			name:        name
			description: description
			parameters:  parameters_json_schema
		}
	}
}

// Usage is the token accounting of a response.
pub struct Usage {
pub:
	prompt_tokens     int
	completion_tokens int
	total_tokens      int
}

// ResponseFormat selects the output format, for example
// `ResponseFormat{ @type: 'json_object' }` for JSON mode.
pub struct ResponseFormat {
pub:
	@type string @[json: 'type']
}
