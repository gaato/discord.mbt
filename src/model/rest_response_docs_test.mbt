///|
test "discord docs: guild scheduled event user response" {
  let fixture =
    #|{"guild_scheduled_event_id":"122000000000000001","user":{"id":"80351110224678912","username":"Nelly","discriminator":"0","global_name":"Nelly","avatar":null},"member":{"roles":[],"joined_at":"2025-06-01T10:00:00.000000+00:00"}}
  let value : @model.GuildScheduledEventUser = @json.from_json(
    @json.parse(fixture),
  )
  assert_eq(value.guild_scheduled_event_id.to_string(), "122000000000000001")
  assert_eq(value.user.username, "Nelly")
  assert_true(value.guild_member is Some(_))
  assert_eq(value.to_json().stringify(), fixture)
}

///|
test "discord docs: scheduled event recurrence rule" {
  let fixture =
    #|{"start":"2026-08-01T10:00:00Z","end":null,"frequency":2,"interval":1,"by_weekday":[0,2],"by_n_weekday":[{"n":1,"day":0}],"by_month":[8],"by_month_day":[1],"by_year_day":[213],"count":4}
  let value : @model.GuildScheduledEventRecurrenceRule = @json.from_json(
    @json.parse(fixture),
  )
  assert_true(value.frequency is Weekly)
  assert_true(value.by_weekday is Some(Value([Monday, Wednesday])))
  assert_eq(value.to_json().stringify(), fixture)
}

///|
test "discord docs: poll answer voters response" {
  let fixture =
    #|{"users":[{"id":"80351110224678912","username":"Nelly","discriminator":"0","global_name":"Nelly","avatar":null}]}
  let value : @model.PollAnswerVoters = @json.from_json(@json.parse(fixture))
  assert_eq(value.users.length(), 1)
  assert_eq(value.users[0].username, "Nelly")
  assert_eq(value.to_json().stringify(), fixture)
}
