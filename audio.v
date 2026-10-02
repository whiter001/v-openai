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
