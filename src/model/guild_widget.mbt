///|
/// Whether a guild widget is enabled and the channel it links to.
pub(all) struct GuildWidgetSettings {
  enabled : Bool
  channel_id : Nullable[ChannelId]
} derive(ToJson, FromJson, Debug)

///|
/// The public JSON representation of a guild widget.
pub(all) struct GuildWidget {
  id : GuildId
  name : String
  instant_invite : Nullable[String]
  channels : Array[GuildWidgetChannel]
  members : Array[GuildWidgetMember]
  presence_count : Int
} derive(ToJson, FromJson, Debug)

///|
/// A voice channel shown in a public guild widget.
pub(all) struct GuildWidgetChannel {
  id : ChannelId
  name : String
  position : Int
} derive(ToJson, FromJson, Debug)

///|
/// An anonymized member shown in a public guild widget. Widget member IDs are
/// opaque strings rather than Discord snowflakes.
pub(all) struct GuildWidgetMember {
  id : String
  username : String
  discriminator : String
  avatar : Nullable[String]
  status : String
  avatar_url : String
} derive(ToJson, FromJson, Debug)
