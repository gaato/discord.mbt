///|
test "guild decodes a full fixture with future features" {
  let fixture =
    #|{
    #|  "id": "81384788765712384",
    #|  "name": "Discord Developers",
    #|  "icon": "a_1269e74af4df7417b13759eae50c83dc",
    #|  "icon_hash": null,
    #|  "splash": null,
    #|  "discovery_splash": "5678",
    #|  "owner": true,
    #|  "owner_id": "80351110224678912",
    #|  "permissions": "1024",
    #|  "afk_channel_id": null,
    #|  "afk_timeout": 300,
    #|  "widget_enabled": true,
    #|  "widget_channel_id": "41771983423143937",
    #|  "verification_level": 2,
    #|  "default_message_notifications": 1,
    #|  "explicit_content_filter": 2,
    #|  "roles": [{
    #|    "id": "81384788765712384",
    #|    "name": "@everyone",
    #|    "color": 0,
    #|    "hoist": false,
    #|    "position": 0,
    #|    "permissions": "104324673",
    #|    "managed": false,
    #|    "mentionable": false,
    #|    "flags": 0
    #|  }],
    #|  "emojis": [{
    #|    "id": "41771983429993937",
    #|    "name": "wave",
    #|    "animated": false,
    #|    "available": true
    #|  }],
    #|  "features": ["COMMUNITY", "SOME_FUTURE_FEATURE"],
    #|  "mfa_level": 1,
    #|  "application_id": null,
    #|  "system_channel_id": "41771983423143937",
    #|  "system_channel_flags": 3,
    #|  "rules_channel_id": null,
    #|  "max_presences": null,
    #|  "max_members": 500000,
    #|  "vanity_url_code": "discord-developers",
    #|  "description": null,
    #|  "banner": "banner_hash",
    #|  "premium_tier": 3,
    #|  "premium_subscription_count": 42,
    #|  "preferred_locale": "en-US",
    #|  "public_updates_channel_id": null,
    #|  "max_video_channel_users": 25,
    #|  "max_stage_video_channel_users": 50,
    #|  "approximate_member_count": 123456,
    #|  "approximate_presence_count": 23456,
    #|  "welcome_screen": {
    #|    "description": "Welcome!",
    #|    "welcome_channels": [{
    #|      "channel_id": "41771983423143937",
    #|      "description": "Read the rules",
    #|      "emoji_id": null,
    #|      "emoji_name": "👋"
    #|    }]
    #|  },
    #|  "nsfw_level": 0,
    #|  "stickers": [],
    #|  "premium_progress_bar_enabled": true,
    #|  "safety_alerts_channel_id": null,
    #|  "incidents_data": {"invites_disabled_until": null},
    #|  "brand_new_field_from_discord": true
    #|}
  let guild : @model.Guild = @json.from_json(@json.parse(fixture))
  debug_inspect(
    guild,
    content=(
      #|{
      #|  id: 81384788765712384,
      #|  name: "Discord Developers",
      #|  icon: Value("a_1269e74af4df7417b13759eae50c83dc"),
      #|  icon_hash: Some(Null),
      #|  splash: Null,
      #|  discovery_splash: Value("5678"),
      #|  owner: Some(true),
      #|  owner_id: 80351110224678912,
      #|  permissions: Some(1024),
      #|  afk_channel_id: Null,
      #|  afk_timeout: 300,
      #|  widget_enabled: Some(true),
      #|  widget_channel_id: Some(Value(41771983423143937)),
      #|  verification_level: Medium,
      #|  default_message_notifications: OnlyMentions,
      #|  explicit_content_filter: AllMembers,
      #|  roles: [
      #|    {
      #|      id: 81384788765712384,
      #|      name: "@everyone",
      #|      color: 0,
      #|      colors: None,
      #|      hoist: false,
      #|      icon: None,
      #|      unicode_emoji: None,
      #|      position: 0,
      #|      permissions: 104324673,
      #|      managed: false,
      #|      mentionable: false,
      #|      tags: None,
      #|      flags: Some(0),
      #|    },
      #|  ],
      #|  emojis: [
      #|    {
      #|      id: Some(Value(41771983429993937)),
      #|      name: Value("wave"),
      #|      animated: Some(false),
      #|      roles: None,
      #|      user: None,
      #|      require_colons: None,
      #|      managed: None,
      #|      available: Some(true),
      #|    },
      #|  ],
      #|  features: [Community, Unknown("SOME_FUTURE_FEATURE")],
      #|  mfa_level: Elevated,
      #|  application_id: Null,
      #|  system_channel_id: Value(41771983423143937),
      #|  system_channel_flags: 3,
      #|  rules_channel_id: Null,
      #|  max_presences: Some(Null),
      #|  max_members: Some(500000),
      #|  vanity_url_code: Value("discord-developers"),
      #|  description: Null,
      #|  banner: Value("banner_hash"),
      #|  premium_tier: Tier3,
      #|  premium_subscription_count: Some(42),
      #|  preferred_locale: "en-US",
      #|  public_updates_channel_id: Null,
      #|  max_video_channel_users: Some(25),
      #|  max_stage_video_channel_users: Some(50),
      #|  approximate_member_count: Some(123456),
      #|  approximate_presence_count: Some(23456),
      #|  welcome_screen: Some(
      #|    {
      #|      description: Value("Welcome!"),
      #|      welcome_channels: [
      #|        {
      #|          channel_id: 41771983423143937,
      #|          description: "Read the rules",
      #|          emoji_id: Null,
      #|          emoji_name: Value("👋"),
      #|        },
      #|      ],
      #|    },
      #|  ),
      #|  nsfw_level: Some(Default),
      #|  stickers: Some([]),
      #|  premium_progress_bar_enabled: Some(true),
      #|  safety_alerts_channel_id: Null,
      #|  incidents_data: Some(
      #|    Value(
      #|      {
      #|        invites_disabled_until: Some(Null),
      #|        dms_disabled_until: None,
      #|        dm_spam_detected_at: None,
      #|        raid_detected_at: None,
      #|      },
      #|    ),
      #|  ),
      #|}
    ),
  )
  assert_true(
    guild.features[1] == @model.GuildFeature::Unknown("SOME_FUTURE_FEATURE"),
  )
  let encoded = guild.to_json().stringify()
  assert_true(encoded.contains("SOME_FUTURE_FEATURE"))
  let round_tripped : @model.Guild = @json.from_json(@json.parse(encoded))
  assert_true(
    round_tripped.features[1] ==
    @model.GuildFeature::Unknown("SOME_FUTURE_FEATURE"),
  )
}

