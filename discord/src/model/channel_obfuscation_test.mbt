///|
/// Obfuscated channels of every type, synthesized from the documented rules:
/// `id`, `type`, `position` and `parent_id` kept, `name` `"___hidden___"`,
/// one placeholder overwrite, and every other field this type carries nulled.
/// The 2026-11-12 captures (below) reduced plain fields to defaults instead,
/// but the docs allow nulls and stage, media and announcement channels have
/// not been captured, so this is the case the decoder must survive.
fn synthesized_obfuscated_channels() -> Array[(String, Json)] {
  let placeholder : Json = [
    { "type": 0, "id": "100", "deny": "1024", "allow": "0" },
  ]
  let base = (id : String, typ : Int32, position : Int32, parent : Json) => {
    let fields : Map[String, Json] = {
      "id": Json::string(id),
      "type": Json::number(typ.to_double()),
      "position": Json::number(position.to_double()),
      "parent_id": parent,
      "flags": 131072,
      "name": "___hidden___",
      "permission_overwrites": placeholder,
      "nsfw": Json::null(),
      "rate_limit_per_user": Json::null(),
      "topic": Json::null(),
      "last_message_id": Json::null(),
      "application_id": Json::null(),
    }
    fields
  }
  let category = base("700", 4, 0, Json::null())
  let voice = base("702", 2, 2, "700")
  for key in ["bitrate", "user_limit", "rtc_region", "video_quality_mode"] {
    voice[key] = Json::null()
  }
  let stage = base("703", 13, 3, "700")
  for key in ["bitrate", "user_limit", "rtc_region", "video_quality_mode"] {
    stage[key] = Json::null()
  }
  let forum_keys = [
    "available_tags", "default_reaction_emoji", "default_thread_rate_limit_per_user",
    "default_sort_order", "default_forum_layout", "default_auto_archive_duration",
  ]
  let forum = base("704", 15, 4, "700")
  let media = base("705", 16, 5, "700")
  for key in forum_keys {
    forum[key] = Json::null()
    media[key] = Json::null()
  }
  let announcement = base("706", 5, 6, "700")
  announcement["default_auto_archive_duration"] = Json::null()
  [
    ("category", Json::object(category)),
    ("voice", Json::object(voice)),
    ("stage", Json::object(stage)),
    ("forum", Json::object(forum)),
    ("media", Json::object(media)),
    ("announcement", Json::object(announcement)),
  ]
}

///|
test "obfuscated channels of every type decode with their fields nulled (synthesized)" {
  let decoded = synthesized_obfuscated_channels().map(entry => {
    let (label, json) = entry
    let channel : @model.Channel = @json.from_json(json) catch {
      err => fail("\{label}: \{err}")
    }
    // The guaranteed fields survive; the nulled plain fields become None.
    assert_true(channel.is_obfuscated())
    assert_true(channel.position is Some(_))
    assert_true(channel.permission_overwrites.map_or(0, o => o.length()) == 1)
    assert_true(channel.nsfw is None && channel.rate_limit_per_user is None)
    assert_true(channel.bitrate is None && channel.available_tags is None)
    assert_true(channel.name == Some(Value("___hidden___")))
    let parent = match channel.parent_id {
      Some(Value(id)) => id.to_string()
      Some(Null) => "null"
      None => "absent"
    }
    "\{label}:\{channel.typ.to_int()}:\{channel.position.unwrap()}:\{parent}"
  })
  debug_inspect(
    decoded,
    content=(
      #|[
      #|  "category:4:0:null",
      #|  "voice:2:2:700",
      #|  "stage:13:3:700",
      #|  "forum:15:4:700",
      #|  "media:16:5:700",
      #|  "announcement:5:6:700",
      #|]
    ),
  )
}

