module openai

import x.json2 as json

fn test_list_models_against_a_loopback_server() {
	mut mock := start_mock_server('HTTP/1.1 200 OK', 'application/json',
		'{"object":"list","data":[{"id":"gpt-4o-mini","object":"model","created":1710000000,"owned_by":"system"}]}')
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:                  'sk-test'
		base_url:                 mock.base_url()
		// The mocks below are one-purpose loopback servers; keep net.http's
		// keep-alive pool from reusing a stale connection across them.
		disable_connection_reuse: true
	)

	models := client.list_models()!

	assert models.data.len == 1
	assert models.data[0].id == 'gpt-4o-mini'
	assert mock.request_head()[0] == 'GET /v1/models HTTP/1.1'
}

fn test_get_model_against_a_loopback_server() {
	mut mock := start_mock_server('HTTP/1.1 200 OK', 'application/json',
		'{"id":"gpt-4o-mini","object":"model","created":1710000000,"owned_by":"system"}')
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:                  'sk-test'
		base_url:                 mock.base_url()
		// The mocks below are one-purpose loopback servers; keep net.http's
		// keep-alive pool from reusing a stale connection across them.
		disable_connection_reuse: true
	)

	model := client.get_model('gpt-4o-mini')!

	assert model.owned_by == 'system'
	assert mock.request_head()[0] == 'GET /v1/models/gpt-4o-mini HTTP/1.1'
}

fn test_create_moderation_against_a_loopback_server() {
	body := '{"id":"modr-1","model":"omni-moderation-latest","results":[{"flagged":true,"categories":{"harassment":true,"harassment/threatening":false,"hate":false,"hate/threatening":false,"illicit":false,"illicit/violent":false,"self-harm":false,"self-harm/intent":false,"self-harm/instructions":false,"sexual":false,"sexual/minors":false,"violence":true,"violence/graphic":false},"category_scores":{"harassment":0.9,"harassment/threatening":0.01,"hate":0.0,"hate/threatening":0.0,"illicit":0.0,"illicit/violent":0.0,"self-harm":0.0,"self-harm/intent":0.0,"self-harm/instructions":0.0,"sexual":0.0,"sexual/minors":0.0,"violence":0.8,"violence/graphic":0.0}}]}'
	mut mock := start_mock_server('HTTP/1.1 200 OK', 'application/json', body)
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:                  'sk-test'
		base_url:                 mock.base_url()
		// The mocks below are one-purpose loopback servers; keep net.http's
		// keep-alive pool from reusing a stale connection across them.
		disable_connection_reuse: true
	)

	response := client.create_moderation(ModerationRequest{
		input: ['some text']
	})!

	assert response.results.len == 1
	result := response.results[0]
	assert result.flagged
	assert result.categories.harassment
	assert !result.categories.hate
	assert result.categories.violence
	assert result.category_scores.harassment == 0.9
	assert result.category_scores.violence == 0.8
	assert mock.request_head()[0] == 'POST /v1/moderations HTTP/1.1'
}

fn test_create_image_decodes_urls_and_b64() {
	body := '{"created":1740000000,"data":[{"url":"https://example.com/1.png","revised_prompt":"a cat"},{"b64_json":"aGVsbG8="}]}'
	response := json.decode[ImageResponse](body)!
	assert response.data.len == 2
	assert response.data[0].url == 'https://example.com/1.png'
	assert response.data[0].revised_prompt == 'a cat'
	assert response.data[1].b64_json == 'aGVsbG8='
}

fn test_encode_image_request_sends_only_set_fields() {
	encoded := encode_image_request(ImageRequest{
		prompt: 'a cat'
		n:      2
		size:   '1024x1024'
	})
	assert encoded == '{"prompt":"a cat","n":2,"size":"1024x1024"}'
}

fn test_create_speech_returns_raw_bytes() {
	mut mock := start_mock_server('HTTP/1.1 200 OK', 'audio/mpeg', '\x89PNG-not-really-audio')
	defer {
		mock.listener.close() or {}
	}
	client := new_client(
		api_key:                  'sk-test'
		base_url:                 mock.base_url()
		// The mocks below are one-purpose loopback servers; keep net.http's
		// keep-alive pool from reusing a stale connection across them.
		disable_connection_reuse: true
	)

	audio := client.create_speech(SpeechRequest{
		model: 'tts-1'
		input: 'hello'
		voice: 'alloy'
	})!

	assert audio == '\x89PNG-not-really-audio'.bytes()
	assert mock.request_head()[0] == 'POST /v1/audio/speech HTTP/1.1'
}

fn test_encode_speech_request() {
	encoded := encode_speech_request(SpeechRequest{
		model: 'tts-1-hd'
		input: 'hello'
		voice: 'nova'
		speed: 1.5
	})
	assert encoded == '{"model":"tts-1-hd","input":"hello","voice":"nova","speed":1.5}'
}
