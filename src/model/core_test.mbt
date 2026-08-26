///|
/// A sample struct mirroring how model entities will use the core types:
/// derived JSON codecs composing hand-written impls on Id/Nullable/etc.
struct SampleEntity {
  id : @model.UserId
  guild_id : @model.GuildId?
  nick : @model.Nullable[String]
  avatar : @model.Nullable[@model.ImageHash]?
  typ : @model.ChannelType
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
test "id decodes from string, int, and big int; encodes as string" {
  let from_string : @model.UserId = @json.from_json(
    Json::string("175928847299117063"),
  )
  inspect(from_string.value(), content="175928847299117063")
  let from_int : @model.UserId = @json.from_json(@json.parse("42"))
  inspect(from_int.value(), content="42")
  // 2^53 + 1: must survive without Double precision loss
  let big : @model.UserId = @json.from_json(@json.parse("9007199254740993"))
  inspect(big.value(), content="9007199254740993")
  inspect(big.to_json().stringify(), content="\"9007199254740993\"")
}

///|
test "id decode rejects garbage" {
  try
    (@json.from_json(Json::string("not-a-number")) : @model.UserId) |> ignore
  catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|JsonDecodeError((Root, "expected a snowflake (decimal string), got not-a-number"))
        ),
      )
  } noraise {
    _ => fail("expected decode to fail")
  }
  try (@json.from_json(Json::boolean(true)) : @model.UserId) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected decode to fail")
  }
}

///|
test "id extracts snowflake timestamp" {
  // example snowflake from the Discord docs: 2016-04-30T11:18:25.796Z
  let id : @model.UserId = Id(175928847299117063UL)
  inspect(id.timestamp_ms(), content="1462015105796")
}

///|
test "id cast re-tags the marker" {
  let guild_id : @model.GuildId = Id(81384788765712384UL)
  let everyone_role : @model.RoleId = guild_id.cast()
  inspect(everyone_role.value(), content="81384788765712384")
}

///|
test "ids work as map keys" {
  let m : Map[@model.ChannelId, String] = Map([])
  m[Id(1UL)] = "general"
  m[Id(2UL)] = "random"
  assert_eq(m[Id(1UL)], "general")
}

///|
test "derived struct composes core types (decode)" {
  let json =
    #|{
    #|  "id": "80351110224678912",
    #|  "guild_id": "81384788765712384",
    #|  "nick": null,
    #|  "avatar": "a_1269e74af4df7417b13759eae50c83dc",
    #|  "type": 0,
    #|  "brand_new_field_from_discord": true
    #|}
  let entity : SampleEntity = @json.from_json(@json.parse(json))
  debug_inspect(
    entity,
    content=(
      #|{
      #|  id: 80351110224678912,
      #|  guild_id: Some(81384788765712384),
      #|  nick: Null,
      #|  avatar: Some(Value("a_1269e74af4df7417b13759eae50c83dc")),
      #|  typ: GuildText,
      #|}
    ),
  )
  guard entity.avatar is Some(Value(hash)) else { fail("expected avatar") }
  assert_true(hash.is_animated())
}

///|
test "derived struct composes core types (encode, absent optional omitted)" {
  let entity = SampleEntity::{
    id: Id(1UL),
    guild_id: None,
    nick: Value("neko"),
    avatar: Some(Null),
    typ: Unknown(99),
  }
  inspect(
    ToJson::to_json(entity).stringify(),
    content=(
      #|{"id":"1","nick":"neko","avatar":null,"type":99}
    ),
  )
}

///|
test "obj_builder emits field/opt/und correctly" {
  let body = @model.ObjBuilder()
    .field("name", "general")
    .opt("topic", (None : String?))
    .opt("position", Some(3))
    .und("icon", (Missing : @model.Undefinable[String]))
    .und("banner", (Null : @model.Undefinable[String]))
    .und("nick", Value("neko"))
    .build()
  inspect(
    body.stringify(),
    content=(
      #|{"name":"general","position":3,"banner":null,"nick":"neko"}
    ),
  )
}

///|
test "channel type round-trips unknown values" {
  let known : @model.ChannelType = @json.from_json(@json.parse("5"))
  debug_inspect(known, content="GuildAnnouncement")
  let unknown : @model.ChannelType = @json.from_json(@json.parse("9999"))
  debug_inspect(unknown, content="Unknown(9999)")
  inspect(unknown.to_json().stringify(), content="9999")
}

///|
test "intents combine and serialize as a number" {
  let intents = @model.Intents::guilds() |
    @model.Intents::guild_messages() |
    @model.Intents::message_content()
  inspect(intents.bits(), content="33281")
  assert_true(intents.contains(@model.Intents::guilds()))
  assert_false(intents.contains(@model.Intents::guild_members()))
  inspect(intents.to_json().stringify(), content="33281")
  let decoded : @model.Intents = @json.from_json(@json.parse("33281"))
  assert_true(decoded == intents)
}

///|
test "permissions serialize as decimal string and keep unknown bits" {
  let perms = @model.Permissions::send_messages() |
    @model.Permissions::embed_links()
  inspect(perms.to_json().stringify(), content="\"18432\"")
  // bit 62 is unassigned today; it must survive a round-trip
  let raw = "\"4611686018427387904\""
  let unknown : @model.Permissions = @json.from_json(@json.parse(raw))
  inspect(unknown.to_json().stringify(), content=raw)
  let decoded : @model.Permissions = @json.from_json(Json::string("18432"))
  assert_true(decoded.contains(@model.Permissions::send_messages()))
}

///|
test "timestamp parses discord shapes" {
  inspect(
    @model.Timestamp("2021-03-11T18:15:37.907000+00:00").unix_ms(),
    content="1615486537907",
  )
  inspect(
    @model.Timestamp("2021-03-11T18:15:37.907+09:00").unix_ms(),
    content="1615454137907",
  )
  inspect(
    @model.Timestamp("2016-04-30T11:18:25.796Z").unix_ms(),
    content="1462015105796",
  )
  inspect(@model.Timestamp("1970-01-01T00:00:00Z").unix_ms(), content="0")
}

///|
test "timestamp rejects malformed input" {
  try @model.Timestamp("yesterday").unix_ms() |> ignore catch {
    InvalidTimestamp(s) => inspect(s, content="yesterday")
  } noraise {
    _ => fail("expected parse to fail")
  }
  try @model.Timestamp("2021-03-11X18:15:37Z").unix_ms() |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected parse to fail")
  }
}

///|
test "timestamp json round-trip is lossless" {
  let raw = "\"2021-03-11T18:15:37.907000+00:00\""
  let ts : @model.Timestamp = @json.from_json(@json.parse(raw))
  inspect(ts.to_json().stringify(), content=raw)
}

///|
test "image hash animated detection" {
  assert_true(
    @model.ImageHash("a_1269e74af4df7417b13759eae50c83dc").is_animated(),
  )
  assert_false(
    @model.ImageHash("1269e74af4df7417b13759eae50c83dc").is_animated(),
  )
}

///|
test "nullable helpers" {
  let v : @model.Nullable[Int] = Value(1)
  assert_true(v.to_option() == Some(1))
  let n : @model.Nullable[Int] = Null
  assert_true(n.to_option() is None)
  assert_true(@model.Nullable::from_option(Some(2)) == Value(2))
}
