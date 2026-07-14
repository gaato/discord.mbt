///|
test "webhook decodes a full fixture" {
  let fixture =
    #|{
    #|  "id": "223704706495545344", "type": 1,
    #|  "guild_id": "81384788765712384",
    #|  "channel_id": "41771983423143937",
    #|  "user": {
    #|    "id": "80351110224678912", "username": "Nelly",
    #|    "discriminator": "0", "global_name": null, "avatar": null
    #|  },
    #|  "name": "Captain Hook", "avatar": null,
    #|  "token": "a-token", "application_id": null,
    #|  "url": "https://discord.com/api/webhooks/example",
    #|  "source_guild": {"id":"1","name":"ignored","icon":null},
    #|  "brand_new_field_from_discord": true
    #|}
  let webhook : @model.Webhook = @json.from_json(@json.parse(fixture))
  debug_inspect(
    webhook,
    content=(
      #|{
      #|  id: 223704706495545344,
      #|  typ: Incoming,
      #|  guild_id: Some(Value(81384788765712384)),
      #|  channel_id: Value(41771983423143937),
      #|  user: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Some(Null),
      #|      avatar: Null,
      #|      bot: None,
      #|      system: None,
      #|      mfa_enabled: None,
      #|      banner: None,
      #|      accent_color: None,
      #|      locale: None,
      #|      verified: None,
      #|      email: None,
      #|      flags: None,
      #|      premium_type: None,
      #|      public_flags: None,
      #|      avatar_decoration: None,
      #|      avatar_decoration_data: None,
      #|      collectibles: None,
      #|      primary_guild: None,
      #|    },
      #|  ),
      #|  name: Value("Captain Hook"),
      #|  avatar: Null,
      #|  token: Some("a-token"),
      #|  application_id: Null,
      #|  source_guild: Some(
      #|    {
      #|      id: 1,
      #|      name: Some("ignored"),
      #|      icon: Some(Null),
      #|      splash: None,
      #|      banner: None,
      #|      description: None,
      #|      features: None,
      #|      verification_level: None,
      #|      vanity_url_code: None,
      #|      nsfw_level: None,
      #|      premium_subscription_count: None,
      #|      locale: None,
      #|    },
      #|  ),
      #|  source_channel: None,
      #|  url: Some("https://discord.com/api/webhooks/example"),
      #|}
    ),
  )
}

///|
test "webhook decodes required fields only" {
  let webhook : @model.Webhook = @json.from_json(
    @json.parse(
      (
        #|{"id":"1","type":2,"channel_id":null,"name":null,"avatar":null,"application_id":null}
      ),
    ),
  )
  debug_inspect(
    webhook,
    content=(
      #|{
      #|  id: 1,
      #|  typ: ChannelFollower,
      #|  guild_id: None,
      #|  channel_id: Null,
      #|  user: None,
      #|  name: Null,
      #|  avatar: Null,
      #|  token: None,
      #|  application_id: Null,
      #|  source_guild: None,
      #|  source_channel: None,
      #|  url: None,
      #|}
    ),
  )
}

///|
test "webhook encode omits absent optional fields" {
  let webhook : @model.Webhook = {
    id: @model.Id(1UL),
    typ: @model.WebhookType::Incoming,
    guild_id: None,
    channel_id: @model.Nullable::Null,
    user: None,
    name: @model.Nullable::Null,
    avatar: @model.Nullable::Null,
    token: None,
    application_id: @model.Nullable::Null,
    source_guild: None,
    source_channel: None,
    url: None,
  }
  inspect(
    webhook.to_json().stringify(),
    content=(
      #|{"id":"1","type":1,"channel_id":null,"name":null,"avatar":null,"application_id":null}
    ),
  )
}

///|
test "webhook type preserves unknown values" {
  let typ : @model.WebhookType = @json.from_json(@json.parse("99"))
  debug_inspect(
    typ,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    typ.to_json().stringify(),
    content=(
      #|99
    ),
  )
}
