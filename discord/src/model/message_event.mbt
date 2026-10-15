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
  /// `None` when decoded via `FromJson`. The bot gateway runtime supplies the
  /// cached previous revision only when its messages cache is enabled and that
  /// revision is still retained.
  before : Message?
  guild_id : GuildId?
  guild_member : GuildMember?
  mention_members : Map[UserId, GuildMember]
  channel_type : ChannelType?
} derive(Debug)

///|
/// Whether this update changed the message's edit timestamp.
///
/// Without `before`, this uses the presence of an edited timestamp as a
/// heuristic and may misclassify pin or unfurl updates to an already-edited
/// message as edits.
pub fn MessageUpdateEvent::is_edit(self : MessageUpdateEvent) -> Bool {
  match self.before {
    Some(before) =>
      !edited_timestamps_equal(
        before.edited_timestamp,
        self.message.edited_timestamp,
      )
    None => self.message.edited_timestamp is Value(_)
  }
}

///|
/// Discord echoes `edited_timestamp` with varying sub-second precision
/// (microseconds on the edit dispatch, milliseconds on later pin or unfurl
/// updates for the same message), so compare instants at millisecond
/// precision rather than strings.
fn edited_timestamps_equal(
  a : Nullable[Timestamp],
  b : Nullable[Timestamp],
) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (Value(left), Value(right)) => {
      let left_ms = left.unix_ms() catch { _ => return left == right }
      let right_ms = right.unix_ms() catch { _ => return left == right }
      left_ms == right_ms
    }
    _ => false
  }
}

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
    raise JsonDecodeError((path, "expected gateway message (object)"))
  }
  let mentions : Array[GatewayMessageMention] = event_field(
    fields, "mentions", path,
  )
  let mention_members : Map[UserId, GuildMember] = Map([])
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
    before: None,
    guild_id: fields.guild_id,
    guild_member: fields.guild_member,
    mention_members: fields.mention_members,
    channel_type: fields.channel_type,
  }
}
