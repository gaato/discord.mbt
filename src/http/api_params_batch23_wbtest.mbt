///|
async test "guild audit, ban, and member queries pin set and omitted parameters" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  perform.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let guild_id : @model.GuildId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let entry_id : @model.AuditLogEntryId = Id(30UL)
  try
    client.get_guild_audit_log(
      guild_id,
      user_id~,
      action_type=ChannelDelete,
      after=entry_id,
      limit=100,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake audit response should not decode")
  }
  try client.get_guild_audit_log(guild_id) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake audit response should not decode")
  }
  client.get_guild_bans(guild_id, limit=1000, after=user_id) |> ignore
  client.get_guild_bans(guild_id) |> ignore
  client.list_guild_members(guild_id, limit=1000, after=user_id) |> ignore
  client.list_guild_members(guild_id) |> ignore
  client.search_guild_members(guild_id, "neko sama", limit=25) |> ignore
  assert_eq(paths, [
    "/api/v10/guilds/10/audit-logs?user_id=20&action_type=12&after=30&limit=100",
    "/api/v10/guilds/10/audit-logs", "/api/v10/guilds/10/bans?limit=1000&after=20",
    "/api/v10/guilds/10/bans", "/api/v10/guilds/10/members?limit=1000&after=20",
    "/api/v10/guilds/10/members", "/api/v10/guilds/10/members/search?query=neko%20sama&limit=25",
  ])
}

///|
async test "current user guild query pins set and omitted parameters" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  perform.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let cursor : @model.GuildId = Id(40UL)
  client.get_current_user_guilds(limit=200, after=cursor, with_counts=true)
  |> ignore
  client.get_current_user_guilds() |> ignore
  client.get_current_user_guilds(shard=3) |> ignore
  client.paginate_current_user_guilds(shard=1).collect(max=1) |> ignore
  assert_eq(paths, [
    "/api/v10/users/@me/guilds?limit=200&after=40&with_counts=true", "/api/v10/users/@me/guilds",
    "/api/v10/users/@me/guilds?shard=3", "/api/v10/users/@me/guilds?limit=200&shard=1",
  ])
  try client.get_current_user_guilds(shard=-1) |> ignore catch {
    Validation(message~) =>
      inspect(message, content="shard must be non-negative")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a shard validation error")
  }
}

///|
async test "message pagination query pins around before after and omitted arms" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  perform.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let channel_id : @model.ChannelId = Id(50UL)
  let cursor : @model.MessageId = Id(60UL)
  client.get_channel_messages(channel_id, limit=100, around=cursor) |> ignore
  client.get_channel_messages(channel_id, before=cursor) |> ignore
  client.get_channel_messages(channel_id, after=cursor) |> ignore
  client.get_channel_messages(channel_id) |> ignore
  assert_eq(paths, [
    "/api/v10/channels/50/messages?limit=100&around=60", "/api/v10/channels/50/messages?before=60",
    "/api/v10/channels/50/messages?after=60", "/api/v10/channels/50/messages",
  ])
}

///|
async test "scheduled event queries pin set and omitted parameters" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  perform.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let guild_id : @model.GuildId = Id(70UL)
  let event_id : @model.ScheduledEventId = Id(80UL)
  let user_id : @model.UserId = Id(90UL)
  client.list_guild_scheduled_events(guild_id, with_user_count=true) |> ignore
  client.list_guild_scheduled_events(guild_id) |> ignore
  try
    client.get_guild_scheduled_event(guild_id, event_id, with_user_count=false)
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake scheduled event response should not decode")
  }
  try client.get_guild_scheduled_event(guild_id, event_id) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake scheduled event response should not decode")
  }
  client.list_guild_scheduled_event_users(
    guild_id,
    event_id,
    limit=100,
    with_member=true,
    after=user_id,
  )
  |> ignore
  client.list_guild_scheduled_event_users(guild_id, event_id) |> ignore
  assert_eq(paths, [
    "/api/v10/guilds/70/scheduled-events?with_user_count=true", "/api/v10/guilds/70/scheduled-events",
    "/api/v10/guilds/70/scheduled-events/80?with_user_count=false", "/api/v10/guilds/70/scheduled-events/80",
    "/api/v10/guilds/70/scheduled-events/80/users?limit=100&with_member=true&after=90",
    "/api/v10/guilds/70/scheduled-events/80/users",
  ])
}

