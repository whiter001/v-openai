module openai

import json2 as json

// FineTuningJob is one fine-tuning job.
pub struct FineTuningJob {
pub:
	id               string
	object           string
	model            string
	fine_tuned_model string
	status           string
	training_file    string
	validation_file  string
	created_at       i64
	finished_at      i64
}

// FineTuningJobsList is the answer of GET /fine_tuning/jobs.
pub struct FineTuningJobsList {
pub:
	object   string
	data     []FineTuningJob
	has_more bool
}

// create_fine_tuning_job starts a fine-tuning job for a base model over an
// uploaded training file. `suffix` names the resulting model.
pub fn (c &Client) create_fine_tuning_job(model string, training_file string, suffix string) !FineTuningJob {
	mut fields := ['"model":${json.encode(model)}', '"training_file":${json.encode(training_file)}']
	if suffix != '' {
		fields << '"suffix":${json.encode(suffix)}'
	}
	body := c.post('/fine_tuning/jobs', '{${fields.join(',')}}')!
	return json.decode[FineTuningJob](body)!
}

// list_fine_tuning_jobs returns the account's fine-tuning jobs.
pub fn (c &Client) list_fine_tuning_jobs() !FineTuningJobsList {
	body := c.get('/fine_tuning/jobs')!
	return json.decode[FineTuningJobsList](body)!
}

// get_fine_tuning_job returns one fine-tuning job.
pub fn (c &Client) get_fine_tuning_job(id string) !FineTuningJob {
	body := c.get('/fine_tuning/jobs/${id}')!
	return json.decode[FineTuningJob](body)!
}

// cancel_fine_tuning_job cancels a running fine-tuning job.
pub fn (c &Client) cancel_fine_tuning_job(id string) !FineTuningJob {
	body := c.post('/fine_tuning/jobs/${id}/cancel', '{}')!
	return json.decode[FineTuningJob](body)!
}
