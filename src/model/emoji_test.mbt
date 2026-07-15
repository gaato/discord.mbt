///|
test "emoji decodes a full fixture" {
  let fixture =
    #|{
    #|  "id": "41771983429993937",
    #|  "name": "LUL",
    #|  "animated": true,
    #|  "roles": ["41771983423143936"],
    #|  "user": {
    #|    "id": "80351110224678912",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "require_colons": true,
    #|  "managed": false,
    #|  "available": true,
    #|  "brand_new_field_from_discord": true
    #|}
  let emoji : @model.Emoji = @json.from_json(@json.parse(fixture))
  debug_inspect(
    emoji,
    content=(
      #|{
      #|  id: Some(Value(41771983429993937)),
      #|  name: Value("LUL"),
      #|  animated: Some(true),
      #|  roles: Some([41771983423143936]),
      #|  user: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Some(Value("Nelly")),
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
      #|      collectibles: None,
      #|      primary_guild: None,
      #|    },
      #|  ),
      #|  require_colons: Some(true),
      #|  managed: Some(false),
      #|  available: Some(true),
      #|}
    ),
  )
}

///|
test "emoji decodes required nullable fields only" {
  let emoji : @model.Emoji = @json.from_json(
    @json.parse(
      (
        #|{
        #|  "id": null,
        #|  "name": null
        #|}
      ),
    ),
  )
  debug_inspect(
    emoji,
    content=(
      #|{
      #|  id: Some(Null),
      #|  name: Null,
      #|  animated: None,
      #|  roles: None,
      #|  user: None,
      #|  require_colons: None,
      #|  managed: None,
      #|  available: None,
      #|}
    ),
  )
}

///|
test "emoji encode omits absent optional fields" {
  let emoji : @model.Emoji = {
    id: Some(Null),
    name: Value("wave"),
    animated: None,
    roles: None,
    user: None,
    require_colons: None,
    managed: None,
    available: None,
  }
  inspect(
    emoji.to_json().stringify(),
    content=(
      #|{"id":null,"name":"wave"}
    ),
  )
}
