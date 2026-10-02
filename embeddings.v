module openai

import json2 as json

// EmbeddingRequest is the payload of POST /embeddings. Pass a single text as
// `[text]`; `encoding_format` is 'float' or 'base64', empty for the default.
pub struct EmbeddingRequest {
pub mut:
	model           string   @[required]
	input           []string @[required]
	encoding_format string
}

// Embedding is one vector of an EmbeddingResponse.
pub struct Embedding {
pub:
	object    string
	index     int
	embedding []f32
}

// EmbeddingResponse is the answer of the embeddings endpoint.
pub struct EmbeddingResponse {
pub:
	object string
	data   []Embedding
	model  string
	usage  Usage
}

// create_embedding vectorizes the input texts.
pub fn (c &Client) create_embedding(request EmbeddingRequest) !EmbeddingResponse {
	body := c.post('/embeddings', encode_embedding_request(request))!
	return json.decode[EmbeddingResponse](body)!
}

fn encode_embedding_request(request EmbeddingRequest) string {
	mut fields := ['"model":${json.encode(request.model)}', '"input":${json.encode(request.input)}']
	if request.encoding_format != '' {
		fields << '"encoding_format":${json.encode(request.encoding_format)}'
	}
	return '{${fields.join(',')}}'
}
