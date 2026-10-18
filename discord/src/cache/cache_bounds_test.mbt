///|
fn bound_event(name : String, fixture : String) -> @model.Event raise {
  @model.dispatch_event(name, @json.parse(fixture))
}

///|
fn bound_user_json(id : String) -> String {
  "{\"id\":\"\{id}\",\"username\":\"u\{id}\",\"discriminator\":\"0\",\"avatar\":null}"
}

///|
fn bound_message(
  id : String,
  channel_id~ : String,
  author_id~ : String,
  guild_id? : String,
) -> @model.Event raise {
  let guild = match guild_id {
    Some(guild_id) => "\"guild_id\":\"\{guild_id}\","
    None => ""
  }
  bound_event(
    "MESSAGE_CREATE",
    "{\"id\":\"\{id}\",\"channel_id\":\"\{channel_id}\",\{guild}\"author\":\{bound_user_json(author_id)},\"content\":\"hi\",\"timestamp\":\"2025-06-01T10:00:00Z\",\"edited_timestamp\":null,\"tts\":false,\"mention_everyone\":false,\"mentions\":[],\"mention_roles\":[],\"attachments\":[],\"embeds\":[],\"pinned\":false,\"type\":0}",
  )
}

///|
fn bound_thread_json(
  id : String,
  typ~ : Int32 = 11,
  archived~ : Bool = false,
) -> String {
  "{\"id\":\"\{id}\",\"type\":\{typ},\"guild_id\":\"100\",\"parent_id\":\"400\",\"name\":\"t\",\"thread_metadata\":{\"archived\":\{archived},\"auto_archive_duration\":60,\"archive_timestamp\":\"2025-06-01T10:00:00Z\",\"locked\":false}}"
}

///|
fn bound_ready(user_id : String) -> @model.Event raise {
  bound_event(
    "READY",
    "{\"v\":10,\"user\":\{bound_user_json(user_id)},\"guilds\":[],\"session_id\":\"s\",\"resume_gateway_url\":\"wss://resume.example\",\"application\":{\"id\":\"42\"}}",
  )
}

///|
fn bound_guild_create(
  members~ : Array[String],
  threads~ : Array[String],
) -> @model.Event raise {
  let members = members
    .map(id => {
      "{\"user\":\{bound_user_json(id)},\"roles\":[],\"joined_at\":\"2025-06-01T10:00:00Z\"}"
    })
    .join(",")
  let threads = threads.map(id => bound_thread_json(id)).join(",")
  bound_event(
    "GUILD_CREATE",
    "{\"id\":\"100\",\"name\":\"g\",\"icon\":null,\"splash\":null,\"discovery_splash\":null,\"owner_id\":\"200\",\"afk_channel_id\":null,\"afk_timeout\":300,\"verification_level\":1,\"default_message_notifications\":1,\"explicit_content_filter\":2,\"roles\":[],\"emojis\":[],\"features\":[],\"mfa_level\":0,\"application_id\":null,\"system_channel_id\":null,\"system_channel_flags\":0,\"rules_channel_id\":null,\"vanity_url_code\":null,\"description\":null,\"banner\":null,\"premium_tier\":0,\"preferred_locale\":\"en-US\",\"public_updates_channel_id\":null,\"safety_alerts_channel_id\":null,\"joined_at\":\"2025-06-01T10:00:00Z\",\"large\":false,\"unavailable\":false,\"member_count\":1,\"voice_states\":[],\"members\":[\{members}],\"channels\":[{\"id\":\"400\",\"type\":0,\"name\":\"general\"}],\"threads\":[\{threads}],\"presences\":[],\"stage_instances\":[],\"guild_scheduled_events\":[],\"soundboard_sounds\":[]}",
  )
}

///|
test "users seen only in passing stay within the default bound" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::default())
  for i in 0..<1000 {
    let user_id = (20000 + i).to_string()
    cache.update(
      bound_event(
        "GUILD_BAN_ADD",
        "{\"guild_id\":\"100\",\"user\":\{bound_user_json(user_id)}}",
      ),
    )
  }
  assert_eq(cache.users().length(), 128)
  assert_true(cache.user(@model.Id::parse("20999")) is Some(_))
  assert_true(cache.user(@model.Id::parse("20000")) is None)
}

