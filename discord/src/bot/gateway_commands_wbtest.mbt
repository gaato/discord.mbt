///|
async fn with_command_context(
  shards : ShardConfig,
  body : async (
    GatewayCtx,
    Array[@gatewaysim.FakeTransport],
    @netruntime.VirtualClock,
  ) -> Unit,
) -> Unit {
  let clock = @netruntime.VirtualClock()
  let transports = [
    @gatewaysim.FakeTransport(clock~),
    @gatewaysim.FakeTransport(clock~),
  ]
  let available = [transports[1], transports[0]]
  let builder = BotBuilder(
    @app.AppBuilder().build(),
    token="test-token",
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
    shards~,
  )
  builder.presence(@model.UpdatePresence(status=Idle))
  builder.core.gateway_bot_info_.val = Some(
    manager_gateway_info(max_concurrency=2),
  )
  builder.core.connector_.val = Some(_ => {
    guard available.pop() is Some(transport) else {
      raise @gateway.TransportClosed(code=None, reason="no transport")
    }
    (transport : &@gateway.GatewayTransport)
  })
  builder.core.use_test_time(clock)
  let ready : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  builder.on(Events::ready(), (ctx, _) => ready.put(ctx))
  let bot = builder.build()
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    let count = match shards {
      Fixed(count~) => count
      _ => 1
    }
    let by_id : Array[@gatewaysim.FakeTransport] = transports.copy()
    for index in 0..<count {
      let transport = transports[index]
      transport.put(MANAGER_HELLO)
      let identify = manager_get(clock, transport.outgoing, "identify")
      guard identify
        is { "d": { "presence": { "status": "idle", .. }, .. }, .. } else {
        fail("missing initial presence")
      }
      let (id, total) = identify_shard(identify)
      by_id[id] = transport
      transport.put(manager_ready_frame(id, total))
    }
    let ctx = manager_get(clock, ready, "ready")
    for _ in 1..<count {
      manager_get(clock, ready, "ready") |> ignore
    }
    body(ctx, by_id, clock)
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "typed gateway context broadcasts presence and routes guild commands" {
  with_command_context(Fixed(count=2), (ctx, transports, clock) => {
    ctx.update_presence(@model.UpdatePresence(status=Invisible))
    for transport in transports {
      let frame = manager_get(clock, transport.outgoing, "presence")
      guard frame
        is { "op": Number(3, ..), "d": { "status": "invisible", .. }, .. } else {
        fail("missing presence")
      }
    }
    ctx.request_guild_members({
      guild_id: Id(4194304UL),
      select: All,
      presences: false,
      nonce: Some("route"),
    })
    let members = manager_get(clock, transports[1].outgoing, "members")
    guard members
      is { "op": Number(8, ..), "d": { "guild_id": "4194304", .. }, .. } else {
      fail("wrong member route")
    }
    ctx.request_channel_info({ guild_id: Id(8388608UL), fields: [Status], })
    let info = manager_get(clock, transports[0].outgoing, "channel info")
    guard info
      is { "op": Number(43, ..), "d": { "guild_id": "8388608", .. }, .. } else {
      fail("wrong channel route")
    }
    ctx.request_soundboard_sounds({
      guild_ids: [Id(4194304UL), Id(8388608UL), Id(12582912UL)],
    })
    let zero = manager_get(clock, transports[0].outgoing, "sounds zero")
    let one = manager_get(clock, transports[1].outgoing, "sounds one")
    json_inspect(zero, content={ "op": 31, "d": { "guild_ids": ["8388608"] } })
    json_inspect(one, content={
      "op": 31,
      "d": { "guild_ids": ["4194304", "12582912"] },
    })
  })
}

///|
async test "presence broadcast continues after the first shard fails" {
  with_command_context(Fixed(count=2), (ctx, transports, clock) => {
    ctx.shards_[0].close()
    try ctx.update_presence(@model.UpdatePresence(status=Invisible)) catch {
      @gateway.TransportClosed(code=None, reason="shard is not connected") => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected first shard error")
    }
    let frame = manager_get(
      clock,
      transports[1].outgoing,
      "later shard presence",
    )
    guard frame
      is { "op": Number(3, ..), "d": { "status": "invisible", .. }, .. } else {
      fail("missing later shard presence")
    }
  })
}

///|
async test "unmanaged guild commands fail before sending any soundboard group" {
  with_command_context(Single(id=0, count=2), (ctx, transports, _clock) => {
    try
      ctx.request_guild_members({
        guild_id: Id(4194304UL),
        select: All,
        presences: false,
        nonce: None,
      })
    catch {
      ShardNotManaged(shard_id=1) => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected unmanaged shard")
    }
    try
      ctx.request_channel_info({ guild_id: Id(4194304UL), fields: [Status], })
    catch {
      ShardNotManaged(shard_id=1) => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected unmanaged shard")
    }
    try
      ctx.request_soundboard_sounds({
        guild_ids: [Id(8388608UL), Id(4194304UL)],
      })
    catch {
      ShardNotManaged(shard_id=1) => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected unmanaged shard")
    }
    assert_true(transports[0].outgoing.try_get() is None)
  })
}

///|
fn chunk_frame(nonce : String, index : Int32, count~ : Int32 = 3) -> String {
  let frame : Json = {
    "op": 0,
    "s": Json(index + 2),
    "t": "GUILD_MEMBERS_CHUNK",
    "d": {
      "guild_id": "1",
      "members": [
        {
          "user": {
            "id": Json("\{index + 10}"),
            "username": "member",
            "discriminator": "0",
            "global_name": null,
            "avatar": null,
          },
          "roles": [],
          "joined_at": "2026-10-15T00:00:00Z",
          "deaf": false,
          "mute": false,
        },
      ],
      "presences": [
        { "user": { "id": Json("\{index + 10}") }, "status": "online" },
      ],
      "not_found": [Json("\{index + 20}")],
      "chunk_index": Json(index),
      "chunk_count": Json(count),
      "nonce": Json(nonce),
    },
  }
  frame.stringify()
}

///|
async test "fetch assembles out-of-order chunks ignores foreign nonces and cleans up" {
  with_command_context(Single(id=0, count=1), (ctx, transports, clock) => {
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, presences=true, timeout_ms=500)
      })
      let request = manager_get(clock, transports[0].outgoing, "member request")
      guard request
        is {
          "op": Number(8, ..),
          "d": { "nonce": String(nonce), "presences": True, .. },
          ..
        } else {
        fail("expected nonce")
      }
      assert_true(ctx.collector_.waits_for(KGuildMembersChunk))
      assert_true(ctx.collector_.waits_for(KRateLimited))
      let nonce = nonce.to_string()
      transports[0].put(chunk_frame("other", 0))
      // Chunks with an impossible index or count are dropped.
      transports[0].put(chunk_frame(nonce, 3))
      transports[0].put(chunk_frame(nonce, 0, count=0))
      transports[0].put(chunk_frame(nonce, 2))
      // A chunk disagreeing with the first chunk's count is dropped too.
      transports[0].put(chunk_frame(nonce, 1, count=2))
      // Back-to-back delivery also verifies that registrations survive a chunk.
      for index in [0, 2, 1] {
        transports[0].put(chunk_frame(nonce, index))
      }
      let result = fetching.wait()
      assert_eq(result.members.length(), 3)
      assert_eq(result.presences.length(), 3)
      json_inspect(result.not_found, content=["20", "21", "22"])
      assert_false(ctx.collector_.waits_for(KGuildMembersChunk))
      assert_false(ctx.collector_.waits_for(KRateLimited))
    })
  })
}

