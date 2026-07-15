///|
/// Rich content embedded in a Discord message.
pub(all) struct Embed {
  title : String?
  typ : EmbedType?
  url : String?
  description : String?
  timestamp : Timestamp?
  color : Int?
  footer : EmbedFooter?
  image : EmbedImage?
  thumbnail : EmbedThumbnail?
  video : EmbedVideo?
  provider : EmbedProvider?
  author : EmbedAuthor?
  fields : Array[EmbedField]?
  flags : EmbedFlags?
  // Not modeled: embed components appear in OpenAPI but not in the public documentation.
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// Bit flags describing special rendering behavior of an embed.
pub(all) struct EmbedFlags(UInt64) derive(Eq)

///|
pub fn EmbedFlags::from_bits(bits : UInt64) -> EmbedFlags {
  EmbedFlags(bits)
}

///|
pub fn EmbedFlags::bits(self : EmbedFlags) -> UInt64 {
  self.0
}

///|
pub impl Debug for EmbedFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for EmbedFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for EmbedFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      EmbedFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ => raise JsonDecodeError((path, "expected embed flags (number)"))
        },
      )
    Number(value, repr=None) => EmbedFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected embed flags (number)"))
  }
}

///|
pub fn EmbedFlags::is_content_inventory_entry() -> EmbedFlags {
  EmbedFlags(1UL << 5)
}

///|
/// The string discriminator describing an embed's rendering category.
pub(all) enum EmbedType {
  Rich
  Image
  Video
  Gifv
  Article
  Link
  AutoModerationMessage
  PollResult
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn EmbedType::to_string(self : EmbedType) -> String {
  match self {
    Rich => "rich"
    Image => "image"
    Video => "video"
    Gifv => "gifv"
    Article => "article"
    Link => "link"
    AutoModerationMessage => "auto_moderation_message"
    PollResult => "poll_result"
    Unknown(value) => value
  }
}

///|
pub fn EmbedType::from_string(value : String) -> EmbedType {
  match value {
    "rich" => Rich
    "image" => Image
    "video" => Video
    "gifv" => Gifv
    "article" => Article
    "link" => Link
    "auto_moderation_message" => AutoModerationMessage
    "poll_result" => PollResult
    value => Unknown(value)
  }
}

///|
pub impl ToJson for EmbedType with fn to_json(self) {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for EmbedType with fn from_json(json, path) {
  match json {
    String(value) => EmbedType::from_string(value)
    _ => raise JsonDecodeError((path, "expected an embed type (string)"))
  }
}

///|
/// Footer text and optional icon URLs for an embed.
pub(all) struct EmbedFooter {
  text : String
  icon_url : String?
  proxy_icon_url : String?
} derive(ToJson, FromJson, Debug)

///|
/// Image media displayed within an embed.
pub(all) struct EmbedImage {
  url : String
  proxy_url : String?
  height : Int?
  width : Int?
} derive(ToJson, FromJson, Debug)

///|
/// Thumbnail media displayed beside an embed.
pub(all) struct EmbedThumbnail {
  url : String
  proxy_url : String?
  height : Int?
  width : Int?
} derive(ToJson, FromJson, Debug)

///|
/// Video media attached to an embed.
pub(all) struct EmbedVideo {
  url : String?
  proxy_url : String?
  height : Int?
  width : Int?
} derive(ToJson, FromJson, Debug)

///|
/// Attribution information for the provider of an embed.
pub(all) struct EmbedProvider {
  name : String?
  url : String?
} derive(ToJson, FromJson, Debug)

///|
/// Author information displayed at the top of an embed.
pub(all) struct EmbedAuthor {
  name : String
  url : String?
  icon_url : String?
  proxy_icon_url : String?
} derive(ToJson, FromJson, Debug)

///|
/// A named value displayed in an embed's field grid.
pub(all) struct EmbedField {
  name : String
  value : String
  inline : Bool?
} derive(ToJson, FromJson, Debug)
