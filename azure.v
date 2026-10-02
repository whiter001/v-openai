module openai

import time

// AzureConfig configures an Azure OpenAI client: requests go to
// `{endpoint}/openai/deployments/{deployment}/...` with an `api-key` header
// and an `api-version` query parameter.
pub struct AzureConfig {
pub:
	api_key       string @[required]
	endpoint      string @[required]
	deployment    string @[required]
	api_version   string = '2024-10-21'
	read_timeout  i64    = 300 * time.second
	write_timeout i64    = 30 * time.second
	headers       map[string]string
}

// new_azure_client creates a Client talking to an Azure OpenAI deployment.
pub fn new_azure_client(config AzureConfig) Client {
	return new_client(
		api_key:       config.api_key
		base_url:      '${config.endpoint.trim_right('/')}/openai/deployments/${config.deployment}'
		auth_style:    .api_key
		query_params:  {
			'api-version': config.api_version
		}
		read_timeout:  config.read_timeout
		write_timeout: config.write_timeout
		headers:       config.headers
	)
}
