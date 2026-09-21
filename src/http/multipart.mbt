///|
/// One file to upload in a `multipart/form-data` request, next to the
/// `payload_json` part. Construct with `FileUpload(...)`.
pub struct FileUpload {
  priv filename : String
  priv content : Bytes
  priv content_type : String
  priv description : String?
  priv title : String?
  priv duration_secs : Double?
  priv waveform : String?
  priv is_spoiler : Bool?
}

///|
/// The supplied filename, before multipart encoding.
pub fn FileUpload::filename(self : FileUpload) -> String {
  self.filename
}

///|
/// Immutable uploaded bytes. Never included in debug output.
pub fn FileUpload::content(self : FileUpload) -> Bytes {
  self.content
}

///|
/// The supplied media type.
pub fn FileUpload::content_type(self : FileUpload) -> String {
  self.content_type
}

///|
/// Keep uploaded bytes out of diagnostics while allowing captured interaction
/// outcomes to derive Debug.
pub impl Debug for FileUpload with fn to_repr(self) {
  Repr(
    (self.filename, self.content.length(), self.content_type, self.description),
  )
}

///|
/// Describe one file to upload. `description` becomes the attachment's
/// alt text where the endpoint supports it; `title`, `duration_secs`,
/// `waveform`, and `is_spoiler` fill the matching attachment-request fields
/// (the latter two are required for voice messages).
///
/// ```mbt check
/// test "describe attachments in payload_json" {
///   let files = [
///     @http.FileUpload(
///       "cat.png",
///       b"PNG",
///       content_type="image/png",
///       description="a cat",
///       is_spoiler=true,
///     ),
///   ]
///   json_inspect(@http.attachments_json(files), content=[
///     {
///       "id": 0,
///       "filename": "cat.png",
///       "description": "a cat",
///       "is_spoiler": true,
///     },
///   ])
/// }
/// ```
pub fn FileUpload::FileUpload(
  filename : String,
  content : Bytes,
  content_type? : String = "application/octet-stream",
  description? : String,
  title? : String,
  duration_secs? : Double,
  waveform? : String,
  is_spoiler? : Bool,
) -> FileUpload {
  {
    filename,
    content,
    content_type,
    description,
    title,
    duration_secs,
    waveform,
    is_spoiler,
  }
}

///|
/// Reject upload metadata that could break out of a multipart part header.
fn validate_files(files : Array[FileUpload]) -> Unit raise DiscordHttpError {
  for file in files {
    if file.filename.is_empty() {
      raise Validation(message="filename must not be empty")
    }
    if file.filename.contains("\r") ||
      file.filename.contains("\n") ||
      file.filename.contains("\"") {
      raise Validation(
        message="filename must not contain CR, LF, or double quotes",
      )
    }
    if file.content_type.contains("\r") || file.content_type.contains("\n") {
      raise Validation(message="content_type must not contain CR or LF")
    }
  }
}

///|
/// The `attachments` array announcing uploaded files inside `payload_json`:
/// `[{ "id": n, "filename": ..., "description"? : ... }]`. The typed
/// wrappers add this automatically; use it when building an
/// `InteractionResponse` with files by hand.
pub fn attachments_json(files : Array[FileUpload]) -> Json {
  let items : Array[Json] = []
  for i, file in files {
    items.push(
      @model.ObjBuilder()
      .field("id", i)
      .field("filename", file.filename)
      .opt("description", file.description)
      .opt("title", file.title)
      .opt("duration_secs", file.duration_secs)
      .opt("waveform", file.waveform)
      .opt("is_spoiler", file.is_spoiler)
      .build(),
    )
  }
  Json::array(items)
}

///|
/// The `attachments` array for an edit: retained attachments first (by
/// snowflake id), then one entry per new upload with the numeric ids the
/// `files[n]` multipart parts require. `Some([])` with no files clears every
/// attachment; `None` leaves the retained set implicit (new files replace
/// the whole list, no files leaves it untouched).
fn merged_attachments_json(
  keep : Array[@model.AttachmentRequest],
  files : Array[FileUpload],
) -> Json {
  let items : Array[Json] = []
  for request in keep {
    items.push(request.to_json())
  }
  match attachments_json(files) {
    Array(uploads) => items.append(uploads)
    _ => ()
  }
  Json::array(items)
}

///|
/// Attach the edit-time `attachments` field: an explicit `keep` list is
/// always sent (merged with any new uploads, `[]` clears), while without it
/// the field only announces fresh uploads, matching the create path.
fn edit_attachments_field(
  body : @model.ObjBuilder,
  keep : Array[@model.AttachmentRequest]?,
  files : Array[FileUpload]?,
) -> @model.ObjBuilder {
  match (keep, files) {
    (Some(kept), _) =>
      body.field(
        "attachments",
        merged_attachments_json(kept, files.unwrap_or([])),
      )
    (None, Some(fs)) if fs.length() > 0 =>
      body.field("attachments", attachments_json(fs))
    _ => body
  }
}

///|
fn ascii_bytes(text : String) -> Bytes {
  let out : Array[Byte] = Array(capacity=text.length())
  for ch in text {
    out.push(ch.to_int().to_byte())
  }
  Bytes::from_array(out)
}

///|
fn bytes_contains(haystack : Bytes, needle : Bytes) -> Bool {
  let n = needle.length()
  if n == 0 {
    return true
  }
  for start in 0..<=(haystack.length() - n) {
    for j in 0..<n {
      if haystack[start + j] != needle[j] {
        break
      }
    } nobreak {
      return true
    }
  }
  false
}

