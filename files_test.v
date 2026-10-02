// vtest retry: 3
module openai

import x.json2 as json

fn test_upload_file_sends_a_multipart_body() {
	mut mock := start_mock_server('HTTP/1.1 200 OK', 'application/json',
		'{"id":"file-1","object":"file","bytes":12,"created_at":1740000000,"filename":"data.jsonl","purpose":"batch"}')
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

	file := client.upload_file('batch', 'data.jsonl', '{"a":1}\n{"a":2}\n'.bytes())!

	assert file.id == 'file-1'
	assert file.bytes == 12
	head := mock.request_head()
	assert head[0] == 'POST /v1/files HTTP/1.1'
	assert head.any(it.to_lower().starts_with('content-type: multipart/form-data; boundary='))
}

fn test_create_transcription_sends_the_model_field() {
	mut mock := start_mock_server('HTTP/1.1 200 OK', 'application/json', '{"text":"hello world"}')
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

	text := client.create_transcription(TranscriptionRequest{
		model:        whisper_1
		file_name:    'speech.mp3'
		file_content: [u8(1), 2, 3]
	})!

	assert text == '{"text":"hello world"}'
	assert mock.request_head()[0] == 'POST /v1/audio/transcriptions HTTP/1.1'
}

fn test_decode_batch() {
	body := '{"id":"batch_1","object":"batch","endpoint":"/v1/chat/completions","status":"completed","input_file_id":"file-1","output_file_id":"file-2","error_file_id":"","created_at":1740000000,"completed_at":1740000100,"failed_at":0,"expired_at":0,"request_counts":{"total":10,"completed":9,"failed":1},"metadata":{"job":"nightly"}}'
	batch := json.decode[Batch](body)!
	assert batch.status == 'completed'
	assert batch.request_counts.total == 10
	assert batch.request_counts.failed == 1
	assert batch.metadata['job'] == 'nightly'
}

fn test_decode_vector_store() {
	body := '{"id":"vs_1","object":"vector_store","created_at":1740000000,"name":"docs","status":"completed","usage_bytes":4096,"file_counts":{"in_progress":0,"completed":3,"failed":0,"cancelled":0,"total":3}}'
	store := json.decode[VectorStore](body)!
	assert store.name == 'docs'
	assert store.file_counts.completed == 3
	assert store.usage_bytes == 4096
}

fn test_decode_fine_tuning_job() {
	body := '{"id":"ftjob-1","object":"fine_tuning.job","model":"gpt-4o-mini","fine_tuned_model":"ft:gpt-4o-mini:org:x","status":"succeeded","training_file":"file-1","validation_file":"","created_at":1740000000,"finished_at":1740001000}'
	job := json.decode[FineTuningJob](body)!
	assert job.status == 'succeeded'
	assert job.fine_tuned_model == 'ft:gpt-4o-mini:org:x'
}

fn test_delete_file_decodes_deleted_object() {
	body := '{"id":"file-1","object":"file","deleted":true}'
	deleted := json.decode[DeletedObject](body)!
	assert deleted.deleted
}
