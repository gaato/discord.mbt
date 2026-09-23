///|
test "bot error messages render actionable diagnostics" {
  inspect(
    "\{BotError::FatallyClosed(code=4000)}",
    content="gateway fatally closed with code 4000",
  )
  inspect(
    "\{BotError::FatallyClosed(code=4014)}",
    content="gateway fatally closed with code 4014; verify configured gateway intents and privileged-intent approval",
  )
  inspect(
    "\{BotError::InvalidShardConfig(message="broken")}",
    content="invalid shard configuration: broken",
  )
  let limit = BotError::SessionStartLimitExceeded(
    required=2,
    remaining=1,
    reset_after_ms=5000L,
  )
  inspect(
    "\{limit}",
    content="gateway session start limit exceeded: need 2, have 1; resets in 5000ms",
  )
}

///|
test "shard id validation rejects each invalid selection" {
  fn expect_invalid(
    ids : Array[Int],
    count : Int,
    expected_message : String,
  ) -> Unit raise {
    try validate_shard_ids(ids, count) catch {
      InvalidShardConfig(message~) => assert_eq(message, expected_message)
      other => fail("unexpected error \{other}")
    } noraise {
      _ => fail("expected invalid shard config: \{expected_message}")
    }
  }

  expect_invalid([0], 0, "shard count must be positive")
  expect_invalid([], 2, "at least one shard id must be selected")
  expect_invalid([2], 2, "shard id 2 is outside 0..<2")
  expect_invalid([0, 0], 2, "duplicate shard id 0")
  validate_shard_ids([0, 1], 2)
}

///|
async test "gateway context exposes raw handles, refs, and waiters" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((request, _next) => {
    let body : Json = match request.route {
      GetGuild(guild_id~) => {
        inspect(guild_id.to_string(), content="100")
        @json.parse(
          (
            #|{"id":"100","name":"sandbox","icon":null,"splash":null,"discovery_splash":null,"owner_id":"200","afk_channel_id":null,"afk_timeout":300,"verification_level":0,"default_message_notifications":0,"explicit_content_filter":0,"roles":[],"emojis":[],"features":[],"mfa_level":0,"application_id":null,"system_channel_id":null,"system_channel_flags":0,"rules_channel_id":null,"vanity_url_code":null,"description":null,"banner":null,"premium_tier":0,"preferred_locale":"en-US","public_updates_channel_id":null,"safety_alerts_channel_id":null}
          ),
        )
      }
      GetGuildMember(guild_id~, user_id~) => {
        inspect(guild_id.to_string(), content="100")
        inspect(user_id.to_string(), content="200")
        @json.parse(
          (
            #|{"roles":[],"joined_at":"2024-01-02T03:04:05.000000+00:00","user":{"id":"200","username":"nelly","discriminator":"0","avatar":null}}
          ),
        )
      }
      GetUser(user_id~) => {
        inspect(user_id.to_string(), content="200")
        @json.parse(
          (
            #|{"id":"200","username":"nelly","discriminator":"0","avatar":null}
          ),
        )
      }
      GetChannelMessage(channel_id~, message_id~) => {
        inspect(channel_id.to_string(), content="400")
        inspect(message_id.to_string(), content="500")
        @json.parse(
          (
            #|{"id":"500","channel_id":"400","author":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"content":"hello","timestamp":"2024-01-02T03:04:05.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
          ),
        )
      }
      other => fail("unexpected REST route \{other.bucket()}")
    }
    { status: 200, headers: Map([]), body, }
  })
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client~,
    gateway_url="wss://gateway.example",
  )
  bot.gateway_bot_info_.val = Some(manager_gateway_info())
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()

    // Raw handles agree with the ctx-level views built on top of them.
    assert_true(ctx.shard_raw().latency_ms() == ctx.latency_ms())
    inspect(ctx.framework_raw().command_specs().stringify(), content="[]")

    // Each ref accessor binds the ids it was given.
    let guild_id : @model.GuildId = @model.Id::parse("100")
    let user_id : @model.UserId = @model.Id::parse("200")
    let guild = ctx.guild_ref(guild_id).fetch()
    inspect(guild.name, content="sandbox")
    let fetched_member = ctx.member_ref(guild_id, user_id).fetch()
    guard fetched_member.user is Some(member_user) else {
      fail("expected member user payload")
    }
    inspect(member_user.username, content="nelly")
    let user = ctx.user_ref(user_id).fetch()
    inspect(user.username, content="nelly")

    // A typed waiter resolves from a later dispatch...
    let waiter = group.spawn(no_wait=true, () => {
      ctx.wait_for(
        Events::message_create(),
        event => event.message.content == "hello",
        timeout_ms=2000,
      )
    })
    @async.sleep(10)
    transport.incoming.put(
      (
        #|{"op":0,"s":2,"t":"MESSAGE_CREATE","d":{"id":"500","channel_id":"400","author":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"content":"hello","timestamp":"2024-01-02T03:04:05.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}}
      ),
    )
    guard waiter.wait() is Some(event) else {
      fail("expected message create waiter to resolve")
    }

    // ...and both message ref shapes point at that message's route.
    let fetched = ctx.message_ref(event).fetch()
    inspect(fetched.content, content="hello")
    let refetched = ctx.ref_of_message(event.message).fetch()
    inspect(refetched.content, content="hello")

    // Waiters time out to None instead of raising.
    assert_true(
      ctx.wait_for(Events::message_create(), _ => false, timeout_ms=1) is None,
    )
    assert_true(
      ctx.wait_for_component(custom_id="never-clicked", timeout_ms=1) is None,
    )
    ctx.shutdown()
    running.wait()
  })
}
