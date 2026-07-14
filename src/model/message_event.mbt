///|
/// A message-create dispatch with gateway-only message fields.
pub(all) struct MessageCreateEvent {
  message : Message
  guild_id : GuildId?
  guild_member : GuildMember?
  mention_members : Map[UserId, GuildMember]
  channel_type : ChannelType?
} derive(Debug)

///|
/// A message-update dispatch with the same gateway-only fields as message
/// creation.
pub(all) struct MessageUpdateEvent {
  message : Message
  guild_id : GuildId?
  guild_member : GuildMember?
  mention_members : Map[UserId, GuildMember]
  channel_type : ChannelType?
} derive(Debug)

///|
priv struct GatewayMessageMention {
  id : UserId
  guild_member : GuildMember?
} derive(FromJson(fields(guild_member(rename="member"))))

///|
priv struct GatewayMessageEventFields {
  message : Message
  guild_id : GuildId?
  guild_member : GuildMember?
  mention_members : Map[UserId, GuildMember]
  channel_type : ChannelType?
}

///|
fn[T : @json.FromJson] optional_message_event_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T? raise @json.JsonDecodeError {
  match fields.get(key) {
    None => None
    Some(value) => Some(@json.from_json(value, path=path.add_key(key)))
  }
}

///|
fn decode_gateway_message_event(
  json : Json,
  path : @json.JsonPath,
) -> GatewayMessageEventFields raise @json.JsonDecodeError {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected gateway message (object)"))
  }
  let mentions : Array[GatewayMessageMention] = event_field(
    fields, "mentions", path,
  )
  let mention_members : Map[UserId, GuildMember] = {}
  for mention in mentions {
    if mention.guild_member is Some(guild_member) {
      mention_members[mention.id] = guild_member
    }
  }
  {
    message: @json.from_json(json, path~),
    guild_id: optional_message_event_field(fields, "guild_id", path),
    guild_member: optional_message_event_field(fields, "member", path),
    mention_members,
    channel_type: optional_message_event_field(fields, "channel_type", path),
  }
}

///|
pub impl @json.FromJson for MessageCreateEvent with fn from_json(json, path) {
  let fields = decode_gateway_message_event(json, path)
  {
    message: fields.message,
    guild_id: fields.guild_id,
    guild_member: fields.guild_member,
    mention_members: fields.mention_members,
    channel_type: fields.channel_type,
  }
}

///|
pub impl @json.FromJson for MessageUpdateEvent with fn from_json(json, path) {
  let fields = decode_gateway_message_event(json, path)
  {
    message: fields.message,
    guild_id: fields.guild_id,
    guild_member: fields.guild_member,
    mention_members: fields.mention_members,
    channel_type: fields.channel_type,
  }
}
