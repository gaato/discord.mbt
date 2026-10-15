///|
async fn with_command_context(
  shards : ShardConfig,
  body : async (GatewayCtx, Array[ManagerFakeTransport]) -> Unit,
) -> Unit {
  let transports = [ManagerFakeTransport(), ManagerFakeTransport()]
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
  builder.core.identify_spacing_ms_.val = 1
  builder.core.connector_.val = Some(_ => {
    guard available.pop() is Some(transport) else {
      raise @gateway.TransportClosed(code=None, reason="no transport")
    }
    (transport : &@gateway.GatewayTransport)
  })
  let ready : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  builder.on(Events::ready(), (ctx, _) => ready.put(ctx))
  let bot = builder.build()
  @async.with_timeout(3000, () => {
    @async.with_task_group(group => {
      let running = group.spawn(no_wait=true, () => bot.run())
      let count = match shards {
        Fixed(count~) => count
        _ => 1
      }
      let by_id : Array[ManagerFakeTransport] = transports.copy()
      for index in 0..<count {
        let transport = transports[index]
        transport.incoming.put(MANAGER_HELLO)
        let (_, identify) = manager_get(transport.outgoing, "identify")
        guard identify
          is { "d": { "presence": { "status": "idle", .. }, .. }, .. } else {
          fail("missing initial presence")
        }
        let (id, total) = identify_shard(identify)
        by_id[id] = transport
        transport.incoming.put(manager_ready_frame(id, total))
      }
      let ctx = manager_get(ready, "ready")
      for _ in 1..<count {
        manager_get(ready, "ready") |> ignore
      }
      body(ctx, by_id)
      ctx.shutdown()
      running.wait()
    })
  })
}

///|
async test "typed gateway context broadcasts presence and routes guild commands" {
  with_command_context(Fixed(count=2), (ctx, transports) => {
    ctx.update_presence(@model.UpdatePresence(status=Invisible))
    for transport in transports {
      let (_, frame) = manager_get(transport.outgoing, "presence")
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
    let (_, members) = manager_get(transports[1].outgoing, "members")
    guard members
      is { "op": Number(8, ..), "d": { "guild_id": "4194304", .. }, .. } else {
      fail("wrong member route")
    }
    ctx.request_channel_info({ guild_id: Id(8388608UL), fields: [Status], })
    let (_, info) = manager_get(transports[0].outgoing, "channel info")
    guard info
      is { "op": Number(43, ..), "d": { "guild_id": "8388608", .. }, .. } else {
      fail("wrong channel route")
    }
    ctx.request_soundboard_sounds({
      guild_ids: [Id(4194304UL), Id(8388608UL), Id(12582912UL)],
    })
    let (_, zero) = manager_get(transports[0].outgoing, "sounds zero")
    let (_, one) = manager_get(transports[1].outgoing, "sounds one")
    json_inspect(zero, content={ "op": 31, "d": { "guild_ids": ["8388608"] } })
    json_inspect(one, content={
      "op": 31,
      "d": { "guild_ids": ["4194304", "12582912"] },
    })
  })
}

///|
async test "unmanaged guild commands fail before sending any soundboard group" {
  with_command_context(Single(id=0, count=2), (ctx, transports) => {
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
    assert_true(
      @async.with_timeout_opt(10, () => transports[0].outgoing.get()) is None,
    )
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
  with_command_context(Single(id=0, count=1), (ctx, transports) => {
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, presences=true, timeout_ms=500)
      })
      let (_, request) = manager_get(transports[0].outgoing, "member request")
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
      transports[0].incoming.put(chunk_frame("other", 0))
      // Back-to-back delivery also verifies that registrations survive a chunk.
      for index in [2, 0, 2, 1] {
        transports[0].incoming.put(chunk_frame(nonce.to_string(), index))
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
  with_command_context(Single(id=0, count=1), (ctx, transports) => {
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, timeout_ms=500)
      })
      let (_, request) = manager_get(transports[0].outgoing, "member request")
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
      transports[0].incoming.put(foreign.stringify())
      // Both a foreign nonce and another guild's nonce-less response are ignored.
      let other_guild : Json = {
        "op": 0,
        "s": 3,
        "t": "RATE_LIMITED",
        "d": { "opcode": 8, "retry_after": 0.0011, "meta": { "guild_id": "2" } },
      }
      transports[0].incoming.put(other_guild.stringify())
      transports[0].incoming.put(chunk_frame(nonce.to_string(), 0, count=1))
      assert_eq(fetching.wait().members.length(), 1)
    })
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All, timeout_ms=500)
      })
      manager_get(transports[0].outgoing, "nonce-less rate limited request")
      |> ignore
      let matching : Json = {
        "op": 0,
        "s": 3,
        "t": "RATE_LIMITED",
        "d": { "opcode": 8, "retry_after": 0.0011, "meta": { "guild_id": "1" } },
      }
      transports[0].incoming.put(matching.stringify())
      try fetching.wait() catch {
        GatewayRateLimited(opcode=8, retry_after_ms=2L) => ()
        error => fail("unexpected error: \{error}")
      } noraise {
        _ => fail("expected rate limit")
      }
    })
    assert_eq(ctx.collector_.waiters.length(), 0)
    try ctx.fetch_guild_members(Id(1UL), All, timeout_ms=10) catch {
      GatewayRequestTimeout => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected timeout")
    }
    manager_get(transports[0].outgoing, "timed out request") |> ignore
    assert_eq(ctx.collector_.waiters.length(), 0)
    @async.with_task_group(group => {
      let fetching = group.spawn(no_wait=true, allow_failure=true, () => {
        ctx.fetch_guild_members(Id(1UL), All)
      })
      manager_get(transports[0].outgoing, "cancelled request") |> ignore
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
