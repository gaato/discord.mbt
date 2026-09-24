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
/// The `payload_json` part of an upload, sent first.
fn payload_part(payload_json : String) -> @multipart.Part {
  {
    name: "payload_json",
    filename: None,
    content_type: Some("application/json"),
    body: @utf8.encode(payload_json),
  }
}

///|
/// One file part under `name`, keeping the upload's bytes and media type.
fn file_part(name : String, file : FileUpload) -> @multipart.Part {
  @multipart.Part::file(name, file.filename, file.content_type, file.content)
}

///|
/// The REST upload shape: `payload_json` first, then one `files[n]` part per
/// file.
fn upload_parts(
  payload_json : String,
  files : Array[FileUpload],
) -> Array[@multipart.Part] {
  let parts = [payload_part(payload_json)]
  for i, file in files {
    parts.push(file_part("files[\{i}]", file))
  }
  parts
}

///|
/// A conventional form: text fields and one named file. Discord's
/// guild-sticker and invite target-user endpoints use this shape instead of
/// `payload_json` plus `files[n]`.
fn form_parts(
  fields : Array[(String, String)],
  file_field : String,
  file : FileUpload,
) -> Array[@multipart.Part] {
  let parts : Array[@multipart.Part] = []
  for field in fields {
    let (name, value) = field
    parts.push(@multipart.Part::text(name, value))
  }
  parts.push(file_part(file_field, file))
  parts
}

///|
let boundary_state : Ref[UInt64] = Ref(0UL)

///|
/// Boundary candidates from a small xorshift generator seeded from the clock.
/// Uniqueness does not rest on it: `encode_parts` retries a candidate that
/// occurs in a part.
fn boundary_random() -> Double {
  if boundary_state.val == 0UL {
    boundary_state.val = @clock.now_ms().reinterpret_as_uint64() |
      0x9E3779B97F4A7C15UL
  }
  let mut x = boundary_state.val
  x = x ^ (x << 13)
  x = x ^ (x >> 7)
  x = x ^ (x << 17)
  boundary_state.val = x
  (x >> 11).to_double() / 9007199254740992.0
}

///|
/// Encode the parts with a boundary that occurs in none of them. A candidate
/// that collides with a part is drawn again.
fn[T] encode_with_fresh_boundary(
  parts : Array[@multipart.Part],
  encoder : (Array[@multipart.Part], String) -> T raise @multipart.MultipartError,
  random : () -> Double,
) -> T raise DiscordHttpError {
  for _ in 0..<16 {
    let boundary = @multipart.make_boundary(random)
    let encoded = encoder(parts, boundary) catch {
      @multipart.BoundaryCollision => continue
      error => raise Validation(message=@debug.to_string(error))
    }
    return encoded
  }
  raise Transport(message="could not choose a multipart boundary")
}

///|
/// The body as ordered segments, for a wire request. Each part's bytes stay
/// the caller's, so nothing is copied until the segments are joined.
fn encode_parts(
  parts : Array[@multipart.Part],
  random? : () -> Double = boundary_random,
) -> (String, Array[Bytes]) raise DiscordHttpError {
  encode_with_fresh_boundary(parts, @multipart.encode_segments, random)
}

///|
/// The wire request with its multipart `content-type`, and the body deferred:
/// the segments are joined only once the rate limiter admits an attempt, so
/// an upload waiting its turn holds no second copy of its files.
fn multipart_request(
  request : @ghttp.Request,
  parts : Array[@multipart.Part],
) -> WireRequest raise DiscordHttpError {
  let (content_type, segments) = encode_parts(parts)
  request.headers.set("content-type", content_type)
  { head: request, body: Some(() => join_segments(segments)), }
}

///|
/// The segments as one buffer, in order.
fn join_segments(segments : Array[Bytes]) -> Bytes {
  let size = segments.fold(init=0, (size, segment) => size + segment.length())
  let buffer = Buffer(size_hint=size)
  for segment in segments {
    buffer.write_bytes(segment)
  }
  buffer.to_bytes()
}

///|
/// Encode an interaction-callback `multipart/form-data` body: the
/// `payload_json` part followed by one `files[n]` part per file, in the same
/// wire format as the REST upload path. Returns the `Content-Type` value
/// (including the boundary) and the ordered wire chunks; each file's bytes
/// are a chunk of their own, not copied, so a host can stream the reply by
/// writing the chunks in order.
/// Filenames are validated like the REST upload path.
///
/// ```mbt check
/// test "keep uploaded bytes as a multipart blob chunk" {
///   let content = b"hello"
///   let (content_type, chunks) = @http.encode_multipart_body("{\"type\":4}", [
///     FileUpload("hello.txt", content, content_type="text/plain"),
///   ])
///   assert_true(content_type.has_prefix("multipart/form-data; boundary="))
///   match chunks {
///     [payload_header, payload, file_header, bytes, trailer] => {
///       assert_true(@utf8.decode_lossy(payload_header).contains("payload_json"))
///       assert_eq(payload, b"{\"type\":4}")
///       assert_true(@utf8.decode_lossy(file_header).contains("files[0]"))
///       assert_true(physical_equal(bytes, content))
///       assert_true(@utf8.decode_lossy(trailer).has_suffix("--\r\n"))
///     }
///     _ => fail("unexpected multipart chunk layout")
///   }
/// }
/// ```
pub fn encode_multipart_body(
  payload_json : String,
  files : Array[FileUpload],
) -> (String, Array[Bytes]) raise DiscordHttpError {
  validate_files(files)
  encode_with_fresh_boundary(
    upload_parts(payload_json, files),
    @multipart.encode_segments,
    boundary_random,
  )
}
