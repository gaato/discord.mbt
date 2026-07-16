///|
test "application role connection metadata round-trips a docs-shaped fixture" {
  let fixture =
    #|[{
    #|  "type": 2,
    #|  "key": "cookieseaten",
    #|  "name": "Cookies Eaten",
    #|  "name_localizations": {"de": "Gegessene Kekse"},
    #|  "description": "The number of cookies eaten",
    #|  "description_localizations": {"de": "Die Anzahl gegessener Kekse"}
    #|}]
  let first : Array[@model.ApplicationRoleConnectionMetadata] = @json.from_json(
    @json.parse(fixture),
  )
  let second : Array[@model.ApplicationRoleConnectionMetadata] = @json.from_json(
    first.to_json(),
  )
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(
    first.to_json().stringify(),
    content=(
      #|[{"type":2,"key":"cookieseaten","name":"Cookies Eaten","name_localizations":{"de":"Gegessene Kekse"},"description":"The number of cookies eaten","description_localizations":{"de":"Die Anzahl gegessener Kekse"}}]
    ),
  )
}

///|
test "application role connection metadata types preserve wire values" {
  let types : Array[@model.ApplicationRoleConnectionMetadataType] = [
    IntegerLessThanOrEqual,
    IntegerGreaterThanOrEqual,
    IntegerEqual,
    IntegerNotEqual,
    DatetimeLessThanOrEqual,
    DatetimeGreaterThanOrEqual,
    BooleanEqual,
    BooleanNotEqual,
  ]
  for index, typ in types {
    let value = index + 1
    assert_eq(typ.to_int(), value)
    assert_true(
      @model.ApplicationRoleConnectionMetadataType::from_int(value) == typ,
    )
  }
  assert_true(
    @model.ApplicationRoleConnectionMetadataType::from_int(99) == Unknown(99),
  )
}