///|
fn boundary_taken(
  candidate : String,
  payload : String,
  files : Array[FileUpload],
) -> Bool {
  // the candidate is pure ASCII, so a byte-level match in UTF-8 content
  // implies (and is implied by) a character-level match
  if payload.contains(candidate) {
    return true
  }
  let needle = ascii_bytes(candidate)
  for file in files {
    if bytes_contains(file.content, needle) {
      return true
    }
  }
  false
}

///|
/// Pick a boundary that provably occurs in none of the parts. Uniqueness
/// comes from checking, not from entropy, so a weak seed is fine.
fn fresh_boundary(
  seed : String,
  payload : String,
  files : Array[FileUpload],
) -> String {
  for k = 0; ; k = k + 1 {
    let candidate = "discordmbt-\{seed}-\{k}"
    if !boundary_taken(candidate, payload, files) {
      return candidate
    }
  }
}

///|
/// One chunk of a multipart body, written to the wire in order. File
/// contents stay as their original `Bytes` (no copying or concatenation).
pub enum MultipartChunk {
  Text(String)
  Blob(Bytes)
}

///|
/// Render the multipart body: the `payload_json` part first, then one
/// `files[n]` part per file, then the closing delimiter.
fn multipart_parts(
  boundary : String,
  payload : String,
  files : Array[FileUpload],
) -> Array[MultipartChunk] {
  let parts : Array[MultipartChunk] = []
  parts.push(
    Text(
      "--\{boundary}\r\n" +
      "content-disposition: form-data; name=\"payload_json\"\r\n" +
      "content-type: application/json\r\n\r\n" +
      payload +
      "\r\n",
    ),
  )
  for i, file in files {
    parts.push(
      Text(
        "--\{boundary}\r\n" +
        "content-disposition: form-data; name=\"files[\{i}]\"; filename=\"\{file.filename}\"\r\n" +
        "content-type: \{file.content_type}\r\n\r\n",
      ),
    )
    parts.push(Blob(file.content))
    parts.push(Text("\r\n"))
  }
  parts.push(Text("--\{boundary}--\r\n"))
  parts
}

///|
/// Render a multipart body with the `payload_json` part followed by one file
/// part under a custom field name. The invite target-users upload uses this
/// shape (`target_users_file` next to the JSON params).
fn multipart_payload_with_named_file(
  boundary : String,
  payload : String,
  file_field : String,
  file : FileUpload,
) -> Array[MultipartChunk] {
  let parts : Array[MultipartChunk] = []
  parts.push(
    Text(
      "--\{boundary}\r\n" +
      "content-disposition: form-data; name=\"payload_json\"\r\n" +
      "content-type: application/json\r\n\r\n" +
      payload +
      "\r\n",
    ),
  )
  parts.push(
    Text(
      "--\{boundary}\r\n" +
      "content-disposition: form-data; name=\"\{file_field}\"; filename=\"\{file.filename}\"\r\n" +
      "content-type: \{file.content_type}\r\n\r\n",
    ),
  )
  parts.push(Blob(file.content))
  parts.push(Text("\r\n--\{boundary}--\r\n"))
  parts
}

///|
/// Render a conventional multipart form with text fields and one named file.
/// Discord's guild-sticker and invite target-user endpoints use this shape
/// instead of payload_json plus files[n].
fn multipart_form_parts(
  boundary : String,
  fields : Array[(String, String)],
  file_field : String,
  file : FileUpload,
) -> Array[MultipartChunk] {
  let parts : Array[MultipartChunk] = []
  for field in fields {
    let (name, value) = field
    parts.push(
      Text(
        "--\{boundary}\r\n" +
        "content-disposition: form-data; name=\"\{name}\"\r\n\r\n" +
        value +
        "\r\n",
      ),
    )
  }
  parts.push(
    Text(
      "--\{boundary}\r\n" +
      "content-disposition: form-data; name=\"\{file_field}\"; filename=\"\{file.filename}\"\r\n" +
      "content-type: \{file.content_type}\r\n\r\n",
    ),
  )
  parts.push(Blob(file.content))
  parts.push(Text("\r\n--\{boundary}--\r\n"))
  parts
}

///|
let multipart_seq : Ref[Int] = Ref(0)

///|
/// A per-process sequence number so two requests in the same millisecond
/// still start from different boundary seeds.
fn next_multipart_seq() -> Int {
  multipart_seq.val += 1
  multipart_seq.val
}

///|
/// Encode an interaction-callback `multipart/form-data` body: the
/// `payload_json` part followed by one `files[n]` part per file, in the same
/// wire format as the REST upload path. Returns the `Content-Type` value
/// (including the boundary) and the ordered wire chunks. Filenames are
/// validated like the REST upload path.
///
/// ```mbt check
/// test "keep uploaded bytes as a multipart blob chunk" {
///   let (content_type, chunks) = @http.encode_multipart_body("{\"type\":4}", [
///     FileUpload("hello.txt", b"hello", content_type="text/plain"),
///   ])
///   assert_true(content_type.has_prefix("multipart/form-data; boundary="))
///   match chunks {
///     [Text(payload), Text(file_header), Blob(content), ..] => {
///       assert_true(payload.contains("payload_json"))
///       assert_true(file_header.contains("files[0]"))
///       assert_eq(content, b"hello")
///     }
///     _ => fail("unexpected multipart chunk layout")
///   }
/// }
/// ```
pub fn encode_multipart_body(
  payload_json : String,
  files : Array[FileUpload],
) -> (String, Array[MultipartChunk]) raise DiscordHttpError {
  validate_files(files)
  let seed = "\{@clock.now_ms()}-\{next_multipart_seq()}"
  let boundary = fresh_boundary(seed, payload_json, files)
  (
    "multipart/form-data; boundary=\{boundary}",
    multipart_parts(boundary, payload_json, files),
  )
}