///|
test "members who join and leave keep only their recent sightings" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::default())
  for i in 0..<1000 {
    let user_id = (20000 + i).to_string()
    cache.update(
      bound_event(
        "GUILD_MEMBER_ADD",
        "{\"guild_id\":\"100\",\"user\":\{bound_user_json(user_id)},\"roles\":[],\"joined_at\":\"2025-06-01T10:00:00Z\"}",
      ),
    )
    cache.update(
      bound_event(
        "GUILD_MEMBER_REMOVE",
        "{\"guild_id\":\"100\",\"user\":\{bound_user_json(user_id)}}",
      ),
    )
  }
  assert_eq(cache.users().length(), 128)
  // The departed member's last view is still served while it is recent.
  assert_true(cache.user(@model.Id::parse("20999")) is Some(_))
}

///|
test "users leave with the guild whose members held them" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::default())
  cache.update(bound_guild_create(members=["201", "202"], threads=[]))
  assert_eq(cache.users().length(), 2)
  cache.update(
    bound_event("GUILD_DELETE", "{\"id\":\"100\",\"unavailable\":false}"),
  )
  assert_eq(cache.users().length(), 0)
}

///|
test "DM message buckets stay within the default bound" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
  )
  for i in 0..<1000 {
    cache.update(
      bound_message(
        (90000 + i).to_string(),
        channel_id=(10000 + i).to_string(),
        author_id=(20000 + i).to_string(),
      ),
    )
  }
  let retained = []
  for i in 0..<1000 {
    if cache.messages(@model.Id::parse((10000 + i).to_string())).length() > 0 {
      retained.push(i)
    }
  }
  assert_eq(retained.length(), 128)
  // The least recently used DMs went first, and their authors with them.
  assert_eq(retained[0], 1000 - 128)
  assert_eq(cache.users().length(), 128)
}

///|
test "archived threads leave the cache with their messages" {
  for
    resources in [
      @cache.CacheResources::all(),
      @cache.CacheResources(channels=false, messages=true),
    ] {
    let cache = @cache.InMemoryCache(resources~)
    let thread_id : @model.ChannelId = @model.Id::parse("401")
    cache.update(bound_event("THREAD_CREATE", bound_thread_json("401")))
    cache.update(
      bound_message("900", channel_id="401", author_id="202", guild_id="100"),
    )
    assert_eq(cache.messages(thread_id).length(), 1)
    cache.update(
      bound_event("THREAD_UPDATE", bound_thread_json("401", archived=true)),
    )
    assert_true(cache.channel(thread_id) is None)
    assert_eq(cache.messages(thread_id).length(), 0)
    assert_true(cache.user(@model.Id::parse("202")) is None)
  }
}

///|
test "the bot removed from a private thread forgets it" {
  for
    resources in [
      @cache.CacheResources::all(),
      @cache.CacheResources(channels=false, messages=true),
    ] {
    let cache = @cache.InMemoryCache(resources~)
    cache.update(bound_ready("999"))
    for thread in [("401", 12), ("402", 11)] {
      let (id, typ) = thread
      cache.update(bound_event("THREAD_CREATE", bound_thread_json(id, typ~)))
      cache.update(
        bound_message("9\{id}", channel_id=id, author_id="202", guild_id="100"),
      )
      cache.update(
        bound_event(
          "THREAD_MEMBERS_UPDATE",
          "{\"id\":\"\{id}\",\"guild_id\":\"100\",\"member_count\":0,\"removed_member_ids\":[\"999\"]}",
        ),
      )
    }
    // The private thread is gone; the bot can still read the public one.
    assert_eq(cache.messages(@model.Id::parse("401")).length(), 0)
    assert_true(cache.channel(@model.Id::parse("401")) is None)
    assert_eq(cache.messages(@model.Id::parse("402")).length(), 1)
  }
}

///|
test "a thread list sync clears stale thread messages without retained channels" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(channels=false, messages=true),
  )
  let thread_id : @model.ChannelId = @model.Id::parse("401")
  cache.update(bound_event("THREAD_CREATE", bound_thread_json("401")))
  cache.update(
    bound_message("900", channel_id="401", author_id="202", guild_id="100"),
  )
  cache.update(
    bound_event(
      "THREAD_LIST_SYNC", "{\"guild_id\":\"100\",\"channel_ids\":[\"400\"],\"threads\":[],\"members\":[]}",
    ),
  )
  assert_eq(cache.messages(thread_id).length(), 0)
}

