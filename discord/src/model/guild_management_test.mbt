///|
test "guild preview round trips a docs-shaped fixture" {
  let fixture =
    #|{
    #|  "id":"1","name":"MoonBit Guild","icon":"icon_hash",
    #|  "splash":null,"discovery_splash":"discovery_hash",
    #|  "emojis":[{"id":"2","name":"wave","animated":false}],
    #|  "features":["COMMUNITY","DISCOVERABLE"],
    #|  "approximate_member_count":120,
    #|  "approximate_presence_count":42,
    #|  "description":"A public guild",
    #|  "stickers":[{
    #|    "id":"3","name":"hello","description":null,"tags":"wave",
    #|    "type":2,"format_type":1,"guild_id":"1","available":true
    #|  }]
    #|}
  let value : @model.GuildPreview = @json.from_json(@json.parse(fixture))
  let round_tripped : @model.GuildPreview = @json.from_json(value.to_json())
  json_inspect(round_tripped, content={
    "id": "1",
    "name": "MoonBit Guild",
    "icon": "icon_hash",
    "splash": null,
    "discovery_splash": "discovery_hash",
    "emojis": [{ "id": "2", "name": "wave", "animated": false }],
    "features": ["COMMUNITY", "DISCOVERABLE"],
    "approximate_member_count": 120,
    "approximate_presence_count": 42,
    "description": "A public guild",
    "stickers": [
      {
        "id": "3",
        "name": "hello",
        "description": null,
        "tags": "wave",
        "type": 2,
        "format_type": 1,
        "available": true,
        "guild_id": "1",
      },
    ],
  })
}

///|
test "guild management result models round trip" {
  let bulk_fixture =
    #|{"banned_users":["10","11"],"failed_users":["12"]}
  let bulk : @model.BulkBanResponse = @json.from_json(@json.parse(bulk_fixture))
  let bulk_round : @model.BulkBanResponse = @json.from_json(bulk.to_json())
  json_inspect(bulk_round, content={
    "banned_users": ["10", "11"],
    "failed_users": ["12"],
  })
  let prune : @model.GuildPruneResult = @json.from_json(
    @json.parse("{\"pruned\":null}"),
  )
  let prune_round : @model.GuildPruneResult = @json.from_json(prune.to_json())
  json_inspect(prune_round, content={ "pruned": null })
  let vanity : @model.GuildVanityUrl = @json.from_json(
    @json.parse("{\"code\":\"moonbit\",\"uses\":99}"),
  )
  let vanity_round : @model.GuildVanityUrl = @json.from_json(vanity.to_json())
  json_inspect(vanity_round, content={ "code": "moonbit", "uses": 99 })
}

///|
test "guild widget models round trip a docs-shaped fixture" {
  let settings : @model.GuildWidgetSettings = @json.from_json(
    @json.parse("{\"enabled\":true,\"channel_id\":\"20\"}"),
  )
  let settings_round : @model.GuildWidgetSettings = @json.from_json(
    settings.to_json(),
  )
  json_inspect(settings_round, content={ "enabled": true, "channel_id": "20" })
  let fixture =
    #|{
    #|  "id":"1","name":"MoonBit Guild",
    #|  "instant_invite":"https://discord.gg/moonbit",
    #|  "channels":[{"id":"20","name":"General","position":0}],
    #|  "members":[{
    #|    "id":"0","username":"Wumpus","discriminator":"0000",
    #|    "avatar":null,"status":"online",
    #|    "avatar_url":"https://cdn.discordapp.com/widget-avatars/abc"
    #|  }],
    #|  "presence_count":1
    #|}
  let widget : @model.GuildWidget = @json.from_json(@json.parse(fixture))
  let round_tripped : @model.GuildWidget = @json.from_json(widget.to_json())
  json_inspect(round_tripped, content={
    "id": "1",
    "name": "MoonBit Guild",
    "instant_invite": "https://discord.gg/moonbit",
    "channels": [{ "id": "20", "name": "General", "position": 0 }],
    "members": [
      {
        "id": "0",
        "username": "Wumpus",
        "discriminator": "0000",
        "avatar": null,
        "status": "online",
        "avatar_url": "https://cdn.discordapp.com/widget-avatars/abc",
      },
    ],
    "presence_count": 1,
  })
}

///|
test "guild onboarding and integer enums round trip" {
  let fixture =
    #|{
    #|  "guild_id":"1",
    #|  "prompts":[{
    #|    "id":"40","type":1,"title":"Pick a topic",
    #|    "single_select":true,"required":true,"in_onboarding":true,
    #|    "options":[{
    #|      "id":"41","channel_ids":["20"],"role_ids":["30"],
    #|      "emoji":{"id":"50","name":"wave","animated":false},
    #|      "emoji_id":"50","emoji_name":"wave","emoji_animated":false,
    #|      "title":"News","description":null
    #|    }]
    #|  }],
    #|  "default_channel_ids":["20"],"enabled":true,"mode":1
    #|}
  let onboarding : @model.GuildOnboarding = @json.from_json(
    @json.parse(fixture),
  )
  let round_tripped : @model.GuildOnboarding = @json.from_json(
    onboarding.to_json(),
  )
  json_inspect(round_tripped, content={
    "guild_id": "1",
    "prompts": [
      {
        "id": "40",
        "type": 1,
        "options": [
          {
            "id": "41",
            "channel_ids": ["20"],
            "role_ids": ["30"],
            "emoji": { "id": "50", "name": "wave", "animated": false },
            "emoji_id": "50",
            "emoji_name": "wave",
            "emoji_animated": false,
            "title": "News",
            "description": null,
          },
        ],
        "title": "Pick a topic",
        "single_select": true,
        "required": true,
        "in_onboarding": true,
      },
    ],
    "default_channel_ids": ["20"],
    "enabled": true,
    "mode": 1,
  })
  assert_true(round_tripped.prompts[0].typ == Dropdown)
  assert_true(round_tripped.mode == Advanced)
  assert_true(@model.OnboardingPromptType::from_int(99) == Unknown(99))
  assert_true(@model.OnboardingMode::from_int(99) == Unknown(99))
  inspect(@model.OnboardingPromptType::Unknown(99).to_int(), content="99")
  inspect(@model.OnboardingMode::Unknown(99).to_int(), content="99")
}
