// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/guild.mdx
// Skipped blocks from this page:
// - line 276, Example Guild Preview — guild preview objects are not modeled.
// - line 315, Example Guild Widget Settings — guild widget settings are not modeled.
// - line 343, Example Guild Widget — guild widget objects are not modeled.
// - line 412, Example Guild Member — the illustrative member contains an empty placeholder user object.
// - line 660, Example Guild Onboarding — guild onboarding objects are not modeled.
// - line 739, Example Incidents Data — guild incidents data is not modeled.
// - line 1222, Example Response — the channel-position map response has no model.

///|
test "discord docs: example guild (line 193)" {
  let fixture =
    #|{
    #|  "id": "197038439483310086",
    #|  "name": "Discord Testers",
    #|  "icon": "f64c482b807da4f539cff778d174971c",
    #|  "description": "The official place to report Discord Bugs!",
    #|  "splash": null,
    #|  "discovery_splash": null,
    #|  "features": [
    #|    "ANIMATED_ICON",
    #|    "VERIFIED",
    #|    "NEWS",
    #|    "VANITY_URL",
    #|    "DISCOVERABLE",
    #|    "MORE_EMOJI",
    #|    "INVITE_SPLASH",
    #|    "BANNER",
    #|    "COMMUNITY"
    #|  ],
    #|  "emojis": [],
    #|  "banner": "9b6439a7de04f1d26af92f84ac9e1e4a",
    #|  "owner_id": "73193882359173120",
    #|  "application_id": null,
    #|  "region": null,
    #|  "afk_channel_id": null,
    #|  "afk_timeout": 300,
    #|  "system_channel_id": null,
    #|  "widget_enabled": true,
    #|  "widget_channel_id": null,
    #|  "verification_level": 3,
    #|  "roles": [],
    #|  "default_message_notifications": 1,
    #|  "mfa_level": 1,
    #|  "explicit_content_filter": 2,
    #|  "max_presences": 40000,
    #|  "max_members": 250000,
    #|  "vanity_url_code": "discord-testers",
    #|  "premium_tier": 3,
    #|  "premium_subscription_count": 33,
    #|  "system_channel_flags": 0,
    #|  "preferred_locale": "en-US",
    #|  "rules_channel_id": "441688182833020939",
    #|  "public_updates_channel_id": "281283303326089216",
    #|  "safety_alerts_channel_id": "281283303326089216"
    #|}
  let first : @model.Guild = @json.from_json(@json.parse(fixture))
  let second : @model.Guild = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="197038439483310086")
  assert_eq(first.name, "Discord Testers")
}

///|
test "discord docs: example unavailable guild (line 247)" {
  let fixture =
    #|{
    #|  "id": "41771983423143937",
    #|  "unavailable": true
    #|}
  let first : @model.UnavailableGuild = @json.from_json(@json.parse(fixture))
  let second : @model.UnavailableGuild = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="41771983423143937")
  assert_true(first.unavailable)
}

///|
test "discord docs: example ban (line 518)" {
  let fixture =
    #|{
    #|  "reason": "mentioning b1nzy",
    #|  "user": {
    #|    "username": "Mason",
    #|    "discriminator": "9999",
    #|    "id": "53908099506183680",
    #|    "avatar": "a_bab14f271d565501444b2ca3be944b25",
    #|    "public_flags": 131141
    #|  }
    #|}
  let first : @model.GuildBan = @json.from_json(@json.parse(fixture))
  let second : @model.GuildBan = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  assert_true(first.reason == @model.Nullable::Value("mentioning b1nzy"))
  inspect(first.user.id.to_string(), content="53908099506183680")
}

