module openai

import json2 as json

// SpeechRequest is the payload of POST /audio/speech. `voice` is e.g.
// 'alloy'; `response_format` is 'mp3' (default), 'opus', 'aac', 'flac',
// 'wav' or 'pcm'.
pub struct SpeechRequest {
pub mut:
	model           string @[required]
	input           string @[required]
	voice           string @[required]
	response_format string
	speed           ?f64
	instructions    string
}

// create_speech synthesizes speech from text and returns the raw audio bytes.
pub fn (c &Client) create_speech(request SpeechRequest) ![]u8 {
	body := c.post('/audio/speech', encode_speech_request(request))!
	return body.bytes()
}

// TranscriptionRequest is the payload of POST /audio/transcriptions.
// `language` is an ISO-639-1 code; `response_format` is 'json' (default),
// 'text', 'srt', 'verbose_json' or 'vtt'.
pub struct TranscriptionRequest {
pub mut:
	model           string @[required]
	file_name       string @[required]
	file_content    []u8   @[required]
	language        string
	prompt          string
	response_format string
	temperature     ?f64
}

// create_transcription transcribes an audio file and returns the response
// body: JSON by default, plain text for the text/srt/vtt formats.
pub fn (c &Client) create_transcription(request TranscriptionRequest) !string {
	boundary := multipart_boundary()
	mut fields := {
		'model': request.model
	}
	if request.language != '' {
		fields['language'] = request.language
	}
	if request.prompt != '' {
		fields['prompt'] = request.prompt
	}
	if request.response_format != '' {
		fields['response_format'] = request.response_format
	}
	if temperature := request.temperature {
		fields['temperature'] = temperature.str()
	}
	body := multipart_form_data(boundary, fields, 'file', request.file_name, request.file_content,
		'application/octet-stream')
	return c.post_with_content_type('/audio/transcriptions', body, 'multipart/form-data; boundary=${boundary}')
}

fn encode_speech_request(request SpeechRequest) string {
	mut fields := ['"model":${json.encode(request.model)}', '"input":${json.encode(request.input)}',
		'"voice":${json.encode(request.voice)}']
	if request.response_format != '' {
		fields << '"response_format":${json.encode(request.response_format)}'
	}
	if speed := request.speed {
		fields << '"speed":${speed}'
	}
	if request.instructions != '' {
		fields << '"instructions":${json.encode(request.instructions)}'
	}
	return '{${fields.join(',')}}'
}
