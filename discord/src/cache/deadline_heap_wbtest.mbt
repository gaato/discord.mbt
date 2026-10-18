///|
test "the deadline heap pops due owners earliest first" {
  let heap : DeadlineHeap[String] = DeadlineHeap::new()
  for item in [(30L, "c"), (10L, "a"), (50L, "e"), (20L, "b"), (40L, "d")] {
    heap.push(item.0, item.1)
  }
  let popped = []
  while heap.pop_due(35L) is Some(owner) {
    popped.push(owner)
  }
  assert_eq(popped, ["a", "b", "c"])
  assert_eq(heap.length(), 2)
  assert_true(heap.pop_due(39L) is None)
  assert_eq(heap.pop_due(100L), Some("d"))
  assert_eq(heap.pop_due(100L), Some("e"))
  assert_true(heap.pop_due(100L) is None)
}

///|
test "a churning bucket keeps the deadline index bounded" {
  let now = Ref(0L)
  let buckets : Buckets[Int32, Int32, Int32] = Buckets::new(
    CacheLimit(ttl_ms=1_000_000L),
    () => now.val,
  )
  for i in 0..<1000 {
    buckets.put(1, i, i) |> ignore
    buckets.remove(1, i)
    now.val += 1L
  }
  buckets.put(2, 0, 0) |> ignore
  assert_true(buckets.due_.length() <= 2 * buckets.buckets_.length() + 16)
  // The live bucket is still indexed, and expires on time.
  now.val += 1_000_000L
  buckets.expire()
  assert_eq(buckets.buckets_.length(), 0)
}
