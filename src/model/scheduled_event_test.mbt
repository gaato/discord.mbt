///|
test "guild scheduled event decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "id": "122000000000000001",
    #|  "guild_id": "81384788765712384",
    #|  "channel_id": null,
    #|  "creator_id": "80351110224678912",
    #|  "name": "Community meetup",
    #|  "description": null,
    #|  "scheduled_start_time": "2026-08-01T10:00:00Z",
    #|  "scheduled_end_time": "2026-08-01T12:00:00Z",
    #|  "privacy_level": 2,
    #|  "status": 1,
    #|  "entity_type": 3,
    #|  "entity_id": null,
    #|  "entity_metadata": {"location":"Community Hall"},
    #|  "creator": {
    #|    "id":"80351110224678912","username":"Nelly","discriminator":"0",
    #|    "global_name":"Nelly","avatar":null
    #|  },
    #|  "user_count": 42,
    #|  "image": null,
    #|  "recurrence_rule": {
    #|    "start":"2026-08-01T10:00:00Z","end":null,
    #|    "frequency":2,"interval":1,"by_weekday":[0,2],
    #|    "by_n_weekday":[{"n":1,"day":0}],"by_month":[8],
    #|    "by_month_day":[1],"by_year_day":[213],"count":4,
    #|    "future":true
    #|  },
    #|  "brand_new_field_from_discord": true
    #|}
  let event : @model.GuildScheduledEvent = @json.from_json(@json.parse(fixture))
  debug_inspect(
    event,
    content=(
      #|{
      #|  id: 122000000000000001,
      #|  guild_id: 81384788765712384,
      #|  channel_id: Null,
      #|  creator_id: Some(Value(80351110224678912)),
      #|  name: "Community meetup",
      #|  description: Some(Null),
      #|  scheduled_start_time: "2026-08-01T10:00:00Z",
      #|  scheduled_end_time: Value("2026-08-01T12:00:00Z"),
      #|  privacy_level: GuildOnly,
      #|  status: Scheduled,
      #|  entity_type: External,
      #|  entity_id: Null,
      #|  entity_metadata: Value({ location: Some("Community Hall") }),
      #|  creator: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Some(Value("Nelly")),
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
      #|    },
      #|  ),
      #|  user_count: Some(42),
      #|  image: Some(Null),
      #|  recurrence_rule: Value(
      #|    {
      #|      start: "2026-08-01T10:00:00Z",
      #|      end: Some(Null),
      #|      frequency: Weekly,
      #|      interval: 1,
      #|      by_weekday: Some([Monday, Wednesday]),
      #|      by_n_weekday: Some([{ n: 1, day: Monday }]),
      #|      by_month: Some([August]),
      #|      by_month_day: Some([1]),
      #|      by_year_day: Some([213]),
      #|      count: Some(4),
      #|    },
      #|  ),
      #|}
    ),
  )
}

///|
test "scheduled event enums preserve unknown values" {
  let privacy : @model.GuildScheduledEventPrivacyLevel = @json.from_json(
    @json.parse("99"),
  )
  let status : @model.GuildScheduledEventStatus = @json.from_json(
    @json.parse("98"),
  )
  let entity : @model.GuildScheduledEventEntityType = @json.from_json(
    @json.parse("97"),
  )
  inspect(
    [privacy.to_json(), status.to_json(), entity.to_json()]
    .to_json()
    .stringify(),
    content=(
      #|[99,98,97]
    ),
  )
}
