///|
test "outgoing gateway commands match documented payloads" {
  let presence = @model.UpdatePresence(since=91879201L, activities=[
    @model.BotActivity::playing("Save the Oxford Comma"),
  ])
  json_inspect(presence, content={
    "status": "online",
    "activities": [{ "name": "Save the Oxford Comma", "type": 0 }],
    "afk": false,
    "since": 91879201,
  })
  json_inspect(@model.UpdatePresence(status=Invisible), content={
    "status": "invisible",
    "activities": [],
    "afk": false,
    "since": null,
  })
  assert_eq(@model.PresenceStatus::from_string("invisible"), Invisible)
  assert_eq(@model.PresenceStatus::from_string("future"), Unknown("future"))
  let request : @model.RequestGuildMembers = {
    guild_id: Id(41771983444115456UL),
    select: All,
    presences: false,
    nonce: None,
  }
  request.validate()
  json_inspect(request, content={
    "guild_id": "41771983444115456",
    "presences": false,
    "query": "",
    "limit": 0,
  })
  json_inspect(
    @model.RequestGuildMembers::{
      ..request,
      select: Prefix("ab", limit=100),
      nonce: Some("test"),
    },
    content={
      "guild_id": "41771983444115456",
      "presences": false,
      "query": "ab",
      "limit": 100,
      "nonce": "test",
    },
  )
  json_inspect(
    @model.RequestGuildMembers::{ ..request, select: Ids([Id(1UL)]), },
    content={
      "guild_id": "41771983444115456",
      "presences": false,
      "user_ids": ["1"],
    },
  )
  json_inspect(
    @model.RequestSoundboardSounds::{
      guild_ids: [Id(613425648685547541UL), Id(81384788765712384UL)],
    },
    content={ "guild_ids": ["613425648685547541", "81384788765712384"] },
  )
  json_inspect(
    @model.RequestChannelInfo::{
      guild_id: Id(613425648685547541UL),
      fields: [Status, VoiceStartTime, Other("future")],
    },
    content={
      "guild_id": "613425648685547541",
      "fields": ["status", "voice_start_time", "future"],
    },
  )
  assert_eq(@model.GatewayOpcode::from_int(43), RequestChannelInfo)
  assert_eq(@model.GatewayOpcode::RequestChannelInfo.to_int(), 43)
  assert_eq(@model.GatewayOpcode::RequestSoundboardSounds.to_int(), 31)
}

///|
test "bot activity constructors only encode sendable fields" {
  json_inspect(
    @model.BotActivity::streaming("live", "https://twitch.tv/example"),
    content={ "name": "live", "type": 1, "url": "https://twitch.tv/example" },
  )
  json_inspect(@model.BotActivity::listening("music"), content={
    "name": "music",
    "type": 2,
  })
  json_inspect(@model.BotActivity::watching("video"), content={
    "name": "video",
    "type": 3,
  })
  json_inspect(@model.BotActivity::custom("hello"), content={
    "name": "Custom Status",
    "type": 4,
    "state": "hello",
  })
  json_inspect(@model.BotActivity::competing("arena"), content={
    "name": "arena",
    "type": 5,
  })
}

///|
test "member request validates selection bounds and UTF-8 nonce bytes" {
  let base : @model.RequestGuildMembers = {
    guild_id: Id(1UL),
    select: All,
    presences: false,
    nonce: None,
  }
  for
    select in [
      @model.MemberSelect::Ids([]),
      Ids(Array::make(101, @model.UserId::Id(1UL))),
      Prefix("", limit=1),
      Prefix("a", limit=0),
      Prefix("a", limit=101),
    ] {
    try @model.RequestGuildMembers::{ ..base, select, }.validate() catch {
      @model.GatewayCommandError::InvalidCommand(_) => ()
    } noraise {
      _ => fail("invalid selection accepted")
    }
  }
  for
    select in [
      @model.MemberSelect::Ids([Id(1UL)]),
      Ids(Array::make(100, @model.UserId::Id(1UL))),
      Prefix("a", limit=1),
      Prefix("a", limit=100),
    ] {
    @model.RequestGuildMembers::{ ..base, select, }.validate()
  }
  // One case per UTF-8 width: 1-, 2-, 3- and 4-byte characters.
  for
    nonce in [
      "a".repeat(32),
      "é".repeat(16),
      "あ".repeat(10) + "aa",
      "😀".repeat(8),
    ] {
    @model.RequestGuildMembers::{ ..base, nonce: Some(nonce), }.validate()
    try
      @model.RequestGuildMembers::{ ..base, nonce: Some(nonce + "a"), }.validate()
    catch {
      @model.GatewayCommandError::InvalidCommand(violation) =>
        assert_eq(violation.path, "nonce")
    } noraise {
      _ => fail("33 UTF-8 bytes accepted for \{nonce}")
    }
  }
}
