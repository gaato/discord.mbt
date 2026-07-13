///|
test "channel decodes a guild text fixture" {
  let fixture =
    #|{
    #|  "id": "41771983423143937",
    #|  "type": 0,
    #|  "guild_id": "81384788765712384",
    #|  "position": 6,
    #|  "permission_overwrites": [{
    #|    "id": "81384788765712384",
    #|    "type": 0,
    #|    "allow": "0",
    #|    "deny": "1024"
    #|  }],
    #|  "name": "general",
    #|  "topic": "Welcome to the server",
    #|  "nsfw": false,
    #|  "last_message_id": null,
    #|  "rate_limit_per_user": 0,
    #|  "parent_id": null,
    #|  "last_pin_timestamp": "2021-03-11T18:15:37.907000+00:00",
    #|  "default_auto_archive_duration": 1440,
    #|  "permissions": "1024",
    #|  "flags": 0,
    #|  "default_thread_rate_limit_per_user": 5,
    #|  "brand_new_field_from_discord": true
    #|}
  let channel : @model.Channel = @json.from_json(@json.parse(fixture))
  debug_inspect(
    channel,
    content=(
      #|{
      #|  id: 41771983423143937,
      #|  typ: GuildText,
      #|  guild_id: Some(81384788765712384),
      #|  position: Some(6),
      #|  permission_overwrites: Some([{ id: 81384788765712384, typ: Role, allow: 0, deny: 1024 }]),
      #|  name: Some(Value("general")),
      #|  topic: Some(Value("Welcome to the server")),
      #|  nsfw: Some(false),
      #|  last_message_id: Some(Null),
      #|  bitrate: None,
      #|  user_limit: None,
      #|  rate_limit_per_user: Some(0),
      #|  recipients: None,
      #|  icon: None,
      #|  owner_id: None,
      #|  application_id: None,
      #|  managed: None,
      #|  parent_id: Some(Null),
      #|  last_pin_timestamp: Some(Value("2021-03-11T18:15:37.907000+00:00")),
      #|  rtc_region: None,
      #|  video_quality_mode: None,
      #|  message_count: None,
      #|  member_count: None,
      #|  thread_metadata: None,
      #|  thread_member: None,
      #|  default_auto_archive_duration: Some(OneDay),
      #|  permissions: Some(1024),
      #|  flags: Some(0),
      #|  total_message_sent: None,
      #|  available_tags: None,
      #|  applied_tags: None,
      #|  default_reaction_emoji: None,
      #|  default_thread_rate_limit_per_user: Some(5),
      #|  default_sort_order: None,
      #|  default_forum_layout: None,
      #|}
    ),
  )
}