///|
test "discord docs: example welcome screen (line 554)" {
  let fixture =
    #|{
    #|  "description": "Discord Developers is a place to learn about Discord's API, bots, and SDKs and integrations. This is NOT a general Discord support server.",
    #|  "welcome_channels": [
    #|    {
    #|      "channel_id": "697138785317814292",
    #|      "description": "Follow for official Discord API updates",
    #|      "emoji_id": null,
    #|      "emoji_name": "📡"
    #|    },
    #|    {
    #|      "channel_id": "697236247739105340",
    #|      "description": "Get help with Bot Verifications",
    #|      "emoji_id": null,
    #|      "emoji_name": "📸"
    #|    },
    #|    {
    #|      "channel_id": "697489244649816084",
    #|      "description": "Create amazing things with Discord's API",
    #|      "emoji_id": null,
    #|      "emoji_name": "🔬"
    #|    },
    #|    {
    #|      "channel_id": "613425918748131338",
    #|      "description": "Integrate Discord into your game",
    #|      "emoji_id": null,
    #|      "emoji_name": "🎮"
    #|    },
    #|    {
    #|      "channel_id": "646517734150242346",
    #|      "description": "Find more places to help you on your quest",
    #|      "emoji_id": null,
    #|      "emoji_name": "🔦"
    #|    }
    #|  ]
    #|}
  let first : @model.WelcomeScreen = @json.from_json(@json.parse(fixture))
  let second : @model.WelcomeScreen = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.welcome_channels.length(), content="5")
  inspect(
    first.welcome_channels[0].channel_id.to_string(),
    content="697138785317814292",
  )
}

///|
test "discord docs: example response (line 761)" {
  let fixture =
    #|{
    #|  "id": "2909267986263572999",
    #|  "name": "Mason's Test Server",
    #|  "icon": "389030ec9db118cb5b85a732333b7c98",
    #|  "description": null,
    #|  "splash": "75610b05a0dd09ec2c3c7df9f6975ea0",
    #|  "discovery_splash": null,
    #|  "approximate_member_count": 2,
    #|  "approximate_presence_count": 2,
    #|  "features": [
    #|    "INVITE_SPLASH",
    #|    "VANITY_URL",
    #|    "COMMERCE",
    #|    "BANNER",
    #|    "NEWS",
    #|    "VERIFIED",
    #|    "VIP_REGIONS"
    #|  ],
    #|  "emojis": [
    #|    {
    #|      "name": "ultrafastparrot",
    #|      "roles": [],
    #|      "id": "393564762228785161",
    #|      "require_colons": true,
    #|      "managed": false,
    #|      "animated": true,
    #|      "available": true
    #|    }
    #|  ],
    #|  "banner": "5c3cb8d1bc159937fffe7e641ec96ca7",
    #|  "owner_id": "53908232506183680",
    #|  "application_id": null,
    #|  "region": null,
    #|  "afk_channel_id": null,
    #|  "afk_timeout": 300,
    #|  "system_channel_id": null,
    #|  "widget_enabled": true,
    #|  "widget_channel_id": "639513352485470208",
    #|  "verification_level": 0,
    #|  "roles": [
    #|    {
    #|      "id": "2909267986263572999",
    #|      "name": "@everyone",
    #|      "permissions": "49794752",
    #|      "position": 0,
    #|      "color": 0,
    #|      "colors": {
    #|        "primary_color": 0,
    #|        "secondary_color": null,
    #|        "tertiary_color": null
    #|      },
    #|      "hoist": false,
    #|      "managed": false,
    #|      "mentionable": false
    #|    }
    #|  ],
    #|  "default_message_notifications": 1,
    #|  "mfa_level": 0,
    #|  "explicit_content_filter": 0,
    #|  "max_presences": null,
    #|  "max_members": 250000,
    #|  "max_video_channel_users": 25,
    #|  "vanity_url_code": "no",
    #|  "premium_tier": 0,
    #|  "premium_subscription_count": 0,
    #|  "system_channel_flags": 0,
    #|  "preferred_locale": "en-US",
    #|  "rules_channel_id": null,
    #|  "public_updates_channel_id": null,
    #|  "safety_alerts_channel_id": null
    #|}
  let first : @model.Guild = @json.from_json(@json.parse(fixture))
  let second : @model.Guild = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="2909267986263572999")
  assert_eq(first.name, "Mason's Test Server")
}
