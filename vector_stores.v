module openai

import x.json2 as json

// VectorStore is one vector store. Vector store calls require the
// `OpenAI-Beta: assistants=v2` header; pass it via ClientConfig.headers.
pub struct VectorStore {
pub:
	id          string
	object      string
	created_at  i64
	name        string
	status      string
	usage_bytes i64
	file_counts VectorStoreFileCounts
}

// VectorStoreFileCounts tracks a store's file processing states.
pub struct VectorStoreFileCounts {
pub:
	in_progress int
	completed   int
	failed      int
	cancelled   int
	total       int
}

// VectorStoresList is the answer of GET /vector_stores.
pub struct VectorStoresList {
pub:
	object   string
	data     []VectorStore
	has_more bool
}

// create_vector_store creates a vector store, optionally pre-attaching
// files.
pub fn (c &Client) create_vector_store(name string, file_ids []string) !VectorStore {
	mut fields := ['"name":${json.encode(name)}']
	if file_ids.len != 0 {
		fields << '"file_ids":${json.encode(file_ids)}'
	}
	body := c.post('/vector_stores', '{${fields.join(',')}}')!
	return json.decode[VectorStore](body)!
}

// list_vector_stores returns the account's vector stores.
pub fn (c &Client) list_vector_stores() !VectorStoresList {
	body := c.get('/vector_stores')!
	return json.decode[VectorStoresList](body)!
}

// get_vector_store returns one vector store.
pub fn (c &Client) get_vector_store(id string) !VectorStore {
	body := c.get('/vector_stores/${id}')!
	return json.decode[VectorStore](body)!
}

// delete_vector_store removes one vector store.
pub fn (c &Client) delete_vector_store(id string) !DeletedObject {
	body := c.delete('/vector_stores/${id}')!
	return json.decode[DeletedObject](body)!
}
