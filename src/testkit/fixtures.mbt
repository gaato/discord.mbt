///|
pub(all) suberror FixtureError {
  InconsistentContext(String)
} derive(Debug, Eq)

///|
/// Shared by the default interaction fixtures.
pub fn default_application_id() -> @model.ApplicationId {
  @model.Id(400000000000000001UL)
}

///|
pub fn user(
  id? : @model.UserId,
  username? : String = "test-user",
  bot? : Bool = false,
) -> @model.User {
  try! @json.from_json({
    "id": id.unwrap_or(@model.Id(200000000000000001UL)).to_json(),
    "username": username,
    "discriminator": "0",
    "avatar": Json::null(),
    "bot": bot,
  })
}

///|
pub fn guild_member(
  user? : @model.User = user(),
  roles? : Array[@model.RoleId] = [],
  permissions? : @model.Permissions,
) -> @model.GuildMember {
  let fields : Map[String, Json] = {
    "user": user.to_json(),
    "roles": roles.to_json(),
    "joined_at": "2024-01-01T00:00:00Z",
    "deaf": false,
    "mute": false,
  }
  if permissions is Some(p) {
    fields["permissions"] = p.to_json()
  }
  try! @json.from_json(Json::object(fields))
}

///|
pub fn role(
  id? : @model.RoleId,
  name? : String = "test-role",
  permissions? : @model.Permissions,
) -> @model.Role {
  try! @json.from_json({
    "id": id.unwrap_or(@model.Id(600000000000000001UL)).to_json(),
    "name": name,
    "color": 0,
    "hoist": false,
    "position": 0,
    "permissions": permissions.map(p => p.to_json()).unwrap_or("0"),
    "managed": false,
    "mentionable": false,
  })
}

///|
pub fn message(
  id? : @model.MessageId,
  channel_id? : @model.ChannelId,
  author? : @model.User = user(),
  content? : String = "test message",
  components? : Array[@model.Component],
) -> @model.Message {
  let fields : Map[String, Json] = {
    "id": id.unwrap_or(@model.Id(700000000000000001UL)).to_json(),
    "channel_id": channel_id
    .unwrap_or(@model.Id(300000000000000001UL))
    .to_json(),
    "author": author.to_json(),
    "content": content,
    "timestamp": "2024-01-01T00:00:00Z",
    "edited_timestamp": Json::null(),
    "tts": false,
    "mention_everyone": false,
    "mentions": [],
    "mention_roles": [],
    "attachments": [],
    "embeds": [],
    "pinned": false,
    "type": 0,
  }
  if components is Some(values) {
    fields["components"] = values.to_json()
  }
  try! @json.from_json(copy_json(Json::object(fields)))
}

///|
/// Build a valid base interaction. Pass it as `base` to a specialized fixture
/// for shared actor/guild/channel/application overrides. Struct updates remain
/// available for deliberately malformed inputs. No clock or counter is used.
pub fn interaction(
  id? : @model.InteractionId,
  application_id? : @model.ApplicationId,
  actor? : @model.User,
  guild? : (@model.GuildId, @model.GuildMember),
  channel_id? : @model.ChannelId,
) -> @model.Interaction raise FixtureError {
  let actor = match (actor, guild) {
    (Some(actor), Some((_, membership))) => {
      if membership.user is Some(other) && actor.id != other.id {
        raise InconsistentContext("actor and member disagree")
      }
      actor
    }
    (Some(actor), None) => actor
    (None, Some((_, membership))) =>
      membership.user.unwrap_or_else(() => user())
    (None, None) => user()
  }
  let fields : Map[String, Json] = {
    "id": id.unwrap_or(@model.Id(500000000000000001UL)).to_json(),
    "application_id": application_id
    .unwrap_or(default_application_id())
    .to_json(),
    "type": 1,
    "token": "testkit-interaction-token",
    "version": 1,
    "channel_id": channel_id
    .unwrap_or(@model.Id(300000000000000001UL))
    .to_json(),
  }
  match guild {
    Some((guild_id, membership)) => {
      fields["guild_id"] = guild_id.to_json()
      fields["member"] = { ..membership, user: Some(actor), }.to_json()
    }
    None => fields["user"] = actor.to_json()
  }
  try! @json.from_json(copy_json(Json::object(fields)))
}

