///|
test "JavaScript reports native DAVE as unavailable" {
  assert_false(@dave.available())
  assert_eq(@dave.max_supported_protocol_version(), 0)
  assert_eq(
    @dave.unavailable_reason(),
    Some("libdave is unavailable on the JavaScript backend"),
  )
}

///|
test "JavaScript rejects native handle construction safely" {
  try
    @dave.Session::new(protocol_version=1, group_id=42UL, self_user_id=100UL)
  catch {
    @dave.DaveError::LibraryUnavailable(reason~) =>
      assert_true(reason.contains("JavaScript backend"))
    _ => fail("unexpected JavaScript Session error")
  } noraise {
    _ => fail("expected JavaScript Session construction to fail")
  }
  try @dave.Encryptor::new() catch {
    @dave.DaveError::LibraryUnavailable(reason~) =>
      assert_true(reason.contains("JavaScript backend"))
    _ => fail("unexpected JavaScript Encryptor error")
  } noraise {
    _ => fail("expected JavaScript Encryptor construction to fail")
  }
  try @dave.Decryptor::new() catch {
    @dave.DaveError::LibraryUnavailable(reason~) =>
      assert_true(reason.contains("JavaScript backend"))
    _ => fail("unexpected JavaScript Decryptor error")
  } noraise {
    _ => fail("expected JavaScript Decryptor construction to fail")
  }
}
