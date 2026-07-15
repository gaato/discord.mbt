///|
test "reorder buffer passes contiguous packets through" {
  let reorder = @voice.ReorderBuffer::new()
  assert_eq(reorder.push(seq=10, arrival_ms=0L, "a"), [Deliver("a")])
  assert_eq(reorder.push(seq=11, arrival_ms=1L, "b"), [Deliver("b")])
}

///|
test "reorder buffer restores an adjacent swap" {
  let reorder = @voice.ReorderBuffer::new()
  reorder.push(seq=10, arrival_ms=0L, "a") |> ignore
  assert_eq(reorder.push(seq=12, arrival_ms=1L, "c"), [])
  assert_eq(reorder.push(seq=11, arrival_ms=2L, "b"), [
    Deliver("b"),
    Deliver("c"),
  ])
}

///|
test "reorder buffer reports a held gap after sixty milliseconds" {
  let reorder = @voice.ReorderBuffer::new()
  reorder.push(seq=10, arrival_ms=0L, "a") |> ignore
  assert_eq(reorder.push(seq=12, arrival_ms=5L, "c"), [])
  assert_eq(reorder.push(seq=13, arrival_ms=65L, "d"), [
    Lost(count=1),
    Deliver("c"),
    Deliver("d"),
  ])
}

///|
test "reorder buffer compares sequence numbers across u16 wraparound" {
  let reorder = @voice.ReorderBuffer::new()
  assert_eq(reorder.push(seq=65535, arrival_ms=0L, "last"), [Deliver("last")])
  assert_eq(reorder.push(seq=1, arrival_ms=1L, "one"), [])
  assert_eq(reorder.push(seq=0, arrival_ms=2L, "zero"), [
    Deliver("zero"),
    Deliver("one"),
  ])
}

///|
test "reorder buffer silently drops duplicate packets" {
  let reorder = @voice.ReorderBuffer::new()
  reorder.push(seq=20, arrival_ms=0L, "first") |> ignore
  assert_eq(reorder.push(seq=20, arrival_ms=1L, "duplicate"), [])
  assert_eq(reorder.push(seq=22, arrival_ms=2L, "future"), [])
  assert_eq(reorder.push(seq=22, arrival_ms=3L, "duplicate future"), [])
}

///|
test "reorder buffer flushes when its eight-packet window fills" {
  let reorder = @voice.ReorderBuffer::new(hold_ms=1000)
  reorder.push(seq=1, arrival_ms=0L, 1) |> ignore
  for sequence in 3..<10 {
    assert_eq(reorder.push(seq=sequence, arrival_ms=1L, sequence), [])
  }
  assert_eq(reorder.push(seq=10, arrival_ms=1L, 10), [
    Lost(count=1),
    Deliver(3),
    Deliver(4),
    Deliver(5),
    Deliver(6),
    Deliver(7),
    Deliver(8),
    Deliver(9),
    Deliver(10),
  ])
}
