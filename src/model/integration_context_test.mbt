///|
test "application integration types round-trip" {
  let values : Array[@model.ApplicationIntegrationType] = [
    GuildInstall,
    UserInstall,
    Unknown(99),
  ]
  for value in values {
    let decoded : @model.ApplicationIntegrationType = @json.from_json(
      value.to_json(),
    )
    assert_true(decoded == value)
    assert_true(
      @model.ApplicationIntegrationType::from_int(value.to_int()) == value,
    )
  }
  inspect(Json(values).stringify(), content="[0,1,99]")
}

///|
test "interaction context types round-trip" {
  let values : Array[@model.InteractionContextType] = [
    Guild,
    BotDm,
    PrivateChannel,
    Unknown(99),
  ]
  for value in values {
    let decoded : @model.InteractionContextType = @json.from_json(
      value.to_json(),
    )
    assert_true(decoded == value)
    assert_true(
      @model.InteractionContextType::from_int(value.to_int()) == value,
    )
  }
  inspect(Json(values).stringify(), content="[0,1,2,99]")
}
