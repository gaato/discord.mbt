///|
test "handler errors raised by user code keep their meaning through decoding" {
  let kept : Array[HandlerError] = [
    UserMessage(message="hi", ephemeral=true),
    GuildOnly,
    DmOnly,
    CheckFailed,
    MissingPermission(@model.Permissions::from_bits(8)),
    OnCooldown(retry_after_ms=1000),
    InvalidInput(name=Some("n"), message="bad"),
    Malformed(reason="stale"),
    UnsupportedResponse(reason="no message to update"),
  ]
  for error in kept {
    assert_eq(
      Repr(malformed_unless_handler_error(error)).to_string(),
      Repr(error).to_string(),
    )
  }
  assert_true(
    malformed_unless_handler_error(Failure::Failure("boom")) is Malformed(_),
  )
}
