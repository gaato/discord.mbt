///|
async test "channel optional bodies pin set and omitted forms" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let bodies : Array[Json] = []
  client.perform_override_.val = Some((_route, path, _headers, body, _files) => {
    paths.push(path)
    bodies.push(body.unwrap_or(Json::null()))
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  client.set_voice_channel_status(channel_id, status="Pairing")
  client.set_voice_channel_status(channel_id)
  client.group_dm_add_recipient(channel_id, user_id, "oauth", nick="Nelly")
  client.group_dm_add_recipient(channel_id, user_id, "oauth")
  assert_eq(paths, [
    "/api/v10/channels/10/voice-status", "/api/v10/channels/10/voice-status", "/api/v10/channels/10/recipients/20",
    "/api/v10/channels/10/recipients/20",
  ])
  json_inspect(bodies, content=[
    { "status": "Pairing" },
    { "status": null },
    { "access_token": "oauth", "nick": "Nelly" },
    { "access_token": "oauth" },
  ])
}

///|
async test "current user body pins every set option and all omitted" {
  let client = Client("test-token")
  defer client.close()
  let bodies : Array[Json] = []
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    bodies.push(body.unwrap_or(Json::null()))
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  try
    client.modify_current_user(
      username="Nelly",
      avatar="data:image/png;base64,AAAA",
      banner="data:image/png;base64,BBBB",
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake user response should not decode")
  }
  try client.modify_current_user() catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake user response should not decode")
  }
  assert_eq(bodies.length(), 2)
  json_inspect(bodies[0], content={
    "username": "Nelly",
    "avatar": "data:image/png;base64,AAAA",
    "banner": "data:image/png;base64,BBBB",
  })
  inspect(bodies[1].stringify(), content="{}")
}

///|
async test "scheduled event modify body pins every set option and all omitted" {
  let client = Client("test-token")
  defer client.close()
  let bodies : Array[Json] = []
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    bodies.push(body.unwrap_or(Json::null()))
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(30UL)
  let event_id : @model.ScheduledEventId = Id(40UL)
  let channel_id : @model.ChannelId = Id(50UL)
  let recurrence = @model.GuildScheduledEventRecurrenceRule::{
    start: Timestamp("2026-08-01T10:00:00Z"),
    end: Some(Value(Timestamp("2026-09-01T10:00:00Z"))),
    frequency: Weekly,
    interval: 1,
    by_weekday: Some([Monday]),
    by_n_weekday: None,
    by_month: None,
    by_month_day: None,
    by_year_day: None,
    count: Some(4),
  }
  try
    client.modify_guild_scheduled_event(
      guild_id,
      event_id,
      channel_id~,
      entity_metadata={ location: Some("Town hall"), },
      name="Weekly meetup",
      privacy_level=GuildOnly,
      scheduled_start_time=Timestamp("2026-08-01T10:00:00Z"),
      scheduled_end_time=Timestamp("2026-08-01T12:00:00Z"),
      description="Meet everyone",
      entity_type=Voice,
      status=Active,
      image="data:image/png;base64,AAAA",
      recurrence_rule=recurrence,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake event response should not decode")
  }
  try client.modify_guild_scheduled_event(guild_id, event_id) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake event response should not decode")
  }
  assert_eq(bodies.length(), 2)
  json_inspect(bodies[0], content={
    "channel_id": "50",
    "entity_metadata": { "location": "Town hall" },
    "name": "Weekly meetup",
    "privacy_level": 2,
    "scheduled_start_time": "2026-08-01T10:00:00Z",
    "scheduled_end_time": "2026-08-01T12:00:00Z",
    "description": "Meet everyone",
    "entity_type": 2,
    "status": 2,
    "image": "data:image/png;base64,AAAA",
    "recurrence_rule": {
      "start": "2026-08-01T10:00:00Z",
      "end": "2026-09-01T10:00:00Z",
      "frequency": 2,
      "interval": 1,
      "by_weekday": [0],
      "count": 4,
    },
  })
  inspect(bodies[1].stringify(), content="{}")
}

///|
async test "sticker modify body pins every set option and all omitted" {
  let client = Client("test-token")
  defer client.close()
  let bodies : Array[Json] = []
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    bodies.push(body.unwrap_or(Json::null()))
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(60UL)
  let sticker_id : @model.StickerId = Id(70UL)
  try
    client.modify_guild_sticker(
      guild_id,
      sticker_id,
      name="Nelly",
      description="Nelly waves",
      tags="wave,hello",
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake sticker response should not decode")
  }
  try client.modify_guild_sticker(guild_id, sticker_id) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake sticker response should not decode")
  }
  assert_eq(bodies.length(), 2)
  json_inspect(bodies[0], content={
    "name": "Nelly",
    "description": "Nelly waves",
    "tags": "wave,hello",
  })
  inspect(bodies[1].stringify(), content="{}")
}

///|
async test "sticker field validations reject each out-of-range value" {
  let client = Client("test-token")
  defer client.close()
  let guild_id : @model.GuildId = Id(1UL)
  let sticker_id : @model.StickerId = Id(2UL)
  for
    item in [
      ("name", "x", "sticker name must be between 2 and 30 characters"),
      (
        "description", "x", "sticker description must be between 2 and 100 characters",
      ),
      ("tags", "", "sticker tags must be between 1 and 200 characters"),
    ] {
    let (field, value, expected) = item
    try
      (match field {
        "name" => client.modify_guild_sticker(guild_id, sticker_id, name=value)
        "description" =>
          client.modify_guild_sticker(guild_id, sticker_id, description=value)
        _ => client.modify_guild_sticker(guild_id, sticker_id, tags=value)
      })
      |> ignore
    catch {
      Validation(message~) => assert_eq(message, expected)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected sticker validation for \{field}")
    }
  }
}
