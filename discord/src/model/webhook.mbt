///|
/// A Discord webhook and its execution metadata.
pub(all) struct Webhook {
  id : WebhookId
  typ : WebhookType
  guild_id : Nullable[GuildId]?
  channel_id : Nullable[ChannelId]
  user : User?
  name : Nullable[String]
  avatar : Nullable[ImageHash]
  token : String?
  application_id : Nullable[ApplicationId]
  source_guild : PartialGuild?
  source_channel : PartialChannel?
  url : String?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The behavior category of a Discord webhook.
#non_exhaustive
pub(all) enum WebhookType {
  Incoming
  ChannelFollower
  Application
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `WebhookType`.
pub fn WebhookType::to_int(self : WebhookType) -> Int32 {
  match self {
    Incoming => 1
    ChannelFollower => 2
    Application => 3
    Unknown(value) => value
  }
}

///|
/// The `WebhookType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn WebhookType::from_int(value : Int32) -> WebhookType {
  match value {
    1 => Incoming
    2 => ChannelFollower
    3 => Application
    value => Unknown(value)
  }
}

///|
/// Encodes the `WebhookType` as its Discord integer value.
pub impl ToJson for WebhookType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `WebhookType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for WebhookType with fn from_json(json, path) {
  match json {
    Number(value, ..) => WebhookType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected the behavior category of a discord webhook (number)"),
      )
  }
}
