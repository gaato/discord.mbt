// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/sticker.mdx
// Skipped blocks from this page: none.

///|
test "discord docs: example sticker (line 56)" {
  let fixture =
    #|{
    #|  "id": "749054660769218631",
    #|  "name": "Wave",
    #|  "tags": "wumpus, hello, sup, hi, oi, heyo, heya, yo, greetings, greet, welcome, wave, :wave, :hello, :hi, :hey, hey, \ud83d\udc4b, \ud83d\udc4b\ud83c\udffb, \ud83d\udc4b\ud83c\udffc, \ud83d\udc4b\ud83c\udffd, \ud83d\udc4b\ud83c\udffe, \ud83d\udc4b\ud83c\udfff, goodbye, bye, see ya, later, laterz, cya",
    #|  "type": 1,
    #|  "format_type": 3,
    #|  "description": "Wumpus waves hello",
    #|  "pack_id": "847199849233514549",
    #|  "sort_value": 12
    #|}
  let first : @model.Sticker = @json.from_json(@json.parse(fixture))
  let second : @model.Sticker = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="749054660769218631")
  inspect(first.format_type.to_int(), content="3")
}

///|
test "discord docs: example sticker pack (line 101)" {
  let fixture =
    #|{
    #|  "id": "847199849233514549",
    #|  "stickers": [],
    #|  "name": "Wumpus Beyond",
    #|  "sku_id": "847199849233514547",
    #|  "cover_sticker_id": "749053689419006003",
    #|  "description": "Say hello to Wumpus!",
    #|  "banner_asset_id": "761773777976819732"
    #|}
  let first : @model.StickerPack = @json.from_json(@json.parse(fixture))
  let second : @model.StickerPack = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="847199849233514549")
  assert_eq(first.name, "Wumpus Beyond")
}

///|
test "discord docs: list sticker packs response envelope" {
  let fixture =
    #|{"sticker_packs":[{"id":"847199849233514549","stickers":[],"name":"Wumpus Beyond","sku_id":"847199849233514547","cover_sticker_id":"749053689419006003","description":"Say hello to Wumpus!","banner_asset_id":"761773777976819732"}]}
  let response : @model.StickerPacksResponse = @json.from_json(
    @json.parse(fixture),
  )
  assert_eq(response.sticker_packs.length(), 1)
  inspect(response.sticker_packs[0].name, content="Wumpus Beyond")
}
