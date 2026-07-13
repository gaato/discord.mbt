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
  // TODO(partial-guild): Port source_guild with the partial guild surface.
  // TODO(partial-channel): Port source_channel with its partial channel surface.
  url : String?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The behavior category of a Discord webhook.
pub(all) enum WebhookType {
  Incoming
  ChannelFollower
  Application
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn WebhookType::to_int(self : WebhookType) -> Int {
  match self {
    Incoming => 1
    ChannelFollower => 2
    Application => 3
    Unknown(value) => value
  }
}

///|
pub fn WebhookType::from_int(value : Int) -> WebhookType {
  match value {
    1 => Incoming
    2 => ChannelFollower
    3 => Application
    value => Unknown(value)
  }
}

///|
pub impl ToJson for WebhookType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for WebhookType with fn from_json(json, path) {
  match json {
    Number(value, ..) => WebhookType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected the behavior category of a discord webhook (number)"),
      )
  }
}