///|
test "guild decodes required fields only" {
  let fixture =
    #|{
    #|  "id":"1","name":"tiny","icon":null,"splash":null,
    #|  "discovery_splash":null,"owner_id":"2","afk_channel_id":null,
    #|  "afk_timeout":60,"verification_level":0,
    #|  "default_message_notifications":0,"explicit_content_filter":0,
    #|  "roles":[],"emojis":[],"features":[],"mfa_level":0,
    #|  "application_id":null,"system_channel_id":null,
    #|  "system_channel_flags":0,"rules_channel_id":null,
    #|  "vanity_url_code":null,"description":null,"banner":null,
    #|  "premium_tier":0,"preferred_locale":"en-US",
    #|  "public_updates_channel_id":null,"nsfw_level":0,
    #|  "premium_progress_bar_enabled":false,
    #|  "safety_alerts_channel_id":null
    #|}
  let guild : @model.Guild = @json.from_json(@json.parse(fixture))
  debug_inspect(
    guild,
    content=(
      #|{
      #|  id: 1,
      #|  name: "tiny",
      #|  icon: Null,
      #|  icon_hash: None,
      #|  splash: Null,
      #|  discovery_splash: Null,
      #|  owner: None,
      #|  owner_id: 2,
      #|  permissions: None,
      #|  afk_channel_id: Null,
      #|  afk_timeout: 60,
      #|  widget_enabled: None,
      #|  widget_channel_id: None,
      #|  verification_level: None,
      #|  default_message_notifications: AllMessages,
      #|  explicit_content_filter: Disabled,
      #|  roles: [],
      #|  emojis: [],
      #|  features: [],
      #|  mfa_level: None,
      #|  application_id: Null,
      #|  system_channel_id: Null,
      #|  system_channel_flags: 0,
      #|  rules_channel_id: Null,
      #|  max_presences: None,
      #|  max_members: None,
      #|  vanity_url_code: Null,
      #|  description: Null,
      #|  banner: Null,
      #|  premium_tier: None,
      #|  premium_subscription_count: None,
      #|  preferred_locale: "en-US",
      #|  public_updates_channel_id: Null,
      #|  max_video_channel_users: None,
      #|  max_stage_video_channel_users: None,
      #|  approximate_member_count: None,
      #|  approximate_presence_count: None,
      #|  welcome_screen: None,
      #|  nsfw_level: Some(Default),
      #|  stickers: None,
      #|  premium_progress_bar_enabled: Some(false),
      #|  safety_alerts_channel_id: Null,
      #|  incidents_data: None,
      #|}
    ),
  )
}

