module openai

import x.json2 as json

// ModerationRequest is the payload of POST /moderations. `model` is e.g.
// 'omni-moderation-latest'; empty uses the API default.
pub struct ModerationRequest {
pub mut:
	input []string @[required]
	model string
}

// ModerationResponse is the answer of the moderation endpoint.
pub struct ModerationResponse {
pub:
	id      string
	model   string
	results []ModerationResult
}

// ModerationResult is the verdict for one input text.
pub struct ModerationResult {
pub:
	flagged         bool
	categories      ModerationCategories
	category_scores ModerationCategoryScores
}

// ModerationCategories are the boolean violation flags.
pub struct ModerationCategories {
pub:
	harassment             bool
	harassment_threatening bool @[json: 'harassment/threatening']
	hate                   bool
	hate_threatening       bool @[json: 'hate/threatening']
	illicit                bool
	illicit_violent        bool @[json: 'illicit/violent']
	self_harm              bool @[json: 'self-harm']
	self_harm_intent       bool @[json: 'self-harm/intent']
	self_harm_instructions bool @[json: 'self-harm/instructions']
	sexual                 bool
	sexual_minors          bool @[json: 'sexual/minors']
	violence               bool
	violence_graphic       bool @[json: 'violence/graphic']
}

// ModerationCategoryScores are the per-category confidence scores.
pub struct ModerationCategoryScores {
pub:
	harassment             f64
	harassment_threatening f64 @[json: 'harassment/threatening']
	hate                   f64
	hate_threatening       f64 @[json: 'hate/threatening']
	illicit                f64
	illicit_violent        f64 @[json: 'illicit/violent']
	self_harm              f64 @[json: 'self-harm']
	self_harm_intent       f64 @[json: 'self-harm/intent']
	self_harm_instructions f64 @[json: 'self-harm/instructions']
	sexual                 f64
	sexual_minors          f64 @[json: 'sexual/minors']
	violence               f64
	violence_graphic       f64 @[json: 'violence/graphic']
}

// create_moderation classifies the input texts against the moderation
// categories.
pub fn (c &Client) create_moderation(request ModerationRequest) !ModerationResponse {
	body := c.post('/moderations', encode_moderation_request(request))!
	return json.decode[ModerationResponse](body)!
}

fn encode_moderation_request(request ModerationRequest) string {
	mut fields := ['"input":${json.encode(request.input)}']
	if request.model != '' {
		fields << '"model":${json.encode(request.model)}'
	}
	return '{${fields.join(',')}}'
}
