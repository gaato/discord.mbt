///|
test "sticker decodes a full fixture" {
  let fixture =
    #|{
    #|  "id": "749054660769218631",
    #|  "name": "Wave",
    #|  "description": null,
    #|  "tags": "wave",
    #|  "asset": "",
    #|  "type": 2,
    #|  "format_type": 1,
    #|  "available": true,
    #|  "guild_id": "81384788765712384",
    #|  "user": {
    #|    "id": "80351110224678912",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": null,
    #|    "avatar": null
    #|  },
    #|  "brand_new_field_from_discord": true
    #|}
  let sticker : @model.Sticker = @json.from_json(@json.parse(fixture))
  debug_inspect(
    sticker,
    content=(
      #|{
      #|  id: 749054660769218631,
      #|  pack_id: None,
      #|  name: "Wave",
      #|  description: Null,
      #|  tags: "wave",
      #|  asset: Some(""),
      #|  typ: Guild,
      #|  format_type: Png,
      #|  available: Some(true),
      #|  guild_id: Some(81384788765712384),
      #|  user: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Some(Null),
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
      #|  sort_value: None,
      #|}
    ),
  )
}

///|
test "sticker decodes required fields only" {
  let fixture =
    #|{
    #|  "id": "749054660769218631",
    #|  "name": "Wave",
    #|  "description": "A friendly wave",
    #|  "tags": "wave, hello",
    #|  "type": 1,
    #|  "format_type": 3
    #|}
  let sticker : @model.Sticker = @json.from_json(@json.parse(fixture))
  debug_inspect(
    sticker,
    content=(
      #|{
      #|  id: 749054660769218631,
      #|  pack_id: None,
      #|  name: "Wave",
      #|  description: Value("A friendly wave"),
      #|  tags: "wave, hello",
      #|  asset: None,
      #|  typ: Standard,
      #|  format_type: Lottie,
      #|  available: None,
      #|  guild_id: None,
      #|  user: None,
      #|  sort_value: None,
      #|}
    ),
  )
}

///|
test "sticker encode omits absent optional fields" {
  let sticker : @model.Sticker = {
    id: Id(1UL),
    pack_id: None,
    name: "Wave",
    description: Null,
    tags: "wave, hello",
    asset: None,
    typ: Standard,
    format_type: Png,
    available: None,
    guild_id: None,
    user: None,
    sort_value: None,
  }
  inspect(
    sticker.to_json().stringify(),
    content=(
      #|{"id":"1","name":"Wave","description":null,"tags":"wave, hello","type":1,"format_type":1}
    ),
  )
}

///|
test "sticker wire enums preserve unknown values" {
  let known : @model.StickerType = @json.from_json(@json.parse("2"))
  debug_inspect(
    known,
    content=(
      #|Guild
    ),
  )
  let unknown_type : @model.StickerType = @json.from_json(@json.parse("99"))
  debug_inspect(
    unknown_type,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    unknown_type.to_json().stringify(),
    content=(
      #|99
    ),
  )
  let unknown_format : @model.StickerFormatType = @json.from_json(
    @json.parse("98"),
  )
  debug_inspect(
    unknown_format,
    content=(
      #|Unknown(98)
    ),
  )
  inspect(
    unknown_format.to_json().stringify(),
    content=(
      #|98
    ),
  )
  let round_trip : @model.StickerFormatType = @json.from_json(
    unknown_format.to_json(),
  )
  assert_true(round_trip == unknown_format)
}

///|
test "sticker item and pack decode their complete shapes" {
  let item : @model.StickerItem = @json.from_json(
    @json.parse(
      (
        #|{
        #|  "id": "749054660769218631",
        #|  "name": "Wave",
        #|  "format_type": 1,
        #|  "brand_new_field_from_discord": true
        #|}
      ),
    ),
  )
  debug_inspect(
    item,
    content=(
      #|{ id: 749054660769218631, name: "Wave", format_type: Png }
    ),
  )
  let pack : @model.StickerPack = @json.from_json(
    @json.parse(
      (
        #|{
        #|  "id": "847199849233514549",
        #|  "stickers": [{
        #|    "id": "749054660769218631",
        #|    "pack_id": "847199849233514549",
        #|    "name": "Wave",
        #|    "description": "A friendly wave",
        #|    "tags": "wave, hello",
        #|    "type": 1,
        #|    "format_type": 1,
        #|    "sort_value": 12
        #|  }],
        #|  "name": "Wumpus Beyond",
        #|  "sku_id": "1144058844004233369",
        #|  "cover_sticker_id": "749054660769218631",
        #|  "description": "Wumpus explores the stars",
        #|  "banner_asset_id": "761773777170071552",
        #|  "brand_new_field_from_discord": true
        #|}
      ),
    ),
  )
  debug_inspect(
    pack,
    content=(
      #|{
      #|  id: 847199849233514549,
      #|  stickers: [
      #|    {
      #|      id: 749054660769218631,
      #|      pack_id: Some(847199849233514549),
      #|      name: "Wave",
      #|      description: Value("A friendly wave"),
      #|      tags: "wave, hello",
      #|      asset: None,
      #|      typ: Standard,
      #|      format_type: Png,
      #|      available: None,
      #|      guild_id: None,
      #|      user: None,
      #|      sort_value: Some(12),
      #|    },
      #|  ],
      #|  name: "Wumpus Beyond",
      #|  sku_id: 1144058844004233369,
      #|  cover_sticker_id: Some(749054660769218631),
      #|  description: "Wumpus explores the stars",
      #|  banner_asset_id: Some(761773777170071552),
      #|}
    ),
  )
}
