///|
fn member_add_fixture(user_id : String, username : String) -> String {
  (
    #|{"guild_id":"100","user":{"id":"USER_ID","username":"USERNAME","discriminator":"0","avatar":null},"roles":["301"],"joined_at":"2025-06-01T10:00:00Z"}
  )
  .replace(old="USER_ID", new=user_id)
  .replace(old="USERNAME", new=username)
}

///|
test "member, presence, and voice-state flows land in their guild maps" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::all())
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let user_id : @model.UserId = @model.Id::parse("200")

  cache.update(
    cached_event("GUILD_MEMBER_ADD", member_add_fixture("200", "nelly")),
  )
  guard cache.member(guild_id, user_id) is Some(added) else {
    fail("expected a cached member")
  }
  assert_eq(added.roles.length(), 1)
  assert_eq(cache.members(guild_id).length(), 1)
  guard cache.user(user_id) is Some(_) else { fail("expected a cached user") }

  // A member update merges over the previous entry.
  cache.update(
    cached_event(
      "GUILD_MEMBER_UPDATE",
      (
        #|{"guild_id":"100","roles":["301","302"],"user":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"nick":"Nel","avatar":null,"joined_at":"2025-06-01T10:00:00Z"}
      ),
    ),
  )
  guard cache.member(guild_id, user_id) is Some(updated) else {
    fail("expected the updated member")
  }
  assert_eq(updated.roles.length(), 2)
  assert_true(updated.nick is Some(Value("Nel")))

  // A member chunk stores both members and typed presences.
  cache.update(
    cached_event(
      "GUILD_MEMBERS_CHUNK",
      (
        #|{"guild_id":"100","members":[{"user":{"id":"201","username":"wumpus","discriminator":"0","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00Z"}],"chunk_index":0,"chunk_count":1,"presences":[{"user":{"id":"201"},"status":"online"}]}
      ),
    ),
  )
  assert_eq(cache.members(guild_id).length(), 2)
  guard cache.presence(guild_id, @model.Id::parse("201")) is Some(_) else {
    fail("expected a chunk presence")
  }

  cache.update(
    cached_event(
      "PRESENCE_UPDATE",
      (
        #|{"user":{"id":"200"},"guild_id":"100","status":"idle"}
      ),
    ),
  )
  assert_eq(cache.presences(guild_id).length(), 2)

  // Voice states join, move, and clear on a null channel.
  cache.update(
    cached_event(
      "VOICE_STATE_UPDATE",
      (
        #|{"guild_id":"100","channel_id":"400","user_id":"200","session_id":"sess","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null,"member":{"user":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00Z"}}
      ),
    ),
  )
  guard cache.voice_state(guild_id, user_id) is Some(state) else {
    fail("expected a cached voice state")
  }
  assert_true(state.channel_id is Value(_))
  assert_eq(cache.voice_states(guild_id).length(), 1)
  cache.update(
    cached_event(
      "VOICE_STATE_UPDATE",
      (
        #|{"guild_id":"100","channel_id":null,"user_id":"200","session_id":"sess","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null}
      ),
    ),
  )
  assert_true(cache.voice_state(guild_id, user_id) is None)

  // Bans only refresh the user record; removal clears everything.
  cache.update(
    cached_event(
      "GUILD_BAN_ADD",
      (
        #|{"guild_id":"100","user":{"id":"200","username":"nelly-banned","discriminator":"0","avatar":null}}
      ),
    ),
  )
  guard cache.user(user_id) is Some(banned_user) else {
    fail("expected the banned user record")
  }
  assert_eq(banned_user.username, "nelly-banned")
  assert_true(cache.member(guild_id, user_id) is Some(_))
  cache.update(
    cached_event(
      "GUILD_MEMBER_REMOVE",
      (
        #|{"guild_id":"100","user":{"id":"200","username":"nelly-banned","discriminator":"0","avatar":null}}
      ),
    ),
  )
  assert_true(cache.member(guild_id, user_id) is None)
  assert_true(cache.presence(guild_id, user_id) is None)
  assert_true(cache.voice_state(guild_id, user_id) is None)
}

///|
test "thread list sync replaces tracked threads and keeps plain channels" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::all())
  cache.update(
    cached_event(
      "CHANNEL_CREATE",
      (
        #|{"id":"400","type":0,"guild_id":"100","name":"general"}
      ),
    ),
  )
  cache.update(
    cached_event(
      "THREAD_CREATE",
      (
        #|{"id":"401","type":11,"guild_id":"100","parent_id":"400","name":"old-thread"}
      ),
    ),
  )
  cache.update(
    cached_event(
      "THREAD_LIST_SYNC",
      (
        #|{"guild_id":"100","channel_ids":["400"],"threads":[{"id":"402","type":11,"guild_id":"100","parent_id":"400","name":"fresh-thread"}],"members":[]}
      ),
    ),
  )
  // The synced parent's stale thread is dropped, the fresh one stored, and
  // the plain channel untouched.
  assert_true(cache.channel(@model.Id::parse("401")) is None)
  assert_true(cache.channel(@model.Id::parse("402")) is Some(_))
  assert_true(cache.channel(@model.Id::parse("400")) is Some(_))
}
