///|
/// Live-API shape observed 2026-07-16: the guild soundboard listing wraps the
/// array in an `items` envelope, unlike the default-sound listing.
async test "guild soundboard listing unwraps the items envelope" {
  let (client, perform) = offline_test_client()
  defer client.close()
  perform.val = Some((_route, _path, _headers, _body, _files) => {
    let body : Json = {
      "items": [
        {
          "name": "probe-sound",
          "sound_id": "1527264515534622800",
          "volume": 0.5,
          "emoji_id": Json::null(),
          "emoji_name": "🔔",
          "guild_id": "300",
          "available": true,
        },
      ],
    }
    { status: 200, headers: Map([]), body, }
  })
  let guild_id : @model.GuildId = Id(300UL)
  let sounds = client.list_guild_soundboard_sounds(guild_id)
  inspect(sounds.length(), content="1")
  inspect(sounds[0].name, content="probe-sound")
}

///|
async test "default soundboard listing decodes a bare array" {
  let (client, perform) = offline_test_client()
  defer client.close()
  perform.val = Some((_route, _path, _headers, _body, _files) => {
    let body : Json = [
      {
        "name": "quack",
        "sound_id": "1",
        "volume": 1.0,
        "emoji_id": Json::null(),
        "emoji_name": "🦆",
        "available": true,
      },
    ]
    { status: 200, headers: Map([]), body, }
  })
  let sounds = client.list_default_soundboard_sounds()
  inspect(sounds.length(), content="1")
}
