///|
fn paginator_message_page(ids : Array[Int]) -> Json raise {
  Json::array(
    ids.map(id => {
      @json.parse(
        "{\"id\":\"\{id}\",\"channel_id\":\"10\",\"author\":{\"id\":\"20\",\"username\":\"Nelly\",\"discriminator\":\"0\",\"global_name\":null,\"avatar\":null},\"content\":\"page \{id}\",\"timestamp\":\"2026-07-16T00:00:00Z\",\"edited_timestamp\":null,\"tts\":false,\"mention_everyone\":false,\"mentions\":[],\"mention_roles\":[],\"attachments\":[],\"embeds\":[],\"pinned\":false,\"type\":0}",
      )
    }),
  )
}

///|
async test "message paginator after uses maximum cursor from canned pages" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    calls.val += 1
    let body = if calls.val == 1 {
      paginator_message_page([101, 103])
    } else {
      Json::array([])
    }
    { status: 200, headers: Map([]), body, }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let after : @model.MessageId = Id(100UL)
  let paginator = client.paginate_messages(channel_id, after~, page_size=2)
  guard paginator.next_page() is Some(first) else {
    fail("expected first page")
  }
  assert_eq(first.map(message => message.id.value()), [101UL, 103UL])
  assert_true(paginator.next_page() is None)
  assert_eq(paths, [
    "/api/v10/channels/10/messages?limit=2&after=100", "/api/v10/channels/10/messages?limit=2&after=103",
  ])
}

///|
async test "message paginator before uses minimum cursor from canned pages" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    calls.val += 1
    let body = if calls.val == 1 {
      paginator_message_page([99, 98])
    } else {
      Json::array([])
    }
    { status: 200, headers: Map([]), body, }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let before : @model.MessageId = Id(100UL)
  let paginator = client.paginate_messages(channel_id, before~, page_size=2)
  guard paginator.next_page() is Some(first) else {
    fail("expected first page")
  }
  assert_eq(first.map(message => message.id.value()), [99UL, 98UL])
  assert_true(paginator.next_page() is None)
  assert_eq(paths, [
    "/api/v10/channels/10/messages?limit=2&before=100", "/api/v10/channels/10/messages?limit=2&before=98",
  ])
}

///|
async test "message paginator around performs one fixed-cursor page" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: paginator_message_page([100]), }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let around : @model.MessageId = Id(100UL)
  let paginator = client.paginate_messages(channel_id, around~, page_size=2)
  guard paginator.next_page() is Some(first) else {
    fail("expected first page")
  }
  assert_eq(first.map(message => message.id.value()), [100UL])
  assert_true(paginator.next_page() is None)
  assert_eq(paths, ["/api/v10/channels/10/messages?limit=2&around=100"])
}

///|
fn round2_user_json(id : Int) -> Json raise {
  @json.parse(
    "{\"id\":\"\{id}\",\"username\":\"user-\{id}\",\"discriminator\":\"0\",\"global_name\":null,\"avatar\":null}",
  )
}

///|
async test "guild member paginator skips absent users and advances by maximum id" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    calls.val += 1
    let body = if calls.val == 1 {
      Json::array([
        @json.parse("{\"roles\":[],\"joined_at\":null,\"flags\":0}"),
        @json.parse(
          "{\"user\":\{round2_user_json(22).stringify()},\"roles\":[],\"joined_at\":null,\"flags\":0}",
        ),
        @json.parse(
          "{\"user\":\{round2_user_json(21).stringify()},\"roles\":[],\"joined_at\":null,\"flags\":0}",
        ),
      ])
    } else {
      Json::array([])
    }
    { status: 200, headers: Map([]), body, }
  })
  let guild_id : @model.GuildId = Id(10UL)
  let paginator = client.paginate_guild_members(guild_id, page_size=3)
  guard paginator.next_page() is Some(first) else {
    fail("expected guild member page")
  }
  assert_eq(first.length(), 3)
  assert_true(paginator.next_page() is None)
  assert_eq(paths, [
    "/api/v10/guilds/10/members?limit=3", "/api/v10/guilds/10/members?limit=3&after=22",
  ])
}

///|
async test "guild ban paginator covers after and before cursor directions" {
  for use_after in [true, false] {
    let client = Client("test-token")
    defer client.close()
    let paths : Array[String] = []
    let calls = Ref(0)
    client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
      paths.push(path)
      calls.val += 1
      let body = if calls.val == 1 {
        Json::array([
          { "reason": "first", "user": round2_user_json(31) },
          { "reason": null, "user": round2_user_json(33) },
        ])
      } else {
        Json::array([])
      }
      { status: 200, headers: Map([]), body, }
    })
    let guild_id : @model.GuildId = Id(11UL)
    let cursor : @model.UserId = Id(30UL)
    let paginator = if use_after {
      client.paginate_guild_bans(guild_id, after=cursor, page_size=2)
    } else {
      client.paginate_guild_bans(guild_id, before=cursor, page_size=2)
    }
    guard paginator.next_page() is Some(first) else {
      fail("expected guild ban page")
    }
    assert_eq(first.map(ban => ban.user.id.value()), [31UL, 33UL])
    assert_true(paginator.next_page() is None)
    let direction = if use_after { "after" } else { "before" }
    let next_cursor = if use_after { 33 } else { 31 }
    assert_eq(paths, [
      "/api/v10/guilds/11/bans?limit=2&\{direction}=30",
      "/api/v10/guilds/11/bans?limit=2&\{direction}=\{next_cursor}",
    ])
  }
}

