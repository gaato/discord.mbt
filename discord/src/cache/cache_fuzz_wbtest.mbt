///|
/// Holder counts recomputed from scratch: one per member entry, one per
/// cached message (its author), and one for the current user.
fn recount_holders(cache : InMemoryCache) -> Map[@model.UserId, Int32] {
  let counts : Map[@model.UserId, Int32] = Map([])
  guard cache.resources_.users_ else { return counts }
  let add = (user_id : @model.UserId) => {
    counts[user_id] = counts.get(user_id).unwrap_or(0) + 1
  }
  for _, bucket in cache.members_.buckets_ {
    for _, timed in bucket.entries.entries_ {
      if timed.value.user is Some(user) {
        add(user.id)
      }
    }
  }
  for _, bucket in cache.messages_.buckets_ {
    for _, timed in bucket.entries.entries_ {
      add(timed.value.author.id)
    }
  }
  if cache.current_user_ is Some(user_id) {
    add(user_id)
  }
  counts
}

///|
fn sorted_counts(counts : Map[@model.UserId, Int32]) -> Array[String] {
  let rendered = [ for user_id, count in counts => "\{user_id}:\{count}" ]
  rendered.sort()
  rendered
}

///|
fn[O, K, V] has_empty_bucket(buckets : Buckets[O, K, V]) -> Bool {
  buckets.buckets_.values().any(bucket => bucket.entries.entries_.is_empty())
}

///|
fn[K, V] holds_expired(map : TimedMap[K, V]) -> Bool {
  map.entries_.values().any(timed => map.is_expired(timed))
}

///|
fn[O, K, V] buckets_hold_expired(buckets : Buckets[O, K, V]) -> Bool {
  buckets.buckets_.values().any(bucket => holds_expired(bucket.entries))
}

///|
fn within(length : Int32, limit : CacheLimit) -> Bool {
  match limit.max_entries_ {
    Some(max_entries) => length <= max_entries
    None => true
  }
}

///|
/// Every way the cache's bookkeeping can disagree with its contents, or a
/// structure can outgrow its bound. Empty when all hold.
fn cache_violations(
  cache : InMemoryCache,
  limits : CacheLimits,
) -> Array[String] {
  let violations = []
  let users = cache.users_
  let expected = sorted_counts(recount_holders(cache))
  let actual = sorted_counts(users.counts_)
  if expected != actual {
    violations.push(
      "holder counts \{actual.join(" ")}, recount \{expected.join(" ")}",
    )
  }
  for user_id, _ in users.held_.entries_ {
    if !users.counts_.contains(user_id) {
      violations.push("user \{user_id} held without a holder")
    }
    if users.recent_.entries_.contains(user_id) {
      violations.push("user \{user_id} both held and recent")
    }
  }
  if !within(users.recent_.entries_.length(), limits.recent_users_) {
    violations.push("recent users over their limit")
  }
  if !within(cache.dm_channels_.entries_.length(), limits.dm_channels_) {
    violations.push("DM channels over their limit")
  }
  for channel_id, bucket in cache.messages_.buckets_ {
    if bucket.guild_id is None &&
      !cache.dm_channels_.entries_.contains(channel_id) {
      violations.push("DM messages of \{channel_id} untracked")
    }
  }
  for channel_id, timed in cache.channels_.entries_ {
    let cached = timed.value
    match cached.guild_id {
      None =>
        if !cache.dm_channels_.entries_.contains(channel_id) {
          violations.push("DM channel \{channel_id} untracked")
        }
      Some(_) =>
        if is_thread(cached.channel) && !cache.threads_.contains(channel_id) {
          violations.push("thread \{channel_id} untracked")
        }
    }
    if !keeps_channel(cached.channel) {
      violations.push("archived thread \{channel_id} retained")
    }
  }
  if has_empty_bucket(cache.roles_) ||
    has_empty_bucket(cache.members_) ||
    has_empty_bucket(cache.voice_states_) ||
    has_empty_bucket(cache.presences_) ||
    has_empty_bucket(cache.messages_) {
    violations.push("an empty bucket")
  }
  // Every read and update expires everything due first, so nothing expired
  // is left to hold a user or a DM slot.
  if holds_expired(cache.guilds_) ||
    holds_expired(cache.channels_) ||
    holds_expired(cache.dm_channels_) ||
    holds_expired(users.held_) ||
    holds_expired(users.recent_) ||
    buckets_hold_expired(cache.roles_) ||
    buckets_hold_expired(cache.members_) ||
    buckets_hold_expired(cache.voice_states_) ||
    buckets_hold_expired(cache.presences_) ||
    buckets_hold_expired(cache.messages_) {
    violations.push("an expired entry retained")
  }
  for channel_id, _ in cache.dm_channels_.entries_ {
    if !cache.messages_.buckets_.contains(channel_id) &&
      !cache.channels_.entries_.contains(channel_id) {
      violations.push("DM slot \{channel_id} holds nothing")
    }
  }
  violations
}