///|
test "guild encode omits absent optional fields" {
  let fixture =
    #|{
    #|  "id":"1","name":"tiny","icon":null,"splash":null,
    #|  "discovery_splash":null,"owner_id":"2","afk_channel_id":null,
    #|  "afk_timeout":60,"verification_level":0,
    #|  "default_message_notifications":0,"explicit_content_filter":0,
    #|  "roles":[],"emojis":[],"features":[],"mfa_level":0,
    #|  "application_id":null,"system_channel_id":null,
    #|  "system_channel_flags":0,"rules_channel_id":null,
    #|  "vanity_url_code":null,"description":null,"banner":null,
    #|  "premium_tier":0,"preferred_locale":"en-US",
    #|  "public_updates_channel_id":null,"nsfw_level":0,
    #|  "premium_progress_bar_enabled":false,
    #|  "safety_alerts_channel_id":null
    #|}
  let guild : @model.Guild = @json.from_json(@json.parse(fixture))
  inspect(
    guild.to_json().stringify(),
    content=(
      #|{"id":"1","name":"tiny","icon":null,"splash":null,"discovery_splash":null,"owner_id":"2","afk_channel_id":null,"afk_timeout":60,"verification_level":0,"default_message_notifications":0,"explicit_content_filter":0,"roles":[],"emojis":[],"features":[],"mfa_level":0,"application_id":null,"system_channel_id":null,"system_channel_flags":0,"rules_channel_id":null,"vanity_url_code":null,"description":null,"banner":null,"premium_tier":0,"preferred_locale":"en-US","public_updates_channel_id":null,"nsfw_level":0,"premium_progress_bar_enabled":false,"safety_alerts_channel_id":null}
    ),
  )
}

///|
test "guild numeric enums preserve unknown values" {
  let verification : @model.VerificationLevel = @json.from_json(
    @json.parse("99"),
  )
  let notifications : @model.DefaultMessageNotifications = @json.from_json(
    @json.parse("98"),
  )
  let content_filter : @model.ExplicitContentFilter = @json.from_json(
    @json.parse("97"),
  )
  let mfa : @model.MfaLevel = @json.from_json(@json.parse("96"))
  let premium : @model.PremiumTier = @json.from_json(@json.parse("95"))
  let nsfw : @model.NsfwLevel = @json.from_json(@json.parse("94"))
  inspect(
    [
      verification.to_json(),
      notifications.to_json(),
      content_filter.to_json(),
      mfa.to_json(),
      premium.to_json(),
      nsfw.to_json(),
    ]
    .to_json()
    .stringify(),
    content=(
      #|[99,98,97,96,95,94]
    ),
  )
}

///|
test "system channel flags combine and preserve unknown bits" {
  let flags = @model.SystemChannelFlags::suppress_join_notifications() |
    @model.SystemChannelFlags::suppress_premium_subscriptions()
  assert_true(flags.bits() == 3)
  assert_true(
    flags.contains(@model.SystemChannelFlags::suppress_join_notifications()),
  )
  let bits = (1UL << 60) | flags.bits()
  let unknown = @model.SystemChannelFlags::from_bits(bits)
  let encoded = unknown.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|1152921504606846979
    ),
  )
  let decoded : @model.SystemChannelFlags = @json.from_json(
    @json.parse(encoded),
  )
  assert_true(decoded.bits() == bits)
}
