///|
test "Wasm reports native DAVE as unavailable" {
  assert_false(@dave.available())
  assert_eq(@dave.max_supported_protocol_version(), 0)
  assert_eq(
    @dave.unavailable_reason(),
    Some("libdave is unavailable on the Wasm backend"),
  )
}

///|
test "Wasm rejects native handle construction safely" {
  try
    @dave.Session::new(protocol_version=1, group_id=42UL, self_user_id=100UL)
  catch {
    @dave.DaveError::LibraryUnavailable(reason~) =>
      assert_true(reason.contains("Wasm backend"))
    _ => fail("unexpected Wasm Session error")
  } noraise {
    _ => fail("expected Wasm Session construction to fail")
  }
  try @dave.Encryptor::new() catch {
    @dave.DaveError::LibraryUnavailable(reason~) =>
      assert_true(reason.contains("Wasm backend"))
    _ => fail("unexpected Wasm Encryptor error")
  } noraise {
    _ => fail("expected Wasm Encryptor construction to fail")
  }
  try @dave.Decryptor::new() catch {
    @dave.DaveError::LibraryUnavailable(reason~) =>
      assert_true(reason.contains("Wasm backend"))
    _ => fail("unexpected Wasm Decryptor error")
  } noraise {
    _ => fail("expected Wasm Decryptor construction to fail")
  }
}
