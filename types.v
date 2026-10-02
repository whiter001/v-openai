module openai

// ChatMessage is a single message in a chat conversation. `content` is none
// for assistant messages that only carry tool calls.
pub struct ChatMessage {
pub:
	role         string
	content      ?string
	name         string     @[omitempty]
	tool_calls   []ToolCall @[omitempty]
	tool_call_id string     @[omitempty]
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
