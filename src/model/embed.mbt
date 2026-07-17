///|
/// Rich content embedded in a Discord message.
///
/// Use `Embed(...)` to construct outgoing embeds from fields Discord accepts
/// when sending. Embed models remain public records so received metadata can
/// be inspected. Pass outgoing values to
/// `Client::create_message(embeds=[...])`, `CommandReply::message(embeds=[...])`,
/// `ctx.respond`, or a followup method. Discord applies its documented embed
/// count and text-length limits.
///
/// ```mbt check
/// test "construct an outgoing embed" {
///   let embed = @model.Embed(
///     title="Build complete",
///     description="All checks passed.",
///     timestamp=@model.Timestamp("2026-07-15T00:00:00Z"),
///     color=0x57F287,
///     footer=@model.EmbedFooter("build 42"),
///     fields=[
///       @model.EmbedField("Target", "native", inline=true),
///       @model.EmbedField("Tests", "325 passed", inline=true),
///     ],
///   )
///   json_inspect(embed, content={
///     "title": "Build complete",
///     "description": "All checks passed.",
///     "timestamp": "2026-07-15T00:00:00Z",
///     "color": 5763719,
///     "footer": { "text": "build 42" },
///     "fields": [
///       { "name": "Target", "value": "native", "inline": true },
///       { "name": "Tests", "value": "325 passed", "inline": true },
///     ],
///   })
/// }
/// ```
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
/// Construct an embed containing only fields accepted in outgoing payloads.
/// Receive-only fields are left unset. The `fields` array is copied so later
/// mutations of the caller's array do not affect the embed.
pub fn Embed::Embed(
  title? : String,
  description? : String,
  url? : String,
  timestamp? : Timestamp,
  color? : Int,
  footer? : EmbedFooter,
  image? : EmbedImage,
  thumbnail? : EmbedThumbnail,
  author? : EmbedAuthor,
  fields? : Array[EmbedField],
) -> Embed {
  {
    title,
    typ: None,
    url,
    description,
    timestamp,
    color,
    footer,
    image,
    thumbnail,
    video: None,
    provider: None,
    author,
    fields: fields.map(values => values.copy()),
    flags: None,
  }
}

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
/// Construct footer content for an outgoing embed.
pub fn EmbedFooter::EmbedFooter(
  text : String,
  icon_url? : String,
) -> EmbedFooter {
  { text, icon_url, proxy_icon_url: None }
}

///|
/// Image media displayed within an embed.
pub(all) struct EmbedImage {
  url : String
  proxy_url : String?
  height : Int?
  width : Int?
} derive(ToJson, FromJson, Debug)

///|
/// Construct image media for an outgoing embed.
pub fn EmbedImage::EmbedImage(url : String) -> EmbedImage {
  { url, proxy_url: None, height: None, width: None }
}

///|
/// Thumbnail media displayed beside an embed.
pub(all) struct EmbedThumbnail {
  url : String
  proxy_url : String?
  height : Int?
  width : Int?
} derive(ToJson, FromJson, Debug)

///|
/// Construct thumbnail media for an outgoing embed.
pub fn EmbedThumbnail::EmbedThumbnail(url : String) -> EmbedThumbnail {
  { url, proxy_url: None, height: None, width: None }
}

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
/// Construct author information for an outgoing embed.
pub fn EmbedAuthor::EmbedAuthor(
  name : String,
  url? : String,
  icon_url? : String,
) -> EmbedAuthor {
  { name, url, icon_url, proxy_icon_url: None }
}

///|
/// A named value displayed in an embed's field grid.
pub(all) struct EmbedField {
  name : String
  value : String
  inline : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// Construct a field for an outgoing embed.
pub fn EmbedField::EmbedField(
  name : String,
  value : String,
  inline? : Bool,
) -> EmbedField {
  { name, value, inline }
}
