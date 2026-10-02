module openai

import x.json2 as json

// ImageRequest is the payload of POST /images/generations. `size` is e.g.
// '1024x1024'; `quality` 'standard'/'hd'; `style' 'vivid'/'natural';
// `response_format` 'url' or 'b64_json'. Empty fields use the API defaults.
pub struct ImageRequest {
pub mut:
	prompt          string @[required]
	model           string
	n               ?int
	size            string
	quality         string
	style           string
	response_format string
	user            string
}

// ImageResponse is the answer of the images endpoint.
pub struct ImageResponse {
pub:
	created i64
	data    []ImageData
}

// ImageData is one generated image: a URL or base64 JSON, depending on the
// requested response_format.
pub struct ImageData {
pub:
	url            string
	b64_json       string
	revised_prompt string
}

// create_image generates images from a prompt.
pub fn (c &Client) create_image(request ImageRequest) !ImageResponse {
	body := c.post('/images/generations', encode_image_request(request))!
	return json.decode[ImageResponse](body)!
}

fn encode_image_request(request ImageRequest) string {
	mut fields := ['"prompt":${json.encode(request.prompt)}']
	if request.model != '' {
		fields << '"model":${json.encode(request.model)}'
	}
	if n := request.n {
		fields << '"n":${n}'
	}
	if request.size != '' {
		fields << '"size":${json.encode(request.size)}'
	}
	if request.quality != '' {
		fields << '"quality":${json.encode(request.quality)}'
	}
	if request.style != '' {
		fields << '"style":${json.encode(request.style)}'
	}
	if request.response_format != '' {
		fields << '"response_format":${json.encode(request.response_format)}'
	}
	if request.user != '' {
		fields << '"user":${json.encode(request.user)}'
	}
	return '{${fields.join(',')}}'
}
