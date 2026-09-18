// Source: Discord Developer Documentation, fetched 2026-09-19.
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/application-identity-profile
// Skipped blocks from this page: none.

///|
test "discord docs: example application identity profile object" {
  let fixture =
    #|{
    #|  "username": "johndoe123",
    #|  "metadata": null,
    #|  "data": {
    #|    "primary": {
    #|      "season": "Season 3",
    #|      "rank_name": "Silver",
    #|      "rank_image": {"url": "https://example.com/assets/rank-images/silver.png"},
    #|      "highest_rank": "Platinum",
    #|      "highest_rank_image": {"url": "https://example.com/assets/rank-images/platinum.png"},
    #|      "featured_played_character": "John Doe",
    #|      "featured_played_character_image": {"url": "https://example.com/assets/character-images/john-doe.png"},
    #|      "playtime_hours": 69.41,
    #|      "total_wins": 57,
    #|      "current_period_wins": 8,
    #|      "total_games": 100,
    #|      "current_period_games": 10,
    #|      "total_kills": 253,
    #|      "current_period_kills": 35,
    #|      "total_assists": 478,
    #|      "current_period_assists": 68,
    #|      "total_deaths": 561,
    #|      "current_period_deaths": 21
    #|    },
    #|    "dynamic": [
    #|      {"type": 1, "name": "my_string", "value": "hello"},
    #|      {"type": 2, "name": "my_number", "value": 123.45},
    #|      {"type": 3, "name": "my_media", "value": {"url": "https://example.com/some-media.png"}}
    #|    ]
    #|  }
    #|}
  let first : @model.ApplicationIdentityProfile = @json.from_json(
    @json.parse(fixture),
  )
  let second : @model.ApplicationIdentityProfile = @json.from_json(
    ToJson::to_json(first),
  )
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  assert_true(first.username == Value("johndoe123"))
  assert_true(first.metadata is Null)
  guard first.data is Value({ primary: Some(primary), dynamic: Some(dynamic), }) else {
    fail("expected complete profile data")
  }
  assert_eq(primary.total_wins, Some(57))
  assert_eq(dynamic.length(), 3)
  assert_true(dynamic[0] is StringField(_))
  assert_true(dynamic[1] is NumberField(_))
  assert_true(dynamic[2] is MediaField(_))
}

///|
test "discord docs: application identities response envelope" {
  let fixture =
    #|{
    #|  "identities": [
    #|    {
    #|      "user_id": "80351110224678912",
    #|      "provider_type": "steam",
    #|      "provider_id": "pc",
    #|      "provider_issued_user_id": "76561198000000000"
    #|    }
    #|  ]
    #|}
  guard @json.parse(fixture) is { "identities": items, .. } else {
    fail("expected the identities envelope")
  }
  let response : Array[@model.ApplicationIdentity] = @json.from_json(items)
  assert_eq(response.length(), 1)
  assert_eq(
    response[0].user_id.map(id => id.to_string()),
    Some("80351110224678912"),
  )
  assert_eq(response[0].provider_type, "steam")
  let round_trip : Array[@model.ApplicationIdentity] = @json.from_json(
    ToJson::to_json(response),
  )
  assert_eq("\{Repr(response)}", "\{Repr(round_trip)}")
}

///|
test "unknown dynamic application identity fields round trip unchanged" {
  let fixture : Json = { "type": 99, "name": "future", "value": { "x": true } }
  let field : @model.ApplicationIdentityDynamicField = @json.from_json(fixture)
  assert_true(field is Unknown(_))
  assert_eq(ToJson::to_json(field), fixture)
}
