///|
async test "unknown bucket admits immediately" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("unknown", global_exempt=false)
  limiter.release("unknown", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
}

///|
async test "exhausted bucket waits 1500 ms for Discord reset-after" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=200,
    headers=@http.Headers::of([
      ("x-ratelimit-remaining", "0"),
      ("x-ratelimit-reset-after", "1.5"),
    ]),
  )
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [1500])
}

///|
async test "remaining budget admits without waiting" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=200,
    headers=@http.Headers::of([
      ("x-ratelimit-remaining", "3"),
      ("x-ratelimit-reset-after", "60"),
    ]),
  )
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
}

///|
async test "global 429 blocks another bucket but exempts interaction routes" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::of([
      ("x-ratelimit-global", "true"),
      ("retry-after", "1.5"),
    ]),
  )
  limiter.acquire("interaction", global_exempt=true)
  limiter.release("interaction", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
  limiter.acquire("other", global_exempt=false)
  limiter.release("other", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [1500])
}

///|
async test "route 429 exhausts only its bucket" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::of([
      ("x-ratelimit-scope", "user"),
      ("retry-after", "0.08"),
    ]),
  )
  limiter.acquire("other", global_exempt=false)
  limiter.release("other", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [80])
}

///|
async test "a 429 without Retry-After waits one second on its bucket" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=true)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::of([("x-ratelimit-scope", "user")]),
  )
  limiter.acquire("bucket", global_exempt=true)
  limiter.release("bucket", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [1000])
}

///|
async test "the default global window delays the 51st non-exempt acquire" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  for _ in 0..<50 {
    limiter.acquire("bucket", global_exempt=false)
    limiter.release("bucket", status=200, headers=@http.Headers::empty())
  }
  limiter.acquire("interaction", global_exempt=true)
  limiter.release("interaction", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [1000])
}

///|
async test "a global-scope 429 blocks every non-exempt bucket" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::of([
      ("x-ratelimit-scope", "global"),
      ("content-type", "application/json"),
      ("retry-after", "2"),
    ]),
  )
  limiter.acquire("interaction", global_exempt=true)
  limiter.release("interaction", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
  limiter.acquire("other", global_exempt=false)
  limiter.release("other", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [2000])
}

///|
async test "a shared-scope 429 records the bucket's headers and blocks nothing" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::of([
      ("x-ratelimit-scope", "shared"),
      ("x-ratelimit-remaining", "2"),
      ("x-ratelimit-reset-after", "5"),
      ("retry-after", "30"),
    ]),
  )
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::empty())
  limiter.acquire("other", global_exempt=false)
  limiter.release("other", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
  assert_eq(limiter.state("bucket").map(state => state.remaining), Some(1))
}

///|
async test "a 429 that is not Discord's blocks every non-exempt bucket" {
  // No X-RateLimit-Scope and no JSON: Cloudflare's, which bans the address.
  for
    index, headers in [
      [("content-type", "text/html")],
      [],
      [("content-type", "text/plain"), ("retry-after", "3")],
    ] {
    let clock = @mock.FakeClock::new()
    let limiter = @ratelimit.rate_limiter(clock~)
    limiter.acquire("bucket", global_exempt=false)
    limiter.release("bucket", status=429, headers=@http.Headers::of(headers))
    limiter.acquire("interaction", global_exempt=true)
    limiter.release("interaction", status=200, headers=@http.Headers::empty())
    limiter.acquire("other", global_exempt=false)
    limiter.release("other", status=200, headers=@http.Headers::empty())
    let expected = if headers.length() == 2 { [3000] } else { [1000] }
    assert_eq(clock.slept(), expected, msg="case \{index}")
  }
  // A JSON 429 without a scope stays on its bucket.
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::of([
      ("content-type", "application/json; charset=utf-8"),
    ]),
  )
  limiter.acquire("other", global_exempt=false)
  limiter.release("other", status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [])
}

///|
/// The headers of a 200 that leaves `remaining` requests in Discord's bucket
/// `hash`, resetting in 1.5 s.
fn bucket_headers(hash : String, remaining : String) -> @http.Headers {
  @http.Headers::of([
    ("x-ratelimit-bucket", hash),
    ("x-ratelimit-remaining", remaining),
    ("x-ratelimit-reset-after", "1.5"),
  ])
}

///|
async test "routes that Discord counts in one bucket share its state" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  let list = "GET:/channels/1/messages"
  let fetch = "GET:/channels/1/messages/{}"
  let other_channel = "GET:/channels/2/messages"
  // Each route learns the hash from its own first response.
  for bucket in [list, fetch, other_channel] {
    limiter.acquire(bucket, global_exempt=false)
    limiter.release(bucket, status=200, headers=bucket_headers("abc", "5"))
  }
  assert_eq(clock.slept(), [])
  // The window of hash abc in channel 1 is used up through one route...
  limiter.acquire(list, global_exempt=false)
  limiter.release(list, status=200, headers=bucket_headers("abc", "0"))
  assert_eq(limiter.state(fetch), limiter.state(list))
  // ...so the other waits for its reset, and channel 2 does not.
  limiter.acquire(other_channel, global_exempt=false)
  limiter.release(other_channel, status=200, headers=bucket_headers("abc", "4"))
  assert_eq(clock.slept(), [])
  limiter.acquire(fetch, global_exempt=false)
  limiter.release(fetch, status=200, headers=bucket_headers("abc", "4"))
  assert_eq(clock.slept(), [1500])
}

///|
async test "a 429 in a shared Discord bucket holds every route in it" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  let create = "POST:/channels/1/messages"
  let reply = "POST:/channels/1/messages/{}/threads"
  for bucket in [create, reply] {
    limiter.acquire(bucket, global_exempt=false)
    limiter.release(bucket, status=200, headers=bucket_headers("h", "5"))
  }
  limiter.acquire(create, global_exempt=false)
  limiter.release(
    create,
    status=429,
    headers=@http.Headers::of([
      ("x-ratelimit-bucket", "h"),
      ("x-ratelimit-scope", "user"),
      ("retry-after", "0.25"),
    ]),
  )
  limiter.acquire(reply, global_exempt=false)
  limiter.release(reply, status=200, headers=@http.Headers::empty())
  assert_eq(clock.slept(), [250])
}