///|
test "a fresh guild create forgets the threads it no longer lists" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::all())
  cache.update(bound_guild_create(members=[], threads=["401", "402"]))
  cache.update(
    bound_message("900", channel_id="401", author_id="202", guild_id="100"),
  )
  cache.update(
    bound_event("GUILD_DELETE", "{\"id\":\"100\",\"unavailable\":true}"),
  )
  // Thread 401 was deleted during the outage.
  cache.update(bound_guild_create(members=[], threads=["402"]))
  assert_true(cache.channel(@model.Id::parse("401")) is None)
  assert_eq(cache.messages(@model.Id::parse("401")).length(), 0)
  assert_true(cache.channel(@model.Id::parse("402")) is Some(_))
}

///|
fn dm_retained(
  cache : @cache.InMemoryCache,
  ids : Array[String],
) -> Array[String] raise {
  ids.filter(id => cache.messages(@model.Id::parse(id)).length() > 0)
}

///|
test "the DM limit is configurable and evicts the least recently written" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
    limits=@cache.CacheLimits(dm_channels=@cache.CacheLimit(max_entries=2)),
  )
  cache.update(bound_message("1", channel_id="3000", author_id="1"))
  cache.update(bound_message("2", channel_id="3001", author_id="2"))
  // Writing 3000 again makes 3001 the least recently written.
  cache.update(bound_message("3", channel_id="3000", author_id="1"))
  cache.update(bound_message("4", channel_id="3002", author_id="3"))
  assert_eq(dm_retained(cache, ["3000", "3001", "3002"]), ["3000", "3002"])
  assert_true(cache.user(@model.Id::parse("2")) is None)
  // Guild channels do not count against it.
  cache.update(
    bound_message("5", channel_id="400", author_id="4", guild_id="100"),
  )
  assert_eq(dm_retained(cache, ["3000", "3002", "400"]), ["3000", "3002", "400"])
}

///|
test "DM channel entries share the DM limit with their messages" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::all(),
    limits=@cache.CacheLimits(dm_channels=@cache.CacheLimit(max_entries=1)),
  )
  cache.update(
    bound_event(
      "CHANNEL_CREATE",
      "{\"id\":\"3000\",\"type\":1,\"recipients\":[\{bound_user_json("1")}]}",
    ),
  )
  cache.update(bound_message("1", channel_id="3000", author_id="1"))
  assert_true(cache.channel(@model.Id::parse("3000")) is Some(_))
  cache.update(bound_message("2", channel_id="3001", author_id="2"))
  assert_true(cache.channel(@model.Id::parse("3000")) is None)
  assert_eq(dm_retained(cache, ["3000", "3001"]), ["3001"])
}

///|
test "lifting or zeroing the DM limit" {
  let unbounded = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
    limits=@cache.CacheLimits(dm_channels=@cache.CacheLimit()),
  )
  let none = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
    limits=@cache.CacheLimits(dm_channels=@cache.CacheLimit(max_entries=0)),
  )
  let ids = [ for i in 0..<200 => (10000 + i).to_string() ]
  for id in ids {
    unbounded.update(bound_message(id, channel_id=id, author_id="1"))
    none.update(bound_message(id, channel_id=id, author_id="1"))
  }
  assert_eq(dm_retained(unbounded, ids).length(), 200)
  assert_eq(dm_retained(none, ids).length(), 0)
  // The author of messages nobody keeps is still a recent sighting.
  assert_true(none.user(@model.Id::parse("1")) is Some(_))
}

///|
test "an expired DM channel releases its messages" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
    limits=@cache.CacheLimits(dm_channels=@cache.CacheLimit(ttl_ms=1000L)),
    now=() => now.val,
  )
  cache.update(bound_message("1", channel_id="3000", author_id="1"))
  now.val = 1000L
  assert_eq(dm_retained(cache, ["3000"]), [])
  assert_true(cache.user(@model.Id::parse("1")) is None)
}

///|
test "the recent-users limit is configurable" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=@cache.CacheLimits(recent_users=@cache.CacheLimit(max_entries=2)),
  )
  for id in ["1", "2", "3"] {
    cache.update(
      bound_event(
        "INTERACTION_CREATE",
        "{\"id\":\"5\",\"application_id\":\"42\",\"type\":2,\"token\":\"t\",\"version\":1,\"user\":\{bound_user_json(id)},\"data\":{\"id\":\"6\",\"name\":\"x\",\"type\":1}}",
      ),
    )
  }
  assert_eq(cache.users().map(user => user.id.to_string()), ["2", "3"])
}

