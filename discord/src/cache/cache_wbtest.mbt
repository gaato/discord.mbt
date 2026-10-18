///|
fn wb_event(name : String, fixture : String) -> @model.Event raise {
  @model.dispatch_event(name, @json.parse(fixture))
}

///|
/// Sizes of every structure keyed by a guild or channel. Per-guild and
/// per-channel resources count buckets, not entries.
fn footprint(cache : InMemoryCache) -> String {
  let guilds = cache.guilds_.entries_.length()
  let channels = cache.channels_.entries_.length()
  let roles = cache.roles_.buckets_.length()
  let members = cache.members_.buckets_.length()
  let voice_states = cache.voice_states_.buckets_.length()
  let presences = cache.presences_.buckets_.length()
  let messages = cache.messages_.buckets_.length()
  "guilds=\{guilds} channels=\{channels} roles=\{roles} members=\{members} voice_states=\{voice_states} presences=\{presences} messages=\{messages}"
}

///|
let empty_footprint = "guilds=0 channels=0 roles=0 members=0 voice_states=0 presences=0 messages=0"

///|
fn wb_guild_fixture(guild_id : String) -> String {
  (
    #|{"id":"GUILD_ID","name":"g","icon":null,"splash":null,"discovery_splash":null,"owner_id":"200","afk_channel_id":null,"afk_timeout":300,"verification_level":1,"default_message_notifications":1,"explicit_content_filter":2,
    #|"roles":[{"id":"GUILD_ID","name":"@everyone","color":0,"hoist":false,"position":0,"permissions":"1024","managed":false,"mentionable":false}],
    #|"emojis":[],"features":[],"mfa_level":0,"application_id":null,"system_channel_id":null,"system_channel_flags":0,"rules_channel_id":null,"vanity_url_code":null,"description":null,"banner":null,"premium_tier":0,"preferred_locale":"en-US","public_updates_channel_id":null,"safety_alerts_channel_id":null,"joined_at":"2025-06-01T10:00:00Z","large":false,"unavailable":false,"member_count":1,
    #|"voice_states":[{"channel_id":"GUILD_ID0","user_id":"201","session_id":"s","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null}],
    #|"members":[{"user":{"id":"201","username":"reader","discriminator":"0","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00Z","deaf":false,"mute":false}],
    #|"channels":[{"id":"GUILD_ID0","type":0,"name":"general","permission_overwrites":[]}],
    #|"threads":[{"id":"GUILD_ID1","type":11,"guild_id":"GUILD_ID","parent_id":"GUILD_ID0","name":"thread"}],
    #|"presences":[{"user":{"id":"201"},"status":"online"}],
    #|"stage_instances":[],"guild_scheduled_events":[],"soundboard_sounds":[]}
  ).replace_all(old="GUILD_ID", new=guild_id)
}

///|
fn wb_message_fixture(channel_id : String, guild_id : String) -> String {
  (
    #|{"id":"900","channel_id":"CHANNEL_ID","guild_id":"GUILD_ID","author":{"id":"202","username":"writer","discriminator":"0","avatar":null},"content":"hi","timestamp":"2025-06-01T10:00:00Z","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
  )
  .replace(old="CHANNEL_ID", new=channel_id)
  .replace(old="GUILD_ID", new=guild_id)
}

///|
/// Seeds guild `id` with a role, member, voice state, presence, channel
/// `{id}0`, thread `{id}1`, and a message in each.
fn seed_guild(cache : InMemoryCache, id : String) -> Unit raise {
  cache.update(wb_event("GUILD_CREATE", wb_guild_fixture(id)))
  cache.update(wb_event("MESSAGE_CREATE", wb_message_fixture("\{id}0", id)))
  cache.update(wb_event("MESSAGE_CREATE", wb_message_fixture("\{id}1", id)))
}

///|
/// Names of the structures still holding anything keyed by guild `id` or by
/// one of the channels `seed_guild` gives it.
fn remnants(cache : InMemoryCache, id : String) -> Array[String] raise {
  let guild_id : @model.GuildId = @model.Id::parse(id)
  let channel_ids : Array[@model.ChannelId] = [
    @model.Id::parse("\{id}0"),
    @model.Id::parse("\{id}1"),
  ]
  let found = []
  if cache.guilds_.entries_.contains(guild_id) {
    found.push("guilds")
  }
  if channel_ids.any(channel_id => cache.channels_.entries_.contains(channel_id)) {
    found.push("channels")
  }
  if cache.roles_.buckets_.contains(guild_id) {
    found.push("roles")
  }
  if cache.members_.buckets_.contains(guild_id) {
    found.push("members")
  }
  if cache.voice_states_.buckets_.contains(guild_id) {
    found.push("voice_states")
  }
  if cache.presences_.buckets_.contains(guild_id) {
    found.push("presences")
  }
  if channel_ids.any(channel_id => cache.messages_.buckets_.contains(channel_id)) {
    found.push("messages")
  }
  if channel_ids.any(channel_id => cache.threads_.contains(channel_id)) {
    found.push("threads")
  }
  found
}

