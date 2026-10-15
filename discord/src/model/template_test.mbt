///|
test "guild template decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "code":"developer-community","name":"Developer Community",
    #|  "description":null,"usage_count":42,
    #|  "creator_id":"80351110224678912",
    #|  "creator":{"id":"80351110224678912","username":"Nelly","discriminator":"0","global_name":"Nelly","avatar":null},
    #|  "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-07-01T00:00:00Z",
    #|  "source_guild_id":"81384788765712384",
    #|  "serialized_source_guild":{"name":"Snapshot","roles":[],"channels":[],"future":true},
    #|  "is_dirty":null,"brand_new_field_from_discord":true
    #|}
  let template : @model.GuildTemplate = @json.from_json(@json.parse(fixture))
  debug_inspect(
    template,
    content=(
      #|{
      #|  code: "developer-community",
      #|  name: "Developer Community",
      #|  description: Null,
      #|  usage_count: 42,
      #|  creator_id: 80351110224678912,
      #|  creator: {
      #|    id: 80351110224678912,
      #|    username: "Nelly",
      #|    discriminator: "0",
      #|    global_name: Some(Value("Nelly")),
      #|    avatar: Null,
      #|    bot: None,
      #|    system: None,
      #|    mfa_enabled: None,
      #|    banner: None,
      #|    accent_color: None,
      #|    locale: None,
      #|    verified: None,
      #|    email: None,
      #|    flags: None,
      #|    premium_type: None,
      #|    public_flags: None,
      #|    avatar_decoration: None,
      #|    avatar_decoration_data: None,
      #|    collectibles: None,
      #|    primary_guild: None,
      #|  },
      #|  created_at: "2026-01-01T00:00:00Z",
      #|  updated_at: "2026-07-01T00:00:00Z",
      #|  source_guild_id: 81384788765712384,
      #|  serialized_source_guild: {
      #|    name: Some("Snapshot"),
      #|    description: None,
      #|    region: None,
      #|    verification_level: None,
      #|    default_message_notifications: None,
      #|    explicit_content_filter: None,
      #|    preferred_locale: None,
      #|    afk_timeout: None,
      #|    roles: Some([]),
      #|    channels: Some([]),
      #|    afk_channel_id: None,
      #|    system_channel_id: None,
      #|    system_channel_flags: None,
      #|    icon_hash: None,
      #|  },
      #|  is_dirty: Null,
      #|}
    ),
  )
}

///|
test "guild template ignores undocumented source snapshot fields" {
  let fixture =
    #|{"code":"x","name":"X","description":null,"usage_count":0,"creator_id":"1","creator":{"id":"1","username":"u","discriminator":"0","global_name":null,"avatar":null},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","source_guild_id":"2","serialized_source_guild":{"unknown":[1,true,null]},"is_dirty":false}
  let template : @model.GuildTemplate = @json.from_json(@json.parse(fixture))
  inspect(
    template.to_json().stringify(),
    content=(
      #|{"code":"x","name":"X","description":null,"usage_count":0,"creator_id":"1","creator":{"id":"1","username":"u","discriminator":"0","global_name":null,"avatar":null},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","source_guild_id":"2","serialized_source_guild":{},"is_dirty":false}
    ),
  )
}