///|
async test "audit log paginator extracts entries and advances by minimum id" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    calls.val += 1
    let entries = if calls.val == 1 {
      [
        { "target_id": null, "user_id": null, "id": "42", "action_type": 10 },
        { "target_id": null, "user_id": null, "id": "41", "action_type": 11 },
      ]
    } else {
      []
    }
    let body : Json = {
      "audit_log_entries": entries,
      "users": [],
      "webhooks": [],
      "integrations": [],
      "application_commands": [],
      "auto_moderation_rules": [],
      "threads": [],
      "guild_scheduled_events": [],
    }
    { status: 200, headers: Map([]), body, }
  })
  let guild_id : @model.GuildId = Id(12UL)
  let paginator = client.paginate_guild_audit_log(guild_id, page_size=2)
  guard paginator.next_page() is Some(first) else {
    fail("expected audit log page")
  }
  assert_eq(first.map(entry => entry.id.value()), [42UL, 41UL])
  assert_true(paginator.next_page() is None)
  assert_eq(paths, [
    "/api/v10/guilds/12/audit-logs?limit=2", "/api/v10/guilds/12/audit-logs?before=41&limit=2",
  ])
}

///|
async test "scheduled users poll voters and current guild paginators advance" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let counts : Map[String, Int] = Map([])
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    let key = if path.contains("scheduled-events") {
      "scheduled"
    } else if path.contains("answers") {
      "poll"
    } else {
      "guilds"
    }
    let count = counts.get_or_default(key, 0) + 1
    counts[key] = count
    let body = match key {
      "scheduled" =>
        if count == 1 {
          Json::array([
            { "guild_scheduled_event_id": "14", "user": round2_user_json(51) },
            { "guild_scheduled_event_id": "14", "user": round2_user_json(52) },
          ])
        } else {
          Json::array([])
        }
      "poll" =>
        if count == 1 {
          { "users": [round2_user_json(61), round2_user_json(62)] }
        } else {
          { "users": [] }
        }
      _ =>
        if count == 1 {
          Json::array([
            {
              "id": "71",
              "name": "g71",
              "icon": null,
              "banner": null,
              "owner": false,
              "permissions": "8",
              "features": [],
            },
            {
              "id": "72",
              "name": "g72",
              "icon": null,
              "banner": null,
              "owner": true,
              "permissions": "8",
              "features": [],
            },
          ])
        } else {
          Json::array([])
        }
    }
    { status: 200, headers: Map([]), body, }
  })
  let guild_id : @model.GuildId = Id(13UL)
  let event_id : @model.ScheduledEventId = Id(14UL)
  let after : @model.UserId = Id(50UL)
  let scheduled = client.paginate_guild_scheduled_event_users(
    guild_id,
    event_id,
    with_member=true,
    after~,
    page_size=2,
  )
  assert_eq(scheduled.collect(max=10).map(item => item.user.id.value()), [
    51UL, 52UL,
  ])
  let channel_id : @model.ChannelId = Id(15UL)
  let message_id : @model.MessageId = Id(16UL)
  let poll = client.paginate_poll_answer_voters(
    channel_id,
    message_id,
    1,
    after~,
    page_size=2,
  )
  assert_eq(poll.collect(max=10).map(user => user.id.value()), [61UL, 62UL])
  let guild_after : @model.GuildId = Id(70UL)
  let guilds = client.paginate_current_user_guilds(
    after=guild_after,
    with_counts=true,
    page_size=2,
  )
  assert_eq(guilds.collect(max=10).map(guild => guild.id.value()), [71UL, 72UL])
  let before_user : @model.UserId = Id(55UL)
  let scheduled_before = client.paginate_guild_scheduled_event_users(
    guild_id,
    event_id,
    before=before_user,
    page_size=2,
  )
  assert_true(scheduled_before.next_page() is None)
  let before_guild : @model.GuildId = Id(75UL)
  let guilds_before = client.paginate_current_user_guilds(
    before=before_guild,
    page_size=2,
  )
  assert_true(guilds_before.next_page() is None)
  assert_eq(paths, [
    "/api/v10/guilds/13/scheduled-events/14/users?limit=2&with_member=true&after=50",
    "/api/v10/guilds/13/scheduled-events/14/users?limit=2&with_member=true&after=52",
    "/api/v10/channels/15/polls/16/answers/1?after=50&limit=2", "/api/v10/channels/15/polls/16/answers/1?after=62&limit=2",
    "/api/v10/users/@me/guilds?limit=2&after=70&with_counts=true", "/api/v10/users/@me/guilds?limit=2&after=72&with_counts=true",
    "/api/v10/guilds/13/scheduled-events/14/users?limit=2&before=55", "/api/v10/users/@me/guilds?limit=2&before=75",
  ])
}