///|
test "only an obfuscated channel tolerates a malformed field, and never a guaranteed one" {
  let channel = (flags : Int32, key : String, value : Json) => {
    let fields : Map[String, Json] = {
      "id": "702",
      "type": 2,
      "position": 2,
      "parent_id": "700",
      "flags": flags,
    }
    fields[key] = value
    let decoded : @model.Channel = @json.from_json(Json::object(fields))
    decoded
  }
  let obfuscated = 131072
  // A non-guaranteed field that does not decode is dropped, null or not.
  let bad_bitrate = channel(obfuscated, "bitrate", "hidden")
  assert_true(bad_bitrate.is_obfuscated() && bad_bitrate.bitrate is None)
  let null_overwrites = channel(
    obfuscated,
    "permission_overwrites",
    Json::null(),
  )
  assert_true(null_overwrites.permission_overwrites is None)
  // The fields Discord promises stay strict even on an obfuscated channel.
  assert_true(rejects(() => channel(obfuscated, "position", Json::null())))
  assert_true(rejects(() => channel(obfuscated, "parent_id", true)))
  assert_true(rejects(() => channel(obfuscated, "type", "voice")))
  // Without the flag every field is strict, so a malformed channel still fails.
  assert_true(rejects(() => channel(0, "bitrate", Json::null())))
  assert_true(rejects(() => channel(0, "bitrate", "hidden")))
  assert_true(rejects(() => channel(4, "permission_overwrites", Json::null())))
  // A malformed flags field cannot be read as obfuscated either.
  assert_true(rejects(() => channel(0, "flags", "131072")))
}

///|
fn rejects(decode : () -> @model.Channel raise) -> Bool {
  try {
    ignore(decode())
    false
  } catch {
    _ => true
  }
}

///|
/// Obfuscated channels from a GUILD_CREATE, captured live on 2026-11-12 by
/// the live probe with the CHANNEL_OBFUSCATION capability, verbatim.
fn captured_obfuscated_channels_2026_11_12() -> Array[(String, String)] {
  [
    (
      "category",
      (
        #|{"voice_hangout":null,"voice_background_display":null,"version":1794456436114,"type":4,"topic":null,"theme_color":null,"status":null,"rtc_region":null,"position":4,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"}],"parent_id":null,"nsfw":false,"name":"___hidden___","linked_lobby":null,"last_pin_timestamp":null,"last_message_id":null,"id":"1570288848808710204","icon_emoji":null,"hd_streaming_until":null,"hd_streaming_buyer_id":null,"game_id":null,"flags":131072,"default_tag_setting":null,"default_sort_order":null,"default_reaction_emoji":null,"available_tags":[],"application_id":null}
      ),
    ),
    (
      "text",
      (
        #|{"voice_hangout":null,"voice_background_display":null,"version":1794456436400,"type":0,"topic":null,"theme_color":null,"status":null,"rtc_region":null,"rate_limit_per_user":0,"position":8,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"}],"parent_id":"1570288848808710204","nsfw":false,"name":"___hidden___","linked_lobby":null,"last_pin_timestamp":null,"last_message_id":null,"id":"1570288850008547378","icon_emoji":null,"hd_streaming_until":null,"hd_streaming_buyer_id":null,"game_id":null,"flags":131072,"default_tag_setting":null,"default_sort_order":null,"default_reaction_emoji":null,"available_tags":[],"application_id":null}
      ),
    ),
    (
      "voice",
      (
        #|{"voice_hangout":null,"voice_background_display":null,"version":1794456437052,"user_limit":0,"type":2,"topic":null,"theme_color":null,"status":null,"rtc_region":null,"rate_limit_per_user":0,"position":4,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"}],"parent_id":"1570288848808710204","nsfw":false,"name":"___hidden___","linked_lobby":null,"last_pin_timestamp":null,"last_message_id":null,"id":"1570288852742967306","icon_emoji":null,"hd_streaming_until":null,"hd_streaming_buyer_id":null,"game_id":null,"flags":131072,"default_tag_setting":null,"default_sort_order":null,"default_reaction_emoji":null,"bitrate":64000,"available_tags":[],"application_id":null}
      ),
    ),
    (
      "forum",
      (
        #|{"voice_hangout":null,"voice_background_display":null,"version":1794456437385,"type":15,"topic":null,"theme_color":null,"template":"","status":null,"rtc_region":null,"rate_limit_per_user":0,"position":2,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"}],"parent_id":"1570288848808710204","nsfw":false,"name":"___hidden___","linked_lobby":null,"last_pin_timestamp":null,"last_message_id":null,"id":"1570288854131282001","icon_emoji":null,"hd_streaming_until":null,"hd_streaming_buyer_id":null,"game_id":null,"flags":131072,"default_tag_setting":null,"default_sort_order":null,"default_reaction_emoji":null,"available_tags":[],"application_id":null}
      ),
    ),
  ]
}