///|
async test "invite poll thread and archived-thread queries pin optional arms" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  perform.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let channel_id : @model.ChannelId = Id(100UL)
  let message_id : @model.MessageId = Id(110UL)
  let user_id : @model.UserId = Id(120UL)
  let event_id : @model.ScheduledEventId = Id(130UL)
  try
    client.get_invite(
      "real-code",
      with_counts=true,
      guild_scheduled_event_id=event_id,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake invite response should not decode")
  }
  try client.get_invite("real-code") catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake invite response should not decode")
  }
  try
    client.get_poll_answer_voters(
      channel_id,
      message_id,
      2,
      after=user_id,
      limit=100,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake poll response should not decode")
  }
  try client.get_poll_answer_voters(channel_id, message_id, 2) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake poll response should not decode")
  }
  client.list_thread_members(
    channel_id,
    with_member=true,
    after=user_id,
    limit=100,
  )
  |> ignore
  client.list_thread_members(channel_id) |> ignore
  try client.get_thread_member(channel_id, user_id, with_member=false) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake thread member response should not decode")
  }
  try
    client.list_public_archived_threads(
      channel_id,
      before=Timestamp("2026-07-16T00:00:00Z"),
      limit=50,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake archive response should not decode")
  }
  assert_eq(paths, [
    "/api/v10/invites/real-code?with_counts=true&guild_scheduled_event_id=130", "/api/v10/invites/real-code",
    "/api/v10/channels/100/polls/110/answers/2?after=120&limit=100", "/api/v10/channels/100/polls/110/answers/2",
    "/api/v10/channels/100/thread-members?with_member=true&after=120&limit=100",
    "/api/v10/channels/100/thread-members", "/api/v10/channels/100/thread-members/120?with_member=false",
    "/api/v10/channels/100/threads/archived/public?before=2026-07-16T00:00:00Z&limit=50",
  ])
}

///|
async test "new query validations reject invalid limits and cursor pairs before IO" {
  let client = Client("test-token")
  defer client.close()
  let guild_id : @model.GuildId = Id(1UL)
  let user_id : @model.UserId = Id(2UL)
  let entry_id : @model.AuditLogEntryId = Id(3UL)
  let channel_id : @model.ChannelId = Id(4UL)
  let message_id : @model.MessageId = Id(5UL)
  try
    client.get_guild_audit_log(guild_id, before=entry_id, after=entry_id)
  catch {
    Validation(message~) =>
      inspect(
        message,
        content="audit log pagination cannot use before and after together",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected audit cursor validation")
  }
  try client.get_guild_bans(guild_id, limit=1001) catch {
    Validation(message~) =>
      inspect(message, content="guild ban limit must be between 1 and 1000")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected ban limit validation")
  }
  try client.get_current_user_guilds(limit=201) catch {
    Validation(message~) =>
      inspect(
        message,
        content="current user guild limit must be between 1 and 200",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected current user guild limit validation")
  }
  try client.get_poll_answer_voters(channel_id, message_id, 1, limit=0) catch {
    Validation(message~) =>
      inspect(message, content="poll voter limit must be between 1 and 100")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected poll voter limit validation")
  }
  try
    client.list_guild_scheduled_event_users(
      guild_id,
      Id(6UL),
      before=user_id,
      after=user_id,
    )
  catch {
    Validation(message~) =>
      inspect(
        message,
        content="scheduled event user pagination cannot use before and after together",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected scheduled event cursor validation")
  }
}
