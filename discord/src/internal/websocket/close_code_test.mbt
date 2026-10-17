///|
test "close codes round-trip through their numeric form" {
  for
    code in [
      1000, 1001, 1002, 1003, 1006, 1007, 1008, 1009, 1010, 1011, 1005, 3000, 4000,
      4014,
    ] {
    assert_eq(
      @websocket.close_code_to_int(@websocket.close_code_from_int(code)),
      code,
    )
  }
}
