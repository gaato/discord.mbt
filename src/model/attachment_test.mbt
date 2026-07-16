///|
test "attachment decodes a full fixture" {
  let fixture =
    #|{
    #|  "id": "905000000000000001",
    #|  "filename": "voice-message.ogg",
    #|  "title": "Voice message.ogg",
    #|  "description": "A short greeting",
    #|  "content_type": "audio/ogg",
    #|  "size": 123456,
    #|  "url": "https://cdn.discordapp.com/attachments/1/2/voice-message.ogg",
    #|  "proxy_url": "https://media.discordapp.net/attachments/1/2/voice-message.ogg",
    #|  "height": null,
    #|  "width": 1920,
    #|  "ephemeral": false,
    #|  "duration_secs": 3.5,
    #|  "waveform": "AQAFAAoPEA==",
    #|  "flags": 39,
    #|  "brand_new_field_from_discord": true
    #|}
  let attachment : @model.Attachment = @json.from_json(@json.parse(fixture))
  debug_inspect(
    attachment,
    content=(
      #|{
      #|  id: 905000000000000001,
      #|  filename: "voice-message.ogg",
      #|  title: Some("Voice message.ogg"),
      #|  description: Some("A short greeting"),
      #|  content_type: Some("audio/ogg"),
      #|  size: 123456,
      #|  url: "https://cdn.discordapp.com/attachments/1/2/voice-message.ogg",
      #|  proxy_url: "https://media.discordapp.net/attachments/1/2/voice-message.ogg",
      #|  height: Some(Null),
      #|  width: Some(Value(1920)),
      #|  ephemeral: Some(false),
      #|  duration_secs: Some(3.5),
      #|  waveform: Some("AQAFAAoPEA=="),
      #|  flags: Some(39),
      #|  placeholder: None,
      #|  placeholder_version: None,
      #|  clip_participants: None,
      #|  clip_created_at: None,
      #|  application: None,
      #|}
    ),
  )
}

///|
test "attachment decodes required fields only" {
  let fixture =
    #|{
    #|  "id": "905000000000000001",
    #|  "filename": "notes.txt",
    #|  "size": 42,
    #|  "url": "https://cdn.discordapp.com/notes.txt",
    #|  "proxy_url": "https://media.discordapp.net/notes.txt"
    #|}
  let attachment : @model.Attachment = @json.from_json(@json.parse(fixture))
  debug_inspect(
    attachment,
    content=(
      #|{
      #|  id: 905000000000000001,
      #|  filename: "notes.txt",
      #|  title: None,
      #|  description: None,
      #|  content_type: None,
      #|  size: 42,
      #|  url: "https://cdn.discordapp.com/notes.txt",
      #|  proxy_url: "https://media.discordapp.net/notes.txt",
      #|  height: None,
      #|  width: None,
      #|  ephemeral: None,
      #|  duration_secs: None,
      #|  waveform: None,
      #|  flags: None,
      #|  placeholder: None,
      #|  placeholder_version: None,
      #|  clip_participants: None,
      #|  clip_created_at: None,
      #|  application: None,
      #|}
    ),
  )
}

///|
test "attachment encode omits absent optional fields" {
  let attachment : @model.Attachment = {
    id: Id(1UL),
    filename: "notes.txt",
    title: None,
    description: None,
    content_type: None,
    size: 42,
    url: "https://cdn.discordapp.com/notes.txt",
    proxy_url: "https://media.discordapp.net/notes.txt",
    height: None,
    width: None,
    ephemeral: None,
    duration_secs: None,
    waveform: None,
    flags: None,
    placeholder: None,
    placeholder_version: None,
    clip_participants: None,
    clip_created_at: None,
    application: None,
  }
  inspect(
    attachment.to_json().stringify(),
    content=(
      #|{"id":"1","filename":"notes.txt","size":42,"url":"https://cdn.discordapp.com/notes.txt","proxy_url":"https://media.discordapp.net/notes.txt"}
    ),
  )
}

///|
test "attachment flags combine and preserve unknown bits" {
  let flags = @model.AttachmentFlags::is_clip() |
    @model.AttachmentFlags::is_thumbnail() |
    @model.AttachmentFlags::is_remix()
  inspect(
    flags.bits(),
    content=(
      #|7
    ),
  )
  assert_true(flags.contains(@model.AttachmentFlags::is_remix()))
  let unknown_bits = (1UL << 60) | flags.bits()
  let unknown = @model.AttachmentFlags::from_bits(unknown_bits)
  let encoded = unknown.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|1152921504606846983
    ),
  )
  let decoded : @model.AttachmentFlags = @json.from_json(@json.parse(encoded))
  assert_true(decoded.bits() == unknown_bits)
}

///|
test "attachment request omits absent fields" {
  let full : @model.AttachmentRequest = {
    id: Id(123UL),
    filename: Some("cat.png"),
    title: Some("Cat"),
    description: Some("a cat"),
    duration_secs: Some(1.5),
    waveform: Some("AAAA"),
    is_spoiler: Some(true),
  }
  json_inspect(full, content={
    "id": "123",
    "filename": "cat.png",
    "title": "Cat",
    "description": "a cat",
    "duration_secs": 1.5,
    "waveform": "AAAA",
    "is_spoiler": true,
  })
  let keep_only : @model.AttachmentRequest = {
    id: Id(123UL),
    filename: None,
    title: None,
    description: None,
    duration_secs: None,
    waveform: None,
    is_spoiler: None,
  }
  json_inspect(keep_only, content={ "id": "123" })
}