///|
/// The CHANNEL_UPDATEs Discord sent for the same channels once the bot
/// regained access, captured live on 2026-11-12, verbatim.
fn captured_regained_channels_2026_11_12() -> Array[(String, String)] {
  [
    (
      "category",
      (
        #|{"version":1794456436114,"type":4,"position":4,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"},{"type":0,"id":"1570288846070095923","deny":"0","allow":"1024"}],"parent_id":null,"name":"probe-hidden","id":"1570288848808710204","guild_id":"1527253314998108220","flags":0}
      ),
    ),
    (
      "text",
      (
        #|{"version":1794456436400,"type":0,"topic":null,"rate_limit_per_user":0,"position":8,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"},{"type":0,"id":"1570288846070095923","deny":"0","allow":"1024"}],"parent_id":"1570288848808710204","nsfw":false,"name":"probe-hidden-text","last_message_id":null,"id":"1570288850008547378","guild_id":"1527253314998108220","flags":0}
      ),
    ),
    (
      "voice",
      (
        #|{"version":1794456437052,"user_limit":0,"type":2,"rtc_region":null,"rate_limit_per_user":0,"position":4,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"},{"type":0,"id":"1570288846070095923","deny":"0","allow":"1024"}],"parent_id":"1570288848808710204","nsfw":false,"name":"probe-hidden-voice","last_message_id":null,"id":"1570288852742967306","guild_id":"1527253314998108220","flags":0,"bitrate":64000,"application_id":null}
      ),
    ),
    (
      "forum",
      (
        #|{"version":1794456437385,"type":15,"topic":null,"theme_color":null,"template":"","rate_limit_per_user":0,"position":2,"permission_overwrites":[{"type":0,"id":"1527253314998108220","deny":"1024","allow":"0"},{"type":0,"id":"1570288846070095923","deny":"0","allow":"1024"}],"parent_id":"1570288848808710204","nsfw":false,"name":"probe-hidden-forum","last_message_id":null,"id":"1570288854131282001","icon_emoji":null,"guild_id":"1527253314998108220","flags":0,"default_tag_setting":"match_some","default_sort_order":null,"default_reaction_emoji":null,"available_tags":[]}
      ),
    ),
  ]
}

///|
test "obfuscated channels captured live on 2026-11-12 decode" {
  let decoded = captured_obfuscated_channels_2026_11_12().map(entry => {
    let (label, raw) = entry
    let channel : @model.Channel = @json.from_json(@json.parse(raw)) catch {
      err => fail("\{label}: \{err}")
    }
    assert_true(channel.is_obfuscated())
    assert_true(channel.name == Some(Value("___hidden___")))
    // The one placeholder overwrite: @everyone denied VIEW_CHANNEL.
    guard channel.permission_overwrites is Some([overwrite]) else {
      fail("\{label}: expected one placeholder overwrite")
    }
    assert_true(
      overwrite.deny == @model.Permissions::view_channel() &&
      overwrite.allow == @model.Permissions::none(),
    )
    "\{label}:\{channel.typ.to_int()}:\{channel.position.unwrap()}"
  })
  debug_inspect(
    decoded,
    content=(
      #|["category:4:4", "text:0:8", "voice:2:4", "forum:15:2"]
    ),
  )
  // What Discord sent once the bot could view them again: the full channels.
  let regained = captured_regained_channels_2026_11_12().map(entry => {
    let (label, raw) = entry
    let channel : @model.Channel = @json.from_json(@json.parse(raw))
    assert_false(channel.is_obfuscated())
    assert_true(channel.permission_overwrites.map_or(0, o => o.length()) == 2)
    let name = match channel.name {
      Some(Value(name)) => name
      _ => "?"
    }
    "\{label}:\{name}"
  })
  debug_inspect(
    regained,
    content=(
      #|[
      #|  "category:probe-hidden",
      #|  "text:probe-hidden-text",
      #|  "voice:probe-hidden-voice",
      #|  "forum:probe-hidden-forum",
      #|]
    ),
  )
}
