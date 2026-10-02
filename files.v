module openai

import json2 as json

// FileObject is one uploaded file.
pub struct FileObject {
pub:
	id         string
	object     string
	bytes      int
	created_at i64
	filename   string
	purpose    string
}

// FilesList is the answer of GET /files.
pub struct FilesList {
pub:
	object string
	data   []FileObject
}

// DeletedObject is the answer of a delete call.
pub struct DeletedObject {
pub:
	id      string
	object  string
	deleted bool
}

// upload_file uploads one file for a purpose ('batch', 'fine-tune',
// 'assistants', ...).
pub fn (c &Client) upload_file(purpose string, file_name string, content []u8) !FileObject {
	boundary := multipart_boundary()
	body := multipart_form_data(boundary, {
		'purpose': purpose
	}, 'file', file_name, content, 'application/octet-stream')
	response := c.post_with_content_type('/files', body, 'multipart/form-data; boundary=${boundary}')!
	return json.decode[FileObject](response)!
}

// list_files returns the files of the account.
pub fn (c &Client) list_files() !FilesList {
	body := c.get('/files')!
	return json.decode[FilesList](body)!
}

// get_file returns one file's metadata.
pub fn (c &Client) get_file(id string) !FileObject {
	body := c.get('/files/${id}')!
	return json.decode[FileObject](body)!
}

// get_file_content downloads a file's raw content.
pub fn (c &Client) get_file_content(id string) ![]u8 {
	body := c.get('/files/${id}/content')!
	return body.bytes()
}

// delete_file removes one file.
pub fn (c &Client) delete_file(id string) !DeletedObject {
	body := c.delete('/files/${id}')!
	return json.decode[DeletedObject](body)!
}