///|
async test "fetch watches matching rate limits and times out with no leaked expectations" {
  with_command_context(Single(id=0, count=1), (ctx, transports, clock) => {
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, timeout_ms=500)
      })
      let request = manager_get(clock, transports[0].outgoing, "member request")
      guard request is { "d": { "nonce": String(nonce), .. }, .. } else {
        fail("expected nonce")
      }
      let foreign : Json = {
        "op": 0,
        "s": 2,
        "t": "RATE_LIMITED",
        "d": {
          "opcode": 8,
          "retry_after": 0.0011,
          "meta": { "guild_id": "1", "nonce": "other" },
        },
      }
      transports[0].put(foreign.stringify())
      // Both a foreign nonce and another guild's nonce-less response are ignored.
      let other_guild : Json = {
        "op": 0,
        "s": 3,
        "t": "RATE_LIMITED",
        "d": { "opcode": 8, "retry_after": 0.0011, "meta": { "guild_id": "2" } },
      }
      transports[0].put(other_guild.stringify())
      // So are an unparseable guild id, a non-string nonce, and no guild id.
      for
        meta in [
          ({ "guild_id": "x" } : Json),
          { "guild_id": "1", "nonce": 1 },
          {},
        ] {
        let malformed : Json = {
          "op": 0,
          "s": 3,
          "t": "RATE_LIMITED",
          "d": { "opcode": 8, "retry_after": 0.0011, "meta": meta },
        }
        transports[0].put(malformed.stringify())
      }
      transports[0].put(chunk_frame(nonce.to_string(), 0, count=1))
      assert_eq(fetching.wait().members.length(), 1)
    })
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, timeout_ms=500)
      })
      manager_get(
        clock,
        transports[0].outgoing,
        "nonce-less rate limited request",
      )
      |> ignore
      let matching : Json = {
        "op": 0,
        "s": 3,
        "t": "RATE_LIMITED",
        "d": { "opcode": 8, "retry_after": 0.0011, "meta": { "guild_id": "1" } },
      }
      transports[0].put(matching.stringify())
      try fetching.wait() catch {
        GatewayRateLimited(opcode=8, retry_after_ms=2L) => ()
        error => fail("unexpected error: \{error}")
      } noraise {
        _ => fail("expected rate limit")
      }
    })
    assert_eq(ctx.collector_.waiters.length(), 0)
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, timeout_ms=10)
      })
      manager_get(clock, transports[0].outgoing, "timed out request") |> ignore
      clock.advance(10)
      try fetching.wait() catch {
        GatewayRequestTimeout => ()
        error => fail("unexpected error: \{error}")
      } noraise {
        _ => fail("expected timeout")
      }
    })
    assert_eq(ctx.collector_.waiters.length(), 0)
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All)
      })
      manager_get(clock, transports[0].outgoing, "cancelled request") |> ignore
      fetching.cancel()
      try fetching.wait() catch {
        _ => ()
      } noraise {
        _ => fail("expected cancellation")
      }
    })
    assert_eq(ctx.collector_.waiters.length(), 0)
  })
}

