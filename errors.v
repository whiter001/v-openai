module openai

import json2 as json

// ApiError is an error returned by the API itself (HTTP status >= 400).
pub struct ApiError {
pub:
	status  int
	code    string
	message string
}

pub fn (err ApiError) msg() string {
	if err.code != '' {
		return 'openai: HTTP ${err.status} (${err.code}): ${err.message}'
	}
	return 'openai: HTTP ${err.status}: ${err.message}'
}

pub fn (err ApiError) code() int {
	return err.status
}

struct ErrorEnvelope {
	error ErrorBody
}

struct ErrorBody {
	message string
	@type   string
	code    string
}

// decode_error_response turns an HTTP error response into an ApiError, falling
// back to the raw body when it is not the usual JSON error envelope.
fn decode_error_response(status int, body string) IError {
	envelope := json.decode[ErrorEnvelope](body) or {
		return ApiError{
			status:  status
			message: body
		}
	}
	return ApiError{
		status:  status
		code:    envelope.error.code
		message: envelope.error.message
	}
}
