module openai

import x.json2 as json

// Batch is one batch job.
pub struct Batch {
pub:
	id             string
	object         string
	endpoint       string
	status         string
	input_file_id  string
	output_file_id string
	error_file_id  string
	created_at     i64
	completed_at   i64
	failed_at      i64
	expired_at     i64
	request_counts BatchRequestCounts
	metadata       map[string]string
}

// BatchRequestCounts tracks a batch's request progress.
pub struct BatchRequestCounts {
pub:
	total     int
	completed int
	failed    int
}

// BatchesList is the answer of GET /batches.
pub struct BatchesList {
pub:
	object   string
	data     []Batch
	has_more bool
}

// create_batch creates a batch job for an endpoint ('/v1/chat/completions',
// '/v1/embeddings', '/v1/responses') with a '24h' completion window.
pub fn (c &Client) create_batch(input_file_id string, endpoint string, metadata map[string]string) !Batch {
	mut fields := ['"input_file_id":${json.encode(input_file_id)}',
		'"endpoint":${json.encode(endpoint)}', '"completion_window":"24h"']
	if metadata.len != 0 {
		fields << '"metadata":${json.encode(metadata)}'
	}
	body := c.post('/batches', '{${fields.join(',')}}')!
	return json.decode[Batch](body)!
}

// get_batch returns one batch job.
pub fn (c &Client) get_batch(id string) !Batch {
	body := c.get('/batches/${id}')!
	return json.decode[Batch](body)!
}

// list_batches returns the account's batch jobs.
pub fn (c &Client) list_batches() !BatchesList {
	body := c.get('/batches')!
	return json.decode[BatchesList](body)!
}

// cancel_batch cancels an in-progress batch job.
pub fn (c &Client) cancel_batch(id string) !Batch {
	body := c.post('/batches/${id}/cancel', '{}')!
	return json.decode[Batch](body)!
}