///|
test "channel decodes a thread fixture with metadata and membership" {
  let fixture =
    #|{
    #|  "id": "755000000000000001",
    #|  "type": 11,
    #|  "guild_id": "81384788765712384",
    #|  "name": "help-thread",
    #|  "last_message_id": "755000000000000002",
    #|  "rate_limit_per_user": 10,
    #|  "owner_id": "80351110224678912",
    #|  "parent_id": "41771983423143937",
    #|  "message_count": 12,
    #|  "member_count": 4,
    #|  "thread_metadata": {
    #|    "archived": false,
    #|    "auto_archive_duration": 60,
    #|    "archive_timestamp": "2024-01-02T03:04:05.000000+00:00",
    #|    "locked": false,
    #|    "invitable": true,
    #|    "create_timestamp": "2024-01-01T03:04:05.000000+00:00"
    #|  },
    #|  "member": {
    #|    "id": "755000000000000001",
    #|    "user_id": "80351110224678912",
    #|    "join_timestamp": "2024-01-01T03:05:00.000000+00:00",
    #|    "flags": 1,
    #|    "member": {"nick": "Nelly"}
    #|  },
    #|  "flags": 2,
    #|  "total_message_sent": 15,
    #|  "applied_tags": ["111111111111111111"],
    #|  "brand_new_field_from_discord": true
    #|}
  let channel : @model.Channel = @json.from_json(@json.parse(fixture))
  debug_inspect(
    channel,
    content=(
      #|{
      #|  id: 755000000000000001,
      #|  typ: PublicThread,
      #|  guild_id: Some(81384788765712384),
      #|  position: None,
      #|  permission_overwrites: None,
      #|  name: Some(Value("help-thread")),
      #|  topic: None,
      #|  nsfw: None,
      #|  last_message_id: Some(Value(755000000000000002)),
      #|  bitrate: None,
      #|  user_limit: None,
      #|  rate_limit_per_user: Some(10),
      #|  recipients: None,
      #|  icon: None,
      #|  owner_id: Some(80351110224678912),
      #|  application_id: None,
      #|  managed: None,
      #|  parent_id: Some(Value(41771983423143937)),
      #|  last_pin_timestamp: None,
      #|  rtc_region: None,
      #|  video_quality_mode: None,
      #|  message_count: Some(12),
      #|  member_count: Some(4),
      #|  thread_metadata: Some(
      #|    {
      #|      archived: false,
      #|      auto_archive_duration: OneHour,
      #|      archive_timestamp: "2024-01-02T03:04:05.000000+00:00",
      #|      locked: false,
      #|      invitable: Some(true),
      #|      create_timestamp: Some("2024-01-01T03:04:05.000000+00:00"),
      #|    },
      #|  ),
      #|  thread_member: Some(
      #|    {
      #|      id: Some(755000000000000001),
      #|      user_id: Some(80351110224678912),
      #|      join_timestamp: "2024-01-01T03:05:00.000000+00:00",
      #|      flags: 1,
      #|    },
      #|  ),
      #|  default_auto_archive_duration: None,
      #|  permissions: None,
      #|  flags: Some(2),
      #|  total_message_sent: Some(15),
      #|  available_tags: None,
      #|  applied_tags: Some([111111111111111111]),
      #|  default_reaction_emoji: None,
      #|  default_thread_rate_limit_per_user: None,
      #|  default_sort_order: None,
      #|  default_forum_layout: None,
      #|}
    ),
  )
}

///|
test "channel decodes a minimal DM" {
  let channel : @model.Channel = @json.from_json(
    @json.parse(
      (
        #|{
        #|  "id": "811111111111111111",
        #|  "type": 1
        #|}
      ),
    ),
  )
  debug_inspect(
    channel,
    content=(
      #|{
      #|  id: 811111111111111111,
      #|  typ: Dm,
      #|  guild_id: None,
      #|  position: None,
      #|  permission_overwrites: None,
      #|  name: None,
      #|  topic: None,
      #|  nsfw: None,
      #|  last_message_id: None,
      #|  bitrate: None,
      #|  user_limit: None,
      #|  rate_limit_per_user: None,
      #|  recipients: None,
      #|  icon: None,
      #|  owner_id: None,
      #|  application_id: None,
      #|  managed: None,
      #|  parent_id: None,
      #|  last_pin_timestamp: None,
      #|  rtc_region: None,
      #|  video_quality_mode: None,
      #|  message_count: None,
      #|  member_count: None,
      #|  thread_metadata: None,
      #|  thread_member: None,
      #|  default_auto_archive_duration: None,
      #|  permissions: None,
      #|  flags: None,
      #|  total_message_sent: None,
      #|  available_tags: None,
      #|  applied_tags: None,
      #|  default_reaction_emoji: None,
      #|  default_thread_rate_limit_per_user: None,
      #|  default_sort_order: None,
      #|  default_forum_layout: None,
      #|}
    ),
  )
}

///|
test "channel encode omits every absent variant field" {
  let channel : @model.Channel = {
    id: @model.Id(1UL),
    typ: @model.ChannelType::Dm,
    guild_id: None,
    position: None,
    permission_overwrites: None,
    name: None,
    topic: None,
    nsfw: None,
    last_message_id: None,
    bitrate: None,
    user_limit: None,
    rate_limit_per_user: None,
    recipients: None,
    icon: None,
    owner_id: None,
    application_id: None,
    managed: None,
    parent_id: None,
    last_pin_timestamp: None,
    rtc_region: None,
    video_quality_mode: None,
    message_count: None,
    member_count: None,
    thread_metadata: None,
    thread_member: None,
    default_auto_archive_duration: None,
    permissions: None,
    flags: None,
    total_message_sent: None,
    available_tags: None,
    applied_tags: None,
    default_reaction_emoji: None,
    default_thread_rate_limit_per_user: None,
    default_sort_order: None,
    default_forum_layout: None,
  }
  inspect(
    channel.to_json().stringify(),
    content=(
      #|{"id":"1","type":1}
    ),
  )
}

