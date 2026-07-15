///|
/// A file attached to a Discord message.
pub(all) struct Attachment {
  id : AttachmentId
  filename : String
  title : String?
  description : String?
  content_type : String?
  size : Int
  url : String
  proxy_url : String
  height : Nullable[Int]?
  width : Nullable[Int]?
  ephemeral : Bool?
  duration_secs : Double?
  waveform : String?
  flags : AttachmentFlags?
  placeholder : String?
  placeholder_version : Int?
  clip_participants : Array[User]?
  clip_created_at : Timestamp?
  application : Nullable[Application]?
} derive(ToJson, FromJson, Debug)

///|
/// Bit flags describing special properties of an attachment.
pub(all) struct AttachmentFlags(UInt64) derive(Eq)

///|
pub fn AttachmentFlags::none() -> AttachmentFlags {
  AttachmentFlags(0)
}

///|
pub fn AttachmentFlags::from_bits(bits : UInt64) -> AttachmentFlags {
  AttachmentFlags(bits)
}

///|
pub fn AttachmentFlags::bits(self : AttachmentFlags) -> UInt64 {
  self.0
}

///|
pub fn AttachmentFlags::contains(
  self : AttachmentFlags,
  other : AttachmentFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for AttachmentFlags with fn lor(a, b) {
  AttachmentFlags(a.0 | b.0)
}

///|
pub impl BitAnd for AttachmentFlags with fn land(a, b) {
  AttachmentFlags(a.0 & b.0)
}

///|
pub impl Debug for AttachmentFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for AttachmentFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
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
pub fn AttachmentFlags::is_clip() -> AttachmentFlags {
  AttachmentFlags(1UL << 0)
}

///|
pub fn AttachmentFlags::is_thumbnail() -> AttachmentFlags {
  AttachmentFlags(1UL << 1)
}

///|
pub fn AttachmentFlags::is_remix() -> AttachmentFlags {
  AttachmentFlags(1UL << 2)
}

///|
pub fn AttachmentFlags::is_spoiler() -> AttachmentFlags {
  AttachmentFlags(1UL << 3)
}

///|
pub fn AttachmentFlags::is_animated() -> AttachmentFlags {
  AttachmentFlags(1UL << 5)
}
