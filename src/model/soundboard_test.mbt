///|
test "soundboard sound decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "name":"Airhorn","sound_id":"126000000000000001","volume":0.75,
    #|  "emoji_id":null,"emoji_name":"📣","guild_id":"81384788765712384",
    #|  "available":true,
    #|  "user":{"id":"80351110224678912","username":"Nelly","discriminator":"0","global_name":null,"avatar":null},
    #|  "future":true
    #|}
  let sound : @model.SoundboardSound = @json.from_json(@json.parse(fixture))
  debug_inspect(
    sound,
    content=(
      #|{
      #|  name: "Airhorn",
      #|  sound_id: 126000000000000001,
      #|  volume: 0.75,
      #|  emoji_id: Null,
      #|  emoji_name: Value("📣"),
      #|  guild_id: Some(81384788765712384),
      #|  available: true,
      #|  user: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Null,
      #|      avatar: Null,
      #|      bot: None,
      #|      system: None,
      #|      mfa_enabled: None,
      #|      banner: None,
      #|      accent_color: None,
      #|      locale: None,
      #|      verified: None,
      #|      email: None,
      #|      flags: None,
      #|      premium_type: None,
      #|      public_flags: None,
      #|      avatar_decoration: None,
      #|      avatar_decoration_data: None,
      #|    },
      #|  ),
      #|}
    ),
  )
}

///|
test "soundboard sound round-trips nullable wire values" {
  let fixture =
    #|{"name":"Default","sound_id":"1","volume":1.0,"emoji_id":null,"emoji_name":null,"available":false}
  let sound : @model.SoundboardSound = @json.from_json(@json.parse(fixture))
  inspect(
    sound.to_json().stringify(),
    content=(
      #|{"name":"Default","sound_id":"1","volume":1,"emoji_id":null,"emoji_name":null,"available":false}
    ),
  )
}
