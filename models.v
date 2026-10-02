module openai

import json2 as json

// Model is one entry of the models endpoint.
pub struct Model {
pub:
	id       string
	object   string
	created  i64
	owned_by string
}

// ModelsList is the answer of GET /models.
pub struct ModelsList {
pub:
	object string
	data   []Model
}

// list_models returns the models available to the API key.
pub fn (c &Client) list_models() !ModelsList {
	body := c.get('/models')!
	return json.decode[ModelsList](body)!
}

// get_model returns one model by id.
pub fn (c &Client) get_model(id string) !Model {
	body := c.get('/models/${id}')!
	return json.decode[Model](body)!
}