///|
test "a departed guild leaves nothing keyed by it or its channels" {
  let departures : Array[(String, CacheLimits, @model.Event)] = [
    (
      "entry limit",
      CacheLimits(guilds=CacheLimit(max_entries=1)),
      wb_event("GUILD_CREATE", wb_guild_fixture("101")),
    ),
    (
      "TTL",
      CacheLimits(guilds=CacheLimit(ttl_ms=1000L)),
      wb_event(
        "USER_UPDATE",
        (
          #|{"id":"9","username":"other","discriminator":"0","avatar":null}
        ),
      ),
    ),
    (
      "delete",
      CacheLimits(),
      wb_event(
        "GUILD_DELETE",
        (
          #|{"id":"100","unavailable":false}
        ),
      ),
    ),
  ]
  for departure in departures {
    let (name, limits, event) = departure
    for
      resources in [
        CacheResources::all(),
        CacheResources(channels=false, presences=true, messages=true),
      ] {
      let now = Ref(0L)
      let cache = InMemoryCache(resources~, limits~, now=() => now.val)
      seed_guild(cache, "100")
      assert_true(remnants(cache, "100").length() > 0)
      now.val = 1000L
      cache.update(event)
      assert_eq((name, remnants(cache, "100")), (name, []))
      assert_eq((name, cache_violations(cache, limits)), (name, []))
    }
  }
}

///|
test "operations drop the per-owner buckets they leave empty" {
  let cache = InMemoryCache(resources=CacheResources::all())
  cache.update(
    wb_event(
      "GUILD_ROLE_CREATE",
      (
        #|{"guild_id":"100","role":{"id":"301","name":"r","color":0,"hoist":false,"position":1,"permissions":"0","managed":false,"mentionable":false}}
      ),
    ),
  )
  cache.update(
    wb_event(
      "VOICE_STATE_UPDATE",
      (
        #|{"guild_id":"100","channel_id":"400","user_id":"201","session_id":"s","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null,"member":{"user":{"id":"201","username":"m","discriminator":"0","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00Z"}}
      ),
    ),
  )
  cache.update(
    wb_event(
      "PRESENCE_UPDATE",
      (
        #|{"guild_id":"100","user":{"id":"201"},"status":"online"}
      ),
    ),
  )
  cache.update(wb_event("MESSAGE_CREATE", wb_message_fixture("400", "100")))
  assert_eq(
    footprint(cache),
    "guilds=0 channels=0 roles=1 members=1 voice_states=1 presences=1 messages=1",
  )
  cache.update(
    wb_event(
      "GUILD_ROLE_DELETE",
      (
        #|{"guild_id":"100","role_id":"301"}
      ),
    ),
  )
  cache.update(
    wb_event(
      "GUILD_MEMBER_REMOVE",
      (
        #|{"guild_id":"100","user":{"id":"201","username":"m","discriminator":"0","avatar":null}}
      ),
    ),
  )
  cache.update(
    wb_event(
      "MESSAGE_DELETE",
      (
        #|{"id":"900","channel_id":"400","guild_id":"100"}
      ),
    ),
  )
  assert_eq(footprint(cache), empty_footprint)
}

///|
test "expiry and zero limits leave no empty buckets behind" {
  let now = Ref(0L)
  let cache = InMemoryCache(
    resources=CacheResources::all(),
    limits=CacheLimits(
      members=CacheLimit(max_entries=0),
      messages=CacheLimit(ttl_ms=1000L),
    ),
    now=() => now.val,
  )
  cache.update(
    wb_event(
      "GUILD_MEMBER_ADD",
      (
        #|{"guild_id":"100","user":{"id":"201","username":"m","discriminator":"0","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00Z"}
      ),
    ),
  )
  cache.update(wb_event("MESSAGE_CREATE", wb_message_fixture("400", "100")))
  assert_eq(
    footprint(cache),
    "guilds=0 channels=0 roles=0 members=0 voice_states=0 presences=0 messages=1",
  )
  now.val = 1000L
  assert_eq(cache.messages(@model.Id::parse("400")).length(), 0)
  assert_eq(footprint(cache), empty_footprint)
}

///|
test "without retained channels a thread sync leaves no channel bookkeeping" {
  let cache = InMemoryCache(resources=CacheResources(channels=false))
  seed_guild(cache, "100")
  cache.update(
    wb_event(
      "THREAD_LIST_SYNC",
      (
        #|{"guild_id":"100","threads":[{"id":"1002","type":11,"guild_id":"100","parent_id":"1000","name":"new"}],"members":[]}
      ),
    ),
  )
  assert_eq(
    footprint(cache),
    "guilds=1 channels=0 roles=1 members=1 voice_states=1 presences=0 messages=0",
  )
}
