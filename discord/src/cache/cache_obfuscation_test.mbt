///|
/// A private text channel the bot could not view, captured live on
/// 2026-09-20 with the CHANNEL_OBFUSCATION capability (unknown fields kept,
/// ids mapped onto `guild_create_fixture`).
fn captured_obfuscated_text() -> String {
  (
    #|{"version":1789836791299,"type":0,"topic":null,"theme_color":null,"status":null,"rtc_region":null,"rate_limit_per_user":0,"position":3,"permission_overwrites":[{"type":0,"id":"100","deny":"1024","allow":"0"}],"parent_id":"410","nsfw":false,"name":"___hidden___","last_pin_timestamp":null,"last_message_id":null,"id":"411","icon_emoji":null,"flags":131072,"default_sort_order":null,"default_reaction_emoji":null,"available_tags":[],"application_id":null}
  )
}

///|
/// A hidden category and voice channel from a GUILD_CREATE, captured live on
/// 2026-11-12 by the live probe (ids mapped onto `guild_create_fixture`).
fn captured_obfuscated_category_and_voice() -> String {
  (
    #|{"voice_hangout":null,"voice_background_display":null,"version":1794456436114,"type":4,"topic":null,"theme_color":null,"status":null,"rtc_region":null,"position":4,"permission_overwrites":[{"type":0,"id":"100","deny":"1024","allow":"0"}],"parent_id":null,"nsfw":false,"name":"___hidden___","linked_lobby":null,"last_pin_timestamp":null,"last_message_id":null,"id":"410","icon_emoji":null,"hd_streaming_until":null,"hd_streaming_buyer_id":null,"game_id":null,"flags":131072,"default_tag_setting":null,"default_sort_order":null,"default_reaction_emoji":null,"available_tags":[],"application_id":null},
    #|{"voice_hangout":null,"voice_background_display":null,"version":1794456437052,"user_limit":0,"type":2,"topic":null,"theme_color":null,"status":null,"rtc_region":null,"rate_limit_per_user":0,"position":4,"permission_overwrites":[{"type":0,"id":"100","deny":"1024","allow":"0"}],"parent_id":"410","nsfw":false,"name":"___hidden___","linked_lobby":null,"last_pin_timestamp":null,"last_message_id":null,"id":"412","icon_emoji":null,"hd_streaming_until":null,"hd_streaming_buyer_id":null,"game_id":null,"flags":131072,"default_tag_setting":null,"default_sort_order":null,"default_reaction_emoji":null,"bitrate":64000,"available_tags":[],"application_id":null}
  )
}

///|
/// A hidden stage channel synthesized from the documented obfuscation rules
/// (only `id`, `type`, `position` and `parent_id` kept, everything else
/// nulled). The live captures fill plain fields with defaults instead, so
/// this keeps the null case the docs allow in the GUILD_CREATE.
fn synthesized_obfuscated_stage() -> String {
  (
    #|{"id":"413","type":13,"position":5,"parent_id":"410","flags":131072,"name":"___hidden___","permission_overwrites":[{"type":0,"id":"100","deny":"1024","allow":"0"}],"nsfw":null,"bitrate":null,"user_limit":null,"rate_limit_per_user":null,"rtc_region":null,"video_quality_mode":null,"topic":null}
  )
}

///|
/// `guild_create_fixture` with the hidden channels listed before `general`.
fn guild_create_with_hidden_channels() -> String {
  guild_create_fixture().replace(
    old="\"channels\": [",
    new="\"channels\": [" +
      captured_obfuscated_text() +
      "," +
      captured_obfuscated_category_and_voice() +
      "," +
      synthesized_obfuscated_stage() +
      ",",
  )
}

///|
test "guild create with obfuscated channels decodes and fills the cache" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::all())
  cache.update(
    cached_event("GUILD_CREATE", guild_create_with_hidden_channels()),
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  assert_true(cache.guild(guild_id) is Some(_))
  let listed = ["400", "410", "411", "412", "413"].map(id => {
    guard cache.channel(@model.Id::parse(id)) is Some(channel) else {
      fail("channel \{id} is not cached")
    }
    "\{id}:\{channel.typ.to_int()}:\{channel.is_obfuscated()}"
  })
  debug_inspect(
    listed,
    content=(
      #|[
      #|  "400:0:false",
      #|  "410:4:true",
      #|  "411:0:true",
      #|  "412:2:true",
      #|  "413:13:true",
      #|]
    ),
  )
}

///|
test "permissions_in is None on an obfuscated channel" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::all())
  // The live capture alone, which decoded before obfuscation support, so the
  // test exercises permissions_in itself.
  cache.update(
    cached_event(
      "GUILD_CREATE",
      guild_create_fixture().replace(
        old="\"channels\": [",
        new="\"channels\": [" + captured_obfuscated_text() + ",",
      ),
    ),
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let hidden : @model.ChannelId = @model.Id::parse("411")
  let general : @model.ChannelId = @model.Id::parse("400")
  let admin_id : @model.UserId = @model.Id::parse("201")
  let writer_id : @model.UserId = @model.Id::parse("202")
  assert_true(cache.channel(hidden) is Some(_))
  // The placeholder overwrite would deny VIEW_CHANNEL to the writer and
  // grant everything to the administrator; neither is known.
  assert_true(cache.permissions_in(guild_id, hidden, writer_id) is None)
  assert_true(cache.permissions_in(guild_id, hidden, admin_id) is None)
  assert_true(cache.permissions_in(guild_id, general, writer_id) is Some(_))
}

///|
test "channel update with full data replaces an obfuscated channel" {
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::all())
  cache.update(
    cached_event("GUILD_CREATE", guild_create_with_hidden_channels()),
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let voice : @model.ChannelId = @model.Id::parse("412")
  let writer_id : @model.UserId = @model.Id::parse("202")
  assert_true(cache.permissions_in(guild_id, voice, writer_id) is None)
  // The CHANNEL_UPDATE Discord sent for the captured voice channel once the
  // bot regained access, captured live on 2026-11-12 (ids mapped; the viewer
  // role becomes `writer`).
  cache.update(
    cached_event(
      "CHANNEL_UPDATE",
      (
        #|{"version":1794456437052,"user_limit":0,"type":2,"rtc_region":null,"rate_limit_per_user":0,"position":4,"permission_overwrites":[{"type":0,"id":"100","deny":"1024","allow":"0"},{"type":0,"id":"302","deny":"0","allow":"1024"}],"parent_id":"410","nsfw":false,"name":"probe-hidden-voice","last_message_id":null,"id":"412","guild_id":"100","flags":0,"bitrate":64000,"application_id":null}
      ),
    ),
  )
  guard cache.channel(voice) is Some(channel) else {
    fail("expected the updated channel")
  }
  assert_false(channel.is_obfuscated())
  assert_true(channel.name == Some(Value("probe-hidden-voice")))
  assert_true(channel.bitrate == Some(64000))
  guard cache.permissions_in(guild_id, voice, writer_id) is Some(writer) else {
    fail("expected permissions from the real overwrites")
  }
  assert_true(writer.contains(@model.Permissions::view_channel()))
}
