///|
test "voice_on_close classifies every documented policy group" {
  let fatal_codes = [
    4001, 4002, 4003, 4004, 4005, 4011, 4012, 4014, 4016, 4020, 4021, 4022,
  ]
  for code in fatal_codes {
    assert_eq(@voice.voice_on_close(Some(code), true), Fatal)
  }
  for code in [4006, 4009, 1000, 1001] {
    assert_eq(@voice.voice_on_close(Some(code), true), Rejoin)
  }
  for code in [4015, 4000, 1006] {
    assert_eq(@voice.voice_on_close(Some(code), true), Resume)
  }
  assert_eq(@voice.voice_on_close(None, true), Resume)
  // There is no session to resume before Session Description.
  assert_eq(@voice.voice_on_close(Some(4015), false), Rejoin)
}
