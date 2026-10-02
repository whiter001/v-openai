module openai

// Common model identifiers. Model names are accepted as plain strings
// everywhere, so newer models work without a constant.

// chat models
pub const gpt4o = 'gpt-4o'
pub const gpt4o_mini = 'gpt-4o-mini'
pub const gpt41 = 'gpt-4.1'
pub const gpt41_mini = 'gpt-4.1-mini'
pub const gpt41_nano = 'gpt-4.1-nano'
pub const o3 = 'o3'
pub const o4_mini = 'o4-mini'

// image models
pub const dall_e_3 = 'dall-e-3'
pub const dall_e_2 = 'dall-e-2'
pub const gpt_image_1 = 'gpt-image-1'

// audio models
pub const tts_1 = 'tts-1'
pub const tts_1_hd = 'tts-1-hd'
pub const gpt4o_mini_tts = 'gpt-4o-mini-tts'
pub const whisper_1 = 'whisper-1'

// embedding models
pub const text_embedding_3_small = 'text-embedding-3-small'
pub const text_embedding_3_large = 'text-embedding-3-large'
pub const text_embedding_ada_002 = 'text-embedding-ada-002'

// moderation models
pub const omni_moderation_latest = 'omni-moderation-latest'
pub const text_moderation_latest = 'text-moderation-latest'
