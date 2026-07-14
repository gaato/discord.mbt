// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/entitlement.mdx
// Skipped blocks from this page:
// - line 87, Query String Params — query-parameter example.
// - line 112, Get Entitlement — verbatim duplicate of the entitlement fixture at line 36.
// - line 155, JSON Params — JSON request parameters.
// Page: developers/resources/sku.mdx
// Skipped blocks from this page: none.
// Page: developers/resources/subscription.mdx
// Skipped blocks from this page:
// - line 33, Subscription Example — covered by the gateway subscription dispatch fixture.

///|
test "discord docs: entitlement example (line 36)" {
  let fixture =
    #|{
    #|  "id": "1019653849998299136",
    #|  "sku_id": "1019475255913222144",
    #|  "application_id": "1019370614521200640",
    #|  "user_id": "771129655544643584",
    #|  "promotion_id": null,
    #|  "type": 8,
    #|  "deleted": false,
    #|  "gift_code_flags": 0,
    #|  "consumed": false,
    #|  "starts_at": "2022-09-14T17:00:18.704163+00:00",
    #|  "ends_at": "2022-10-14T17:00:18.704163+00:00",
    #|  "guild_id": "1015034326372454400",
    #|  "subscription_id": "1019653835926409216"
    #|}
  let first : @model.Entitlement = @json.from_json(@json.parse(fixture))
  let second : @model.Entitlement = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="1019653849998299136")
  inspect(first.typ.to_int(), content="8")
}

///|
test "discord docs: sku example (line 30)" {
  let fixture =
    #|{
    #|  "id": "1088510058284990888",
    #|  "type": 5,
    #|  "dependent_sku_id": null,
    #|  "application_id": "788708323867885999",
    #|  "manifest_labels": null,
    #|  "access_type": 1,
    #|  "name": "Test Premium",
    #|  "features": [],
    #|  "release_date": null,
    #|  "premium": false,
    #|  "slug": "test-premium",
    #|  "flags": 128,
    #|  "show_age_gate": false
    #|}
  let first : @model.Sku = @json.from_json(@json.parse(fixture))
  let second : @model.Sku = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="1088510058284990888")
  inspect(first.typ.to_int(), content="5")
}

///|
test "discord docs: list skus (line 85)" {
  let fixture =
    #|[
    #|  {
    #|    "id": "1088510053843210999",
    #|    "type": 6,
    #|    "dependent_sku_id": null,
    #|    "application_id": "788708323867885999",
    #|    "manifest_labels": null,
    #|    "access_type": 1,
    #|    "name": "Test Premium",
    #|    "features": [],
    #|    "release_date": null,
    #|    "premium": false,
    #|    "slug": "test-premium",
    #|    "flags": 128,
    #|    "show_age_gate": false
    #|  },
    #|  {
    #|    "id": "1088510058284990888",
    #|    "type": 5,
    #|    "dependent_sku_id": null,
    #|    "application_id": "788708323867885999",
    #|    "manifest_labels": null,
    #|    "access_type": 1,
    #|    "name": "Test Premium",
    #|    "features": [],
    #|    "release_date": null,
    #|    "premium": false,
    #|    "slug": "test-premium",
    #|    "flags": 128,
    #|    "show_age_gate": false
    #|  }
    #|]
  let first : Array[@model.Sku] = @json.from_json(@json.parse(fixture))
  let second : Array[@model.Sku] = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.length(), content="2")
  inspect(first[0].typ.to_int(), content="6")
}
