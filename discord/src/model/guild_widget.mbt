///|
/// Whether a guild widget is enabled and the channel it links to.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildWidgetSettings {
  enabled : Bool
  channel_id : Nullable[ChannelId]
}

///|
/// The public JSON representation of a guild widget.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildWidget {
  id : GuildId
  name : String
  instant_invite : Nullable[String]
  channels : Array[GuildWidgetChannel]
  members : Array[GuildWidgetMember]
  presence_count : Int32
}

///|
/// A voice channel shown in a public guild widget.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildWidgetChannel {
  id : ChannelId
  name : String
  position : Int32
}

///|
/// An anonymized member shown in a public guild widget. Widget member IDs are
/// opaque strings rather than Discord snowflakes.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildWidgetMember {
  id : String
  username : String
  discriminator : String
  avatar : Nullable[String]
  status : String
  avatar_url : String
}