///|
test "channel decodes forum tags and defaults" {
  let fixture =
    #|{
    #|  "id": "855000000000000001",
    #|  "type": 15,
    #|  "guild_id": "81384788765712384",
    #|  "position": 7,
    #|  "name": "support",
    #|  "topic": null,
    #|  "available_tags": [{
    #|    "id": "111111111111111111",
    #|    "name": "Solved",
    #|    "moderated": true,
    #|    "emoji_id": null,
    #|    "emoji_name": "✅"
    #|  }],
    #|  "default_reaction_emoji": {
    #|    "emoji_id": null,
    #|    "emoji_name": "👋"
    #|  },
    #|  "default_sort_order": null,
    #|  "default_forum_layout": 2,
    #|  "brand_new_field_from_discord": true
    #|}
  let channel : @model.Channel = @json.from_json(@json.parse(fixture))
  debug_inspect(
    channel,
    content=(
      #|{
      #|  id: 855000000000000001,
      #|  typ: GuildForum,
      #|  guild_id: Some(81384788765712384),
      #|  position: Some(7),
      #|  permission_overwrites: None,
      #|  name: Some(Value("support")),
      #|  topic: Some(Null),
      #|  nsfw: None,
      #|  last_message_id: None,
      #|  bitrate: None,
      #|  user_limit: None,
      #|  rate_limit_per_user: None,
      #|  recipients: None,
      #|  icon: None,
      #|  owner_id: None,
      #|  application_id: None,
      #|  managed: None,
      #|  parent_id: None,
      #|  last_pin_timestamp: None,
      #|  rtc_region: None,
      #|  video_quality_mode: None,
      #|  message_count: None,
      #|  member_count: None,
      #|  thread_metadata: None,
      #|  thread_member: None,
      #|  default_auto_archive_duration: None,
      #|  permissions: None,
      #|  flags: None,
      #|  total_message_sent: None,
      #|  available_tags: Some(
      #|    [
      #|      {
      #|        id: 111111111111111111,
      #|        name: "Solved",
      #|        moderated: true,
      #|        emoji_id: Null,
      #|        emoji_name: Value("✅"),
      #|      },
      #|    ],
      #|  ),
      #|  applied_tags: None,
      #|  default_reaction_emoji: Some(Value({ emoji_id: Null, emoji_name: Value("👋") })),
      #|  default_thread_rate_limit_per_user: None,
      #|  default_sort_order: Some(Null),
      #|  default_forum_layout: Some(GalleryView),
      #|}
    ),
  )
}

///|
test "channel supporting wire values preserve unknown values" {
  let duration : @model.ThreadAutoArchiveDuration = @json.from_json(
    @json.parse("30"),
  )
  debug_inspect(
    duration,
    content=(
      #|Unknown(30)
    ),
  )
  inspect(
    duration.to_json().stringify(),
    content=(
      #|30
    ),
  )
  let overwrite : @model.OverwriteType = @json.from_json(@json.parse("99"))
  debug_inspect(
    overwrite,
    content=(
      #|Unknown(99)
    ),
  )
  let quality : @model.VideoQualityMode = @json.from_json(@json.parse("98"))
  debug_inspect(
    quality,
    content=(
      #|Unknown(98)
    ),
  )
  let sort : @model.SortOrderType = @json.from_json(@json.parse("97"))
  debug_inspect(
    sort,
    content=(
      #|Unknown(97)
    ),
  )
  let layout : @model.ForumLayoutType = @json.from_json(@json.parse("96"))
  debug_inspect(
    layout,
    content=(
      #|Unknown(96)
    ),
  )
  let unknown_bits = (1UL << 60) | 2UL
  let flags = @model.ChannelFlags::from_bits(unknown_bits)
  let encoded = flags.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|1152921504606846978
    ),
  )
  let decoded : @model.ChannelFlags = @json.from_json(@json.parse(encoded))
  assert_true(decoded.bits() == unknown_bits)
}
