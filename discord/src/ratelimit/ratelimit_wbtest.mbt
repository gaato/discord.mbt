///|
async test "Discord allows only one request in flight per bucket" {
  let limiter = rate_limiter()
  limiter.acquire("bucket", global_exempt=true)
  @async.with_task_group(group => {
    let started = @async.Semaphore(1, initial_value=0)
    let admitted = Ref(false)
    let waiting = group.spawn(no_wait=true, () => {
      started.release()
      limiter.acquire("bucket", global_exempt=true)
      admitted.val = true
      limiter.release("bucket", status=200, headers=@http.Headers::new())
    })
    started.acquire()
    @async.sleep(10)
    assert_false(admitted.val)
    // A different bucket still proceeds while the first exchange is in flight.
    limiter.acquire("other", global_exempt=true)
    limiter.release("other", status=200, headers=@http.Headers::new())
    assert_false(admitted.val)
    limiter.release("bucket", status=200, headers=@http.Headers::new())
    @async.with_timeout(1000, () => waiting.wait())
    assert_true(admitted.val)
  })
}

///|
test "major_parameter reads the route's channel, guild or webhook" {
  let cases : Array[(String, String?)] = [
    ("GET:/channels/1/messages", Some("channels/1")),
    ("POST:/channels/1/messages/{}/reactions/{}", Some("channels/1")),
    ("PATCH:/guilds/9/members/{}", Some("guilds/9")),
    ("POST:/webhooks/5/tok", Some("webhooks/5/tok")),
    ("PATCH:/webhooks/5/tok/messages/{}", Some("webhooks/5/tok")),
    ("GET:/webhooks/5", Some("webhooks/5")),
    ("POST:/interactions/7/tok/callback", Some("interactions/7/tok")),
    ("GET:/users/@me", Some("")),
    ("GET:/gateway/bot", Some("")),
    ("GET:/channels/{}/messages", None),
    // Route::bucket squashes an interaction's id and token.
    ("POST:/interactions/{}/{}/callback", None),
    ("my-own-key", None),
  ]
  for case in cases {
    let (bucket, expected) = case
    assert_eq(major_parameter(bucket), expected, msg=bucket)
  }
}

///|
test "discord_server_key joins the bucket hash and the major parameter" {
  let headers = (pairs : Array[(String, String)]) => {
    @http.Headers::from_array(pairs)
  }
  assert_eq(
    discord_server_key(
      "GET:/channels/1/messages",
      headers([("x-ratelimit-bucket", "abc")]),
    ),
    Some("x-ratelimit-bucket:abc:channels/1"),
  )
  assert_eq(
    discord_server_key(
      "GET:/users/@me",
      headers([("x-ratelimit-bucket", "abc")]),
    ),
    Some("x-ratelimit-bucket:abc:"),
  )
  // A name without a readable major parameter is merged with no other route.
  assert_eq(
    discord_server_key("my-own-key", headers([("x-ratelimit-bucket", "abc")])),
    Some("x-ratelimit-bucket:abc:my-own-key"),
  )
  assert_eq(discord_server_key("GET:/channels/1/messages", headers([])), None)
  assert_eq(
    discord_server_key(
      "GET:/channels/1/messages",
      headers([("x-ratelimit-bucket", " ")]),
    ),
    None,
  )
}
