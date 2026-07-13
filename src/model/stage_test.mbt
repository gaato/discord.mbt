///|
test "stage instance decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "id":"123000000000000001",
    #|  "guild_id":"81384788765712384",
    #|  "channel_id":"41771983423143937",
    #|  "topic":"Weekly town hall",
    #|  "privacy_level":2,
    #|  "guild_scheduled_event_id":null,
    #|  "discoverable_disabled":true,
    #|  "future":true
    #|}
  let stage : @model.StageInstance = @json.from_json(@json.parse(fixture))
  debug_inspect(
    stage,
    content=(
      #|{
      #|  id: 123000000000000001,
      #|  guild_id: 81384788765712384,
      #|  channel_id: 41771983423143937,
      #|  topic: "Weekly town hall",
      #|  privacy_level: GuildOnly,
      #|  guild_scheduled_event_id: Null,
      #|}
    ),
  )
}

///|
test "stage privacy level preserves an unknown value" {
  let level : @model.StagePrivacyLevel = @json.from_json(@json.parse("99"))
  debug_inspect(
    level,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    level.to_json().stringify(),
    content=(
      #|99
    ),
  )
}