///|
/// A small deterministic generator (xorshift32), so a failure names a
/// reproducible seed.
priv struct FuzzRng {
  mut state : UInt32
}

///|
fn FuzzRng::below(self : FuzzRng, n : Int32) -> Int32 {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  (x % n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn[T] FuzzRng::pick(self : FuzzRng, values : Array[T]) -> T {
  values[self.below(values.length())]
}

///|
fn FuzzRng::subset(self : FuzzRng, values : Array[String]) -> Array[String] {
  values.filter(_ => self.below(2) == 0)
}

///|
fn fuzz_user(id : String) -> String {
  "{\"id\":\"\{id}\",\"username\":\"u\{id}\",\"discriminator\":\"0\",\"avatar\":null}"
}

///|
fn fuzz_member(user_id : String) -> String {
  "{\"user\":\{fuzz_user(user_id)},\"roles\":[],\"joined_at\":\"2025-06-01T10:00:00Z\"}"
}

///|
fn fuzz_thread(
  id : String,
  guild_id : String,
  parent_id : String,
  typ : Int32,
  archived : Bool,
) -> String {
  "{\"id\":\"\{id}\",\"type\":\{typ},\"guild_id\":\"\{guild_id}\",\"parent_id\":\"\{parent_id}\",\"name\":\"t\",\"thread_metadata\":{\"archived\":\{archived},\"auto_archive_duration\":60,\"archive_timestamp\":\"2025-06-01T10:00:00Z\",\"locked\":false}}"
}

///|
let fuzz_guilds : Array[String] = ["100", "101"]

///|
let fuzz_users : Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8"]

///|
fn fuzz_channels(guild_id : String) -> Array[String] {
  ["\{guild_id}0", "\{guild_id}1"]
}

///|
fn fuzz_threads(guild_id : String) -> Array[String] {
  ["\{guild_id}5", "\{guild_id}6", "\{guild_id}7"]
}

///|
let fuzz_dms : Array[String] = ["3000", "3001", "3002", "3003"]

///|
fn fuzz_thread_of(rng : FuzzRng, guild_id : String, id : String) -> String {
  fuzz_thread(
    id,
    guild_id,
    rng.pick(fuzz_channels(guild_id)),
    rng.pick([11, 12]),
    false,
  )
}

///|
/// One random gateway event over a small id space, so events collide on the
/// same guilds, channels, threads, and users.
fn fuzz_event(rng : FuzzRng, message_id : Ref[Int32]) -> (String, String) {
  let guild_id = rng.pick(fuzz_guilds)
  let user_id = rng.pick(fuzz_users)
  match rng.below(22) {
    0 => {
      let members = rng.subset(fuzz_users).map(fuzz_member).join(",")
      let channels = rng
        .subset(fuzz_channels(guild_id))
        .map(id => "{\"id\":\"\{id}\",\"type\":0,\"name\":\"c\"}")
        .join(",")
      let threads = rng
        .subset(fuzz_threads(guild_id))
        .map(id => fuzz_thread_of(rng, guild_id, id))
        .join(",")
      let voice_states = if rng.below(2) == 0 {
        "{\"channel_id\":\"\{guild_id}0\",\"user_id\":\"\{user_id}\",\"session_id\":\"s\",\"deaf\":false,\"mute\":false,\"self_deaf\":false,\"self_mute\":false,\"suppress\":false,\"request_to_speak_timestamp\":null}"
      } else {
        ""
      }
      (
        "GUILD_CREATE",
        "{\"id\":\"\{guild_id}\",\"name\":\"g\",\"icon\":null,\"splash\":null,\"discovery_splash\":null,\"owner_id\":\"1\",\"afk_channel_id\":null,\"afk_timeout\":300,\"verification_level\":1,\"default_message_notifications\":1,\"explicit_content_filter\":2,\"roles\":[{\"id\":\"\{guild_id}\",\"name\":\"@everyone\",\"color\":0,\"hoist\":false,\"position\":0,\"permissions\":\"1024\",\"managed\":false,\"mentionable\":false}],\"emojis\":[],\"features\":[],\"mfa_level\":0,\"application_id\":null,\"system_channel_id\":null,\"system_channel_flags\":0,\"rules_channel_id\":null,\"vanity_url_code\":null,\"description\":null,\"banner\":null,\"premium_tier\":0,\"preferred_locale\":\"en-US\",\"public_updates_channel_id\":null,\"safety_alerts_channel_id\":null,\"joined_at\":\"2025-06-01T10:00:00Z\",\"large\":false,\"unavailable\":false,\"member_count\":1,\"voice_states\":[\{voice_states}],\"members\":[\{members}],\"channels\":[\{channels}],\"threads\":[\{threads}],\"presences\":[{\"user\":{\"id\":\"\{user_id}\"},\"status\":\"online\"}],\"stage_instances\":[],\"guild_scheduled_events\":[],\"soundboard_sounds\":[]}",
      )
    }
    1 =>
      (
        "GUILD_DELETE",
        "{\"id\":\"\{guild_id}\",\"unavailable\":\{rng.below(2) == 0}}",
      )
    2 =>
      (
        "GUILD_MEMBER_ADD",
        "{\"guild_id\":\"\{guild_id}\",\"user\":\{fuzz_user(user_id)},\"roles\":[],\"joined_at\":\"2025-06-01T10:00:00Z\"}",
      )
    3 =>
      (
        "GUILD_MEMBER_REMOVE",
        "{\"guild_id\":\"\{guild_id}\",\"user\":\{fuzz_user(user_id)}}",
      )
    4 =>
      (
        "GUILD_MEMBER_UPDATE",
        "{\"guild_id\":\"\{guild_id}\",\"roles\":[],\"user\":\{fuzz_user(user_id)},\"avatar\":null,\"joined_at\":\"2025-06-01T10:00:00Z\"}",
      )
    5 => {
      let members = rng.subset(fuzz_users).map(fuzz_member).join(",")
      (
        "GUILD_MEMBERS_CHUNK",
        "{\"guild_id\":\"\{guild_id}\",\"members\":[\{members}],\"chunk_index\":0,\"chunk_count\":1}",
      )
    }
    6 =>
      (
        rng.pick(["GUILD_BAN_ADD", "GUILD_BAN_REMOVE"]),
        "{\"guild_id\":\"\{guild_id}\",\"user\":\{fuzz_user(user_id)}}",
      )
    7 | 8 => {
      message_id.val += 1
      let (channel_id, guild) = match rng.below(3) {
        0 =>
          (rng.pick(fuzz_channels(guild_id)), "\"guild_id\":\"\{guild_id}\",")
        1 => (rng.pick(fuzz_threads(guild_id)), "\"guild_id\":\"\{guild_id}\",")
        _ => (rng.pick(fuzz_dms), "")
      }
      let id = if rng.below(4) == 0 && message_id.val > 1 {
        (9000 + rng.below(message_id.val)).to_string()
      } else {
        (9000 + message_id.val).to_string()
      }
      (
        rng.pick(["MESSAGE_CREATE", "MESSAGE_CREATE", "MESSAGE_UPDATE"]),
        "{\"id\":\"\{id}\",\"channel_id\":\"\{channel_id}\",\{guild}\"author\":\{fuzz_user(user_id)},\"content\":\"m\",\"timestamp\":\"2025-06-01T10:00:00Z\",\"edited_timestamp\":null,\"tts\":false,\"mention_everyone\":false,\"mentions\":[],\"mention_roles\":[],\"attachments\":[],\"embeds\":[],\"pinned\":false,\"type\":0}",
      )
    }
    9 => {
      let channel_id = rng.pick(
        [..fuzz_channels(guild_id), ..fuzz_threads(guild_id), ..fuzz_dms],
      )
      let id = (9000 + rng.below(message_id.val + 1)).to_string()
      if rng.below(2) == 0 {
        (
          "MESSAGE_DELETE",
          "{\"id\":\"\{id}\",\"channel_id\":\"\{channel_id}\"}",
        )
      } else {
        (
          "MESSAGE_DELETE_BULK",
          "{\"ids\":[\"\{id}\",\"\{9000 + rng.below(message_id.val + 1)}\"],\"channel_id\":\"\{channel_id}\"}",
        )
      }
    }
    10 =>
      if rng.below(2) == 0 {
        (
          "CHANNEL_CREATE",
          "{\"id\":\"\{rng.pick(fuzz_channels(guild_id))}\",\"type\":0,\"guild_id\":\"\{guild_id}\",\"name\":\"c\"}",
        )
      } else {
        (
          "CHANNEL_CREATE",
          "{\"id\":\"\{rng.pick(fuzz_dms)}\",\"type\":1,\"recipients\":[\{fuzz_user(user_id)}]}",
        )
      }
    11 => {
      let channel_id = rng.pick([..fuzz_channels(guild_id), ..fuzz_dms])
      ("CHANNEL_DELETE", "{\"id\":\"\{channel_id}\",\"type\":0}")
    }
    12 =>
      (
        "THREAD_CREATE",
        fuzz_thread_of(rng, guild_id, rng.pick(fuzz_threads(guild_id))),
      )
    13 =>
      (
        "THREAD_UPDATE",
        fuzz_thread(
          rng.pick(fuzz_threads(guild_id)),
          guild_id,
          rng.pick(fuzz_channels(guild_id)),
          rng.pick([11, 12]),
          rng.below(2) == 0,
        ),
      )
    14 => {
      let id = rng.pick(fuzz_threads(guild_id))
      (
        "THREAD_DELETE",
        "{\"id\":\"\{id}\",\"guild_id\":\"\{guild_id}\",\"parent_id\":\"\{guild_id}0\",\"type\":11}",
      )
    }
    15 => {
      let channel_ids = if rng.below(2) == 0 {
        ""
      } else {
        let ids = rng
          .subset(fuzz_channels(guild_id))
          .map(id => "\"\{id}\"")
          .join(",")
        "\"channel_ids\":[\{ids}],"
      }
      let threads = rng
        .subset(fuzz_threads(guild_id))
        .map(id => fuzz_thread_of(rng, guild_id, id))
        .join(",")
      (
        "THREAD_LIST_SYNC",
        "{\"guild_id\":\"\{guild_id}\",\{channel_ids}\"threads\":[\{threads}],\"members\":[]}",
      )
    }
    16 => {
      let removed = rng.pick(["1", "8", user_id])
      (
        "THREAD_MEMBERS_UPDATE",
        "{\"id\":\"\{rng.pick(fuzz_threads(guild_id))}\",\"guild_id\":\"\{guild_id}\",\"member_count\":1,\"removed_member_ids\":[\"\{removed}\"]}",
      )
    }
    17 => {
      let guilds = rng
        .subset(fuzz_guilds)
        .map(id => "{\"id\":\"\{id}\",\"unavailable\":true}")
        .join(",")
      (
        "READY",
        "{\"v\":10,\"user\":\{fuzz_user(rng.pick(["1", "8"]))},\"guilds\":[\{guilds}],\"session_id\":\"s\",\"resume_gateway_url\":\"wss://resume.example\",\"application\":{\"id\":\"42\"}}",
      )
    }
    18 => ("USER_UPDATE", fuzz_user(rng.pick(["1", "8"])))
    19 => {
      let channel = if rng.below(3) == 0 { "null" } else { "\"\{guild_id}0\"" }
      (
        "VOICE_STATE_UPDATE",
        "{\"guild_id\":\"\{guild_id}\",\"channel_id\":\{channel},\"user_id\":\"\{user_id}\",\"session_id\":\"s\",\"deaf\":false,\"mute\":false,\"self_deaf\":false,\"self_mute\":false,\"suppress\":false,\"request_to_speak_timestamp\":null,\"member\":\{fuzz_member(user_id)}}",
      )
    }
    20 =>
      (
        "INTERACTION_CREATE",
        "{\"id\":\"5\",\"application_id\":\"42\",\"type\":2,\"token\":\"t\",\"version\":1,\"user\":\{fuzz_user(user_id)},\"data\":{\"id\":\"6\",\"name\":\"x\",\"type\":1}}",
      )
    _ =>
      (
        "PRESENCE_UPDATE",
        "{\"guild_id\":\"\{guild_id}\",\"user\":{\"id\":\"\{user_id}\"},\"status\":\"idle\"}",
      )
  }
}

///|
fn fuzz_configurations() -> Array[(String, CacheResources, CacheLimits)] {
  let small = CacheLimits(
    dm_channels=CacheLimit(max_entries=2),
    recent_users=CacheLimit(max_entries=3),
    members=CacheLimit(max_entries=3),
    messages=CacheLimit(max_entries=2),
  )
  [
    ("all, small limits", CacheResources::all(), small),
    (
      "holder TTLs only",
      CacheResources::all(),
      CacheLimits(
        roles=CacheLimit(ttl_ms=25L),
        members=CacheLimit(ttl_ms=30L),
        voice_states=CacheLimit(ttl_ms=20L),
        presences=CacheLimit(ttl_ms=20L),
        messages=CacheLimit(ttl_ms=20L),
      ),
    ),
    (
      "all, owner limits and TTLs",
      CacheResources::all(),
      CacheLimits(
        guilds=CacheLimit(max_entries=1, ttl_ms=60L),
        channels=CacheLimit(max_entries=3, ttl_ms=40L),
        dm_channels=CacheLimit(max_entries=2, ttl_ms=35L),
        users=CacheLimit(max_entries=3, ttl_ms=25L),
        recent_users=CacheLimit(max_entries=2, ttl_ms=15L),
        members=CacheLimit(max_entries=2, ttl_ms=30L),
        voice_states=CacheLimit(ttl_ms=20L),
        presences=CacheLimit(max_entries=2),
        messages=CacheLimit(max_entries=2, ttl_ms=20L),
      ),
    ),
    (
      "messages without channels",
      CacheResources(channels=false, presences=true, messages=true),
      small,
    ),
    (
      "zero limits",
      CacheResources::all(),
      CacheLimits(
        dm_channels=CacheLimit(max_entries=0),
        recent_users=CacheLimit(max_entries=0),
        members=CacheLimit(max_entries=0),
        users=CacheLimit(max_entries=0),
      ),
    ),
    ("defaults", CacheResources::all(), CacheLimits()),
    (
      "no members, no users",
      CacheResources(members=false, users=false, messages=true),
      small,
    ),
  ]
}

///|
test "random event sequences keep holder counts exact and every structure bounded" {
  for configuration in fuzz_configurations() {
    let (name, resources, limits) = configuration
    for seed in 1U..<=12U {
      let rng = { state: seed * 2654435761U, }
      let now = Ref(0L)
      let cache = InMemoryCache(resources~, limits~, now=() => now.val)
      let message_id = Ref(0)
      for step in 0..<400 {
        if rng.below(8) == 0 {
          now.val += rng.below(12).to_int64()
          // A read alone, with no event, must already see the expiry.
          ignore(cache.user(@model.Id::parse(rng.pick(fuzz_users))))
          let violations = cache_violations(cache, limits)
          if !violations.is_empty() {
            fail(
              "\{name}, seed \{seed}, step \{step} (read at \{now.val}): \{violations.join("; ")}",
            )
          }
        }
        let (event_name, fixture) = fuzz_event(rng, message_id)
        cache.update(@model.dispatch_event(event_name, @json.parse(fixture)))
        // Reads expire and evict too.
        match rng.below(4) {
          0 => ignore(cache.users())
          1 => ignore(cache.members(@model.Id::parse(rng.pick(fuzz_guilds))))
          2 => ignore(cache.messages(@model.Id::parse(rng.pick(fuzz_dms))))
          _ => ()
        }
        let violations = cache_violations(cache, limits)
        if !violations.is_empty() {
          fail(
            "\{name}, seed \{seed}, step \{step} (\{event_name}): \{violations.join("; ")}",
          )
        }
      }
      // Once every guild is gone, only DM state and the current user remain.
      for guild_id in fuzz_guilds {
        cache.update(
          @model.dispatch_event(
            "GUILD_DELETE",
            @json.parse("{\"id\":\"\{guild_id}\",\"unavailable\":false}"),
          ),
        )
      }
      assert_eq(cache_violations(cache, limits), [])
      assert_eq(
        (name, cache.members_.buckets_.length(), cache.threads_.length()),
        (name, 0, 0),
      )
      for channel_id, bucket in cache.messages_.buckets_ {
        assert_true(bucket.guild_id is None, msg="\{name}: \{channel_id}")
      }
      for _, timed in cache.channels_.entries_ {
        assert_true(timed.value.guild_id is None, msg=name)
      }
    }
  }
}