///|
test "the current user is held until another replaces it" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=@cache.CacheLimits(recent_users=@cache.CacheLimit(max_entries=1)),
  )
  cache.update(bound_ready("999"))
  for id in ["1", "2", "3"] {
    cache.update(
      bound_event(
        "GUILD_BAN_ADD",
        "{\"guild_id\":\"100\",\"user\":\{bound_user_json(id)}}",
      ),
    )
  }
  assert_true(cache.user(@model.Id::parse("999")) is Some(_))
  cache.update(bound_event("USER_UPDATE", bound_user_json("998")))
  assert_true(cache.user(@model.Id::parse("999")) is None)
  assert_eq(cache.users().map(user => user.id.to_string()), ["998", "3"])
}

///|
test "a member the cache does not keep is a recent sighting" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(members=false),
  )
  cache.update(bound_guild_create(members=["201"], threads=[]))
  cache.update(
    bound_event(
      "GUILD_MEMBER_UPDATE",
      "{\"guild_id\":\"100\",\"roles\":[],\"user\":\{bound_user_json("202")},\"avatar\":null,\"joined_at\":\"2025-06-01T10:00:00Z\"}",
    ),
  )
  assert_true(cache.members(@model.Id::parse("100")).is_empty())
  assert_eq(cache.users().map(user => user.id.to_string()), ["201", "202"])
}

///|
test "an unkept message update is a recent sighting of its author" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
  )
  cache.update(
    bound_event(
      "MESSAGE_UPDATE",
      "{\"id\":\"1\",\"channel_id\":\"400\",\"guild_id\":\"100\",\"author\":\{bound_user_json("7")},\"content\":\"e\",\"timestamp\":\"2025-06-01T10:00:00Z\",\"edited_timestamp\":null,\"tts\":false,\"mention_everyone\":false,\"mentions\":[],\"mention_roles\":[],\"attachments\":[],\"embeds\":[],\"pinned\":false,\"type\":0}",
    ),
  )
  assert_true(
    cache.message(@model.Id::parse("400"), @model.Id::parse("1")) is None,
  )
  assert_true(cache.user(@model.Id::parse("7")) is Some(_))
}

///|
test "a new session forgets the guilds the bot left while disconnected" {
  // Guild 100 is on shard 0 of 2 ((100 >> 22) % 2 == 0).
  for
    case in [
      ("unsharded", "", 0),
      ("its shard", ",\"shard\":[0,2]", 0),
      ("another shard", ",\"shard\":[1,2]", 2),
    ] {
    let (name, shard, kept) = case
    let cache = @cache.InMemoryCache(
      resources=@cache.CacheResources(messages=true),
    )
    cache.update(bound_guild_create(members=["201", "202"], threads=["401"]))
    cache.update(
      bound_message("900", channel_id="401", author_id="203", guild_id="100"),
    )
    cache.update(
      bound_event(
        "READY",
        "{\"v\":10,\"user\":\{bound_user_json("999")},\"guilds\":[]\{shard},\"session_id\":\"s\",\"resume_gateway_url\":\"wss://resume.example\",\"application\":{\"id\":\"42\"}}",
      ),
    )
    let guild_id : @model.GuildId = @model.Id::parse("100")
    assert_eq((name, cache.members(guild_id).length()), (name, kept))
    assert_eq((name, cache.guild(guild_id) is Some(_)), (name, kept > 0))
    assert_eq(
      (name, cache.messages(@model.Id::parse("401")).length()),
      (name, kept / 2),
    )
  }
}

///|
test "users leave when their last holder expires, without reading its bucket" {
  let cases : Array[(String, @cache.CacheLimits, @model.Event)] = [
    (
      "member",
      @cache.CacheLimits(members=@cache.CacheLimit(ttl_ms=1000L)),
      bound_event(
        "GUILD_MEMBER_ADD",
        "{\"guild_id\":\"100\",\"user\":\{bound_user_json("201")},\"roles\":[],\"joined_at\":\"2025-06-01T10:00:00Z\"}",
      ),
    ),
    (
      "message author",
      @cache.CacheLimits(messages=@cache.CacheLimit(ttl_ms=1000L)),
      bound_message("900", channel_id="400", author_id="201", guild_id="100"),
    ),
  ]
  for case in cases {
    let (name, limits, event) = case
    let now = Ref(0L)
    let cache = @cache.InMemoryCache(
      resources=@cache.CacheResources(messages=true),
      limits~,
      now=() => now.val,
    )
    cache.update(event)
    assert_true(cache.user(@model.Id::parse("201")) is Some(_), msg=name)
    now.val = 1000L
    assert_eq((name, cache.user(@model.Id::parse("201")) is None), (name, true))
    assert_eq((name, cache.users().length()), (name, 0))
  }
}