///|
pub fn slash(
  name : String,
  options? : Array[@model.CommandDataOption] = [],
  resolved? : @model.ResolvedData,
  base? : @model.Interaction,
) -> @model.Interaction {
  let fields : Map[String, Json] = {
    "id": "800000000000000001",
    "name": name,
    "type": 1,
    "options": options.to_json(),
  }
  if resolved is Some(value) {
    fields["resolved"] = value.to_json()
  }
  let data : @model.CommandData = try! @json.from_json(
    copy_json(Json::object(fields)),
  )
  {
    ..base.unwrap_or_else(() => try! interaction()),
    typ: ApplicationCommand,
    data: Some(Command(data)),
  }
}

///|
pub fn autocomplete(
  name : String,
  options~ : Array[@model.CommandDataOption],
  base? : @model.Interaction,
) -> @model.Interaction {
  { ..slash(name, options~, base?), typ: ApplicationCommandAutocomplete, }
}

///|
pub fn user_command(
  name : String,
  target : @model.User,
  base? : @model.Interaction,
) -> @model.Interaction {
  let data : @model.CommandData = try! @json.from_json({
    "id": "800000000000000001",
    "name": name,
    "type": 2,
    "target_id": target.id.to_json(),
    "resolved": {
      "users": Json::object(
        Map::from_array([(target.id.to_string(), target.to_json())]),
      ),
    },
  })
  {
    ..base.unwrap_or_else(() => try! interaction()),
    typ: ApplicationCommand,
    data: Some(Command(data)),
  }
}

///|
pub fn message_command(
  name : String,
  target : @model.Message,
  base? : @model.Interaction,
) -> @model.Interaction {
  let data : @model.CommandData = try! @json.from_json({
    "id": "800000000000000001",
    "name": name,
    "type": 3,
    "target_id": target.id.to_json(),
    "resolved": {
      "messages": Json::object(
        Map::from_array([(target.id.to_string(), target.to_json())]),
      ),
    },
  })
  {
    ..base.unwrap_or_else(() => try! interaction(channel_id=target.channel_id)),
    typ: ApplicationCommand,
    data: Some(Command(data)),
  }
}

///|
pub fn component(
  custom_id : String,
  message? : @model.Message = message(),
  typ? : Int = 2,
  values? : Array[String] = [],
  resolved? : @model.ResolvedData,
  base? : @model.Interaction,
) -> @model.Interaction raise FixtureError {
  let base = base.unwrap_or_else(() => {
    try! interaction(channel_id=message.channel_id)
  })
  if base.channel_id != Some(message.channel_id) {
    raise InconsistentContext("component and message channels disagree")
  }
  let fields : Map[String, Json] = {
    "custom_id": custom_id,
    "component_type": typ.to_json(),
    "values": values.to_json(),
  }
  if resolved is Some(value) {
    fields["resolved"] = value.to_json()
  }
  let data : @model.ComponentData = try! @json.from_json(
    copy_json(Json::object(fields)),
  )
  {
    ..base,
    typ: MessageComponent,
    message: Some(message),
    data: Some(Component(data)),
  }
}

///|
pub fn modal(
  custom_id : String,
  components? : Array[@model.Component] = [],
  resolved? : @model.ResolvedData,
  message? : @model.Message,
  base? : @model.Interaction,
) -> @model.Interaction raise FixtureError {
  let base = base.unwrap_or_else(() => {
    try! interaction(channel_id?=message.map(value => value.channel_id))
  })
  if message is Some(value) && base.channel_id != Some(value.channel_id) {
    raise InconsistentContext("modal and message channels disagree")
  }
  let fields : Map[String, Json] = {
    "custom_id": custom_id,
    "components": components.to_json(),
  }
  if resolved is Some(value) {
    fields["resolved"] = value.to_json()
  }
  let data : @model.ModalData = try! @json.from_json(
    copy_json(Json::object(fields)),
  )
  { ..base, typ: ModalSubmit, message, data: Some(Modal(data)), }
}