///|
test "rate_limit_matches requires opcode 8, the guild, and this nonce or none" {
  let guild_id : @model.GuildId = Id(1UL)
  let rows : Array[(Int32, Json, Bool)] = [
    (8, { "guild_id": "1", "nonce": "members-1" }, true),
    (8, { "guild_id": "1" }, true),
    (3, { "guild_id": "1", "nonce": "members-1" }, false),
    (8, {}, false),
    (8, { "guild_id": "x" }, false),
    (8, { "guild_id": "2" }, false),
    (8, { "guild_id": "1", "nonce": "other" }, false),
    (8, { "guild_id": "1", "nonce": 1 }, false),
    (8, { "guild_id": "1", "nonce": Json::null() }, false),
  ]
  for row in rows {
    let (opcode, meta, expected) = row
    let event : @model.GatewayRateLimitedEvent = {
      opcode,
      retry_after: 1.0,
      meta,
    }
    assert_eq(
      rate_limit_matches(event, guild_id, "members-1"),
      expected,
      msg="opcode=\{opcode} meta=\{meta.stringify()}",
    )
  }
}

///|
/// A clock that runs `hook` in the same scheduler step as the first sleep of
/// `ms` wakes, before the sleeper resumes: an event that arrives as a timeout
/// fires.
priv struct HookedClock {
  inner : @netruntime.VirtualClock
  ms : Int32
  mut hook : (async () -> Unit noraise)?
}

///|
impl @hclock.Clock for HookedClock with fn sleep(self, milliseconds) {
  (self.inner : &@hclock.Clock).sleep(milliseconds)
  if milliseconds == self.ms && self.hook is Some(hook) {
    self.hook = None
    hook()
  }
}

///|
impl @hclock.Clock for HookedClock with fn now_unix_ms(self) {
  self.inner.now_unix_ms()
}

///|
fn chunk_event(nonce : String, index : Int32) -> @model.Event raise {
  guard @json.parse(chunk_frame(nonce, index)) is { "d": data, .. } else {
    fail("expected a chunk payload")
  }
  GuildMembersChunk(@json.from_json(data))
}

