///|
/// A file attached to a Discord message.
///
/// `proxy_url` serves images and videos (which carry `width` and `height`)
/// and passes audio through unmodified; for any other file Discord's media
/// proxy answers `415 Unsupported Media Type`, so fetch `url` instead.
pub(all) struct Attachment {
  id : AttachmentId
  filename : String
  title : String?
  description : String?
  content_type : String?
  size : Int32
  url : String
  proxy_url : String
  height : Nullable[Int32]?
  width : Nullable[Int32]?
  ephemeral : Bool?
  duration_secs : Double?
  waveform : String?
  flags : AttachmentFlags?
  placeholder : String?
  placeholder_version : Int32?
  clip_participants : Array[User]?
  clip_created_at : Timestamp?
  application : Nullable[Application]?
} derive(ToJson, FromJson, Debug)

///|
/// An existing attachment to retain when editing a message, per the
/// documented attachment-request structure. `description` and `is_spoiler`
/// may be updated in place; absent fields are omitted from the wire, leaving
/// them unchanged. New uploads are announced by the typed wrappers from
/// their `files` parameter instead.
pub(all) struct AttachmentRequest {
  id : AttachmentId
  filename : String?
  title : String?
  description : String?
  duration_secs : Double?
  waveform : String?
  is_spoiler : Bool?
} derive(Debug)

///|
/// Encodes the attachment request as its Discord JSON representation.
pub impl ToJson for AttachmentRequest with fn to_json(self) {
  @sdkjson.ObjBuilder::new()
  .field("id", self.id)
  .opt("filename", self.filename)
  .opt("title", self.title)
  .opt("description", self.description)
  .opt("duration_secs", self.duration_secs)
  .opt("waveform", self.waveform)
  .opt("is_spoiler", self.is_spoiler)
  .build()
}

///|
/// Bit flags describing special properties of an attachment.
pub(all) struct AttachmentFlags(UInt64) derive(Eq)

///|
/// No flags set.
pub fn AttachmentFlags::none() -> AttachmentFlags {
  AttachmentFlags(0)
}

///|
/// Flags from a raw bit field; unknown bits are kept.
pub fn AttachmentFlags::from_bits(bits : UInt64) -> AttachmentFlags {
  AttachmentFlags(bits)
}

///|
/// The raw bit field.
pub fn AttachmentFlags::bits(self : AttachmentFlags) -> UInt64 {
  self.0
}

///|
/// Whether every flag in `other` is set.
pub fn AttachmentFlags::contains(
  self : AttachmentFlags,
  other : AttachmentFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Combines flags: every flag set in either operand is set.
pub impl BitOr for AttachmentFlags with fn lor(a, b) {
  AttachmentFlags(a.0 | b.0)
}

///|
/// Keeps the flags set in both operands.
pub impl BitAnd for AttachmentFlags with fn land(a, b) {
  AttachmentFlags(a.0 & b.0)
}

///|
/// Debug output is the raw bit field.
pub impl Debug for AttachmentFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the flags as a JSON number.
pub impl ToJson for AttachmentFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
/// Decodes the flags from a JSON number; unknown bits are kept.
pub impl @json.FromJson for AttachmentFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      AttachmentFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected attachment flags (number), got \{repr}"),
            )
        },
      )
    Number(value, repr=None) => AttachmentFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected attachment flags (number)"))
  }
}

///|
/// The attachment is a clip from a stream.
pub fn AttachmentFlags::is_clip() -> AttachmentFlags {
  AttachmentFlags(1UL << 0)
}

///|
/// The attachment is the thumbnail of a clip.
pub fn AttachmentFlags::is_thumbnail() -> AttachmentFlags {
  AttachmentFlags(1UL << 1)
}

///|
/// The attachment has been edited with the remix feature.
pub fn AttachmentFlags::is_remix() -> AttachmentFlags {
  AttachmentFlags(1UL << 2)
}

///|
/// The attachment is marked as a spoiler.
pub fn AttachmentFlags::is_spoiler() -> AttachmentFlags {
  AttachmentFlags(1UL << 3)
}

///|
/// The attachment is an animated image.
pub fn AttachmentFlags::is_animated() -> AttachmentFlags {
  AttachmentFlags(1UL << 5)
}
