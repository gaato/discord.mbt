///|
fn retention_channel(fixture : String) -> @model.Channel raise {
  @json.from_json(@json.parse(fixture))
}

///|
fn retention_metadata(archived : Bool) -> String {
  ",\"thread_metadata\":{\"archived\":\{archived},\"auto_archive_duration\":60,\"archive_timestamp\":\"2025-06-01T10:00:00Z\",\"locked\":false}"
}

///|
test "keeps_channel drops archived threads only" {
  let cases : Array[(String, String, Bool)] = [
    ("text channel", "{\"id\":\"1\",\"type\":0}", true),
    (
      "active thread",
      "{\"id\":\"1\",\"type\":11\{retention_metadata(false)}}",
      true,
    ),
    (
      "archived public thread",
      "{\"id\":\"1\",\"type\":11\{retention_metadata(true)}}",
      false,
    ),
    (
      "archived private thread",
      "{\"id\":\"1\",\"type\":12\{retention_metadata(true)}}",
      false,
    ),
    (
      "archived announcement thread",
      "{\"id\":\"1\",\"type\":10\{retention_metadata(true)}}",
      false,
    ),
    ("thread without metadata", "{\"id\":\"1\",\"type\":11}", true),
  ]
  for case in cases {
    let (name, fixture, expected) = case
    assert_eq(
      (name, keeps_channel(retention_channel(fixture))),
      (name, expected),
    )
  }
}

///|
test "loses_thread needs the current user removed from a private thread" {
  let bot : @model.UserId = @model.Id::parse("9")
  let other : @model.UserId = @model.Id::parse("2")
  let cases : Array[(String, Array[@model.UserId]?, @model.UserId?, Bool, Bool)] = [
    ("bot removed from private", Some([other, bot]), Some(bot), true, true),
    ("bot removed from public", Some([bot]), Some(bot), false, false),
    ("someone else removed", Some([other]), Some(bot), true, false),
    ("nobody removed", None, Some(bot), true, false),
    ("current user unknown", Some([bot]), None, true, false),
  ]
  for case in cases {
    let (name, removed, current_user, private_, expected) = case
    assert_eq(
      (name, loses_thread(removed, current_user, private_)),
      (name, expected),
    )
  }
}

///|
test "synced_away drops unlisted threads of the synced guild and parents" {
  let guild : @model.GuildId = @model.Id::parse("100")
  let other_guild : @model.GuildId = @model.Id::parse("101")
  let parent : @model.ChannelId = @model.Id::parse("400")
  let other_parent : @model.ChannelId = @model.Id::parse("401")
  let entry = { guild_id: guild, parent_id: Some(parent), private_: false, }
  let orphan = { guild_id: guild, parent_id: None, private_: false, }
  let cases : Array[
    (String, ThreadEntry, Bool, @model.GuildId, Array[@model.ChannelId]?, Bool),
  ] = [
    ("whole guild", entry, false, guild, None, true),
    ("whole guild, listed", entry, true, guild, None, false),
    ("its parent", entry, false, guild, Some([other_parent, parent]), true),
    ("its parent, listed", entry, true, guild, Some([parent]), false),
    ("other parents", entry, false, guild, Some([other_parent]), false),
    ("other guild", entry, false, other_guild, None, false),
    ("no parent, whole guild", orphan, false, guild, None, true),
    ("no parent, some parents", orphan, false, guild, Some([parent]), false),
  ]
  for case in cases {
    let (name, entry, listed, guild_id, channel_ids, expected) = case
    assert_eq(
      (name, synced_away(entry, listed, guild_id, channel_ids)),
      (name, expected),
    )
  }
}

///|
test "a thread entry records its guild, parent, and privacy" {
  let thread = retention_channel(
    "{\"id\":\"1\",\"type\":12,\"parent_id\":\"400\"}",
  )
  let entry = ThreadEntry::of(thread, @model.Id::parse("100"))
  assert_eq(entry.guild_id.to_string(), "100")
  assert_eq(entry.parent_id.map(id => id.to_string()), Some("400"))
  assert_true(entry.private_)
  let detached = ThreadEntry::of(
    retention_channel("{\"id\":\"1\",\"type\":11,\"parent_id\":null}"),
    @model.Id::parse("100"),
  )
  assert_true(detached.parent_id is None)
  assert_false(detached.private_)
}