///|
/// Fetch members with a 50 ms timeout after chunks 0 and 1 of 3 arrived, and
/// dispatch `late(nonce)` as the timeout fires (`delay` 0) or `delay`
/// scheduler rounds later while the fetch unwinds. Returns whether the event
/// still reached the fetch's expectations, and how the fetch ended.
async fn fetch_with_late_event(
  delay : Int32,
  late : (String) -> @model.Event raise,
) -> (Bool, String) {
  let reached = Ref(false)
  let outcome = Ref("")
  with_command_context(Single(id=0, count=1), (ctx, transports, clock) => {
    let hooked = HookedClock::{ inner: clock, ms: 50, hook: None, }
    let previous = ctx.collector_.clock.val
    ctx.collector_.clock.val = hooked
    defer {
      ctx.collector_.clock.val = previous
    }
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, timeout_ms=50)
      })
      guard manager_get(clock, transports[0].outgoing, "member request")
        is { "d": { "nonce": String(nonce), .. }, .. } else {
        fail("expected nonce")
      }
      let nonce = nonce.to_string()
      let delivered = Ref(0)
      let tap = ctx.expect_event(Events::guild_members_chunk(), _ => {
        delivered.val += 1
        false
      })
      defer tap.cancel()
      transports[0].put(chunk_frame(nonce, 0))
      transports[0].put(chunk_frame(nonce, 1))
      clock.settle(until=() => {
        delivered.val == 2 && clock.pending().contains(50)
      })
      tap.cancel()
      let event = late(nonce)
      let deliver = async fn() noraise {
        reached.val = ctx.collector_.waits_for(KGuildMembersChunk)
        ctx.collector_.dispatch(event) catch {
          _ => abort("dispatch failed")
        }
      }
      hooked.hook = Some(() => {
        if delay == 0 {
          deliver()
        } else {
          group.spawn_bg(() => {
            for _ in 0..<delay {
              @async.pause()
            }
            deliver()
          })
        }
      })
      clock.advance(50)
      outcome.val = try fetching.wait() catch {
        GatewayRequestTimeout => "timeout"
        error => "\{error}"
      } noraise {
        members => "\{members.members.length()} members"
      }
    })
    assert_eq(ctx.collector_.waiters.length(), 0)
  })
  (reached.val, outcome.val)
}

///|
async test "a member chunk that arrives as the fetch times out completes it" {
  // Whenever the last chunk still reaches the fetch, the fetch returns the
  // members; once the fetch has stopped listening, it timed out.
  for delay in 0..<8 {
    let (reached, outcome) = fetch_with_late_event(delay, nonce => {
      chunk_event(nonce, 2)
    })
    assert_eq(
      outcome,
      if reached {
        "3 members"
      } else {
        "timeout"
      },
      msg="delay \{delay}",
    )
  }
}

///|
async test "a rate limit that arrives as the fetch times out is reported" {
  for delay in 0..<8 {
    let (reached, outcome) = fetch_with_late_event(delay, nonce => {
      let data : Json = {
        "opcode": 8,
        "retry_after": 0.0011,
        "meta": { "guild_id": "1", "nonce": Json::string(nonce) },
      }
      RateLimited(@json.from_json(data))
    })
    assert_eq(
      outcome,
      if reached {
        "\{BotError::GatewayRateLimited(opcode=8, retry_after_ms=2L)}"
      } else {
        "timeout"
      },
      msg="delay \{delay}",
    )
  }
}

///|
async test "a partial fetch that times out still raises" {
  with_command_context(Single(id=0, count=1), (ctx, transports, clock) => {
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, timeout_ms=50)
      })
      guard manager_get(clock, transports[0].outgoing, "member request")
        is { "d": { "nonce": String(nonce), .. }, .. } else {
        fail("expected nonce")
      }
      let delivered = Ref(0)
      let tap = ctx.expect_event(Events::guild_members_chunk(), _ => {
        delivered.val += 1
        false
      })
      defer tap.cancel()
      transports[0].put(chunk_frame(nonce.to_string(), 0))
      transports[0].put(chunk_frame(nonce.to_string(), 2))
      clock.settle(until=() => {
        delivered.val == 2 && clock.pending().contains(50)
      })
      clock.advance(50)
      try fetching.wait() catch {
        GatewayRequestTimeout => ()
        error => fail("unexpected error: \{error}")
      } noraise {
        _ => fail("expected timeout")
      }
    })
  })
}
