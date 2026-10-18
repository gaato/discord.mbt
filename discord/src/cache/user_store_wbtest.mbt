///|
fn describe_move(move : UserMove) -> String {
  match move {
    Promote => "promote"
    Keep => "keep"
    Drop => "drop"
    Stray => "stray"
  }
}

///|
test "user_move decides each holder-count transition" {
  let cases : Array[(Int32, UserStep, String)] = [
    (0, Hold, "promote"),
    (1, Hold, "keep"),
    (5, Hold, "keep"),
    (0, Release, "stray"),
    (1, Release, "drop"),
    (2, Release, "keep"),
  ]
  for case in cases {
    let (count, step, expected) = case
    let step_name = match step {
      Hold => "hold"
      Release => "release"
    }
    assert_eq(
      (count, step_name, describe_move(user_move(count, step))),
      (count, step_name, expected),
    )
  }
}

///|
fn store_user(id : String, name : String) -> @model.User raise {
  @json.from_json(
    @json.parse(
      "{\"id\":\"\{id}\",\"username\":\"\{name}\",\"discriminator\":\"0\",\"avatar\":null}",
    ),
  )
}

///|
/// Where the store keeps user `id`, and its holder count.
fn placement(store : UserStore, id : String) -> String raise {
  let user_id : @model.UserId = @model.Id::parse(id)
  let held = store.held_.entries_.contains(user_id)
  let recent = store.recent_.entries_.contains(user_id)
  let count = store.counts_.get(user_id).unwrap_or(0)
  let name = store.get(user_id).map(user => user.username).unwrap_or("-")
  "held=\{held} recent=\{recent} count=\{count} name=\{name}"
}

///|
test "user store moves users between held and recent by their holders" {
  let store = UserStore::new(
    enabled=true,
    held=CacheLimit(),
    recent=CacheLimit(max_entries=2),
    now=() => 0L,
  )
  let user_id : @model.UserId = @model.Id::parse("1")
  let steps : Array[(String, () -> Unit raise, String)] = [
    (
      "seen without a holder",
      () => store.see(store_user("1", "a")),
      "held=false recent=true count=0 name=a",
    ),
    (
      "first holder promotes",
      () => store.hold(store_user("1", "b")),
      "held=true recent=false count=1 name=b",
    ),
    (
      "second holder",
      () => store.hold(store_user("1", "c")),
      "held=true recent=false count=2 name=c",
    ),
    (
      "a sighting refreshes the held view",
      () => store.see(store_user("1", "d")),
      "held=true recent=false count=2 name=d",
    ),
    (
      "one of two holders lets go",
      () => store.release(user_id),
      "held=true recent=false count=1 name=d",
    ),
    (
      "the last holder lets go",
      () => store.release(user_id),
      "held=false recent=false count=0 name=-",
    ),
    (
      "a stray release is ignored",
      () => store.release(user_id),
      "held=false recent=false count=0 name=-",
    ),
  ]
  for step in steps {
    let (name, run, expected) = step
    run()
    assert_eq((name, placement(store, "1")), (name, expected))
  }
  // The recent users are least recently seen first out.
  for id in ["2", "3", "4"] {
    store.see(store_user(id, id))
  }
  assert_eq(store.values().map(user => user.id.to_string()), ["3", "4"])
}

///|
test "a disabled user store keeps nothing" {
  let store = UserStore::new(
    enabled=false,
    held=CacheLimit(),
    recent=CacheLimit(),
    now=() => 0L,
  )
  store.hold(store_user("1", "a"))
  store.see(store_user("2", "b"))
  store.release(@model.Id::parse("1"))
  assert_eq(store.values().length(), 0)
  assert_eq(store.counts_.length(), 0)
}
