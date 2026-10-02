module openai

fn test_azure_client_uses_api_key_header_and_version_query() {
	mock := start_mock_server('HTTP/1.1 200 OK', 'application/json', mock_chat_body)
	defer {
		mock.listener.close() or {}
	}
	client := new_azure_client(
		api_key:    'azure-key'
		endpoint:   mock.base_url().all_before('/v1')
		deployment: 'my-deployment'
	)

	response := client.create_chat_completion(ChatCompletionRequest{
		model:    'gpt-4o-mini'
		messages: [user_message('hi')]
	})!

	assert response.choices[0].message.content or { '' } == 'Hello!'
	head := mock.request_head()
	assert head[0].starts_with('POST /openai/deployments/my-deployment/chat/completions?api-version=')
	assert head.any(it.to_lower() == 'api-key: azure-key')
	assert !head.any(it.to_lower().starts_with('authorization:'))
}

fn test_bearer_client_sends_no_query_params_by_default() {
	client := new_client(
		api_key:  'sk-test'
		base_url: 'http://127.0.0.1:1/v1'
	)
	assert client.url('/chat/completions') == 'http://127.0.0.1:1/v1/chat/completions'
}
