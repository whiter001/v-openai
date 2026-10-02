module openai

import rand

// multipart_form_data renders a multipart/form-data body with plain text
// fields plus one file part. The file endpoints (uploads, transcriptions)
// all take exactly one file per request.
fn multipart_form_data(boundary string, fields map[string]string, file_field string, file_name string, file_content []u8, file_content_type string) string {
	mut body := ''
	for name, value in fields {
		body += '--${boundary}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n'
	}
	body += '--${boundary}\r\nContent-Disposition: form-data; name="${file_field}"; filename="${file_name}"\r\nContent-Type: ${file_content_type}\r\n\r\n'
	body += file_content.bytestr()
	body += '\r\n--${boundary}--\r\n'
	return body
}

// multipart_boundary returns a random boundary that will not appear in
// ordinary payloads.
fn multipart_boundary() string {
	return 'vopenai${rand.hex(24)}'
}
