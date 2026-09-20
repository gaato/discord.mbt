///|
/// Live probe for the 2026-07-17 dogfooding fixes. Verifies against the real
/// Discord API:
///   1. MESSAGE_UPDATE payloads (unfurl / edit / pin) decode with the strict
///      full-Message decoder, and `before` / `is_edit()` behave as designed.
///   2. Localized command registration echoes through
///      `get_guild_commands(with_localizations=true)` and is omitted without.
///   3. `GatewayCtx::latency_ms()` reports a value after the first heartbeat.
///   4. `ChannelRef::with_typing` keeps re-triggering typing without error.
///
/// Run: set -a; source .env; set +a; moon run --target native --release src/examples/update_probe
fn describe_update(event : @model.MessageUpdateEvent) -> String {
  let before = match event.before {
    Some(message) => "Some(content=\{message.content})"
    None => "None"
  }
  let embeds = event.message.embeds.length()
  let pinned = event.message.pinned
  "is_edit=\{event.is_edit()} before=\{before} embeds=\{embeds} pinned=\{pinned} edited_ts=\{Repr(event.message.edited_timestamp)}"
}

///|
async fn next_update(
  updates : @aqueue.Queue[@model.MessageUpdateEvent],
  label : String,
  timeout_ms : Int,
) -> @model.MessageUpdateEvent? {
  let result = @async.with_timeout_opt(timeout_ms, () => updates.get())
  match result {
    Some(event) => println("[update] \{label}: \{describe_update(event)}")
    None =>
      println("[update] \{label}: no MESSAGE_UPDATE within \{timeout_ms}ms")
  }
  result
}

///|
async fn probe_localizations(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
) -> Unit {
  let spec = @interaction.CommandSpec::slash(
    "probe-loc",
    "Localization probe",
    name_localizations={ "ja": "プローブ" },
    description_localizations={ "ja": "ローカライズ検証" },
  )
  client.bulk_overwrite_guild_commands(
    application_id,
    guild_id,
    Json::array([spec.to_json()]),
  )
  |> ignore
  let with_loc = client.get_guild_commands(
    application_id,
    guild_id,
    with_localizations=true,
  )
  let without_loc = client.get_guild_commands(application_id, guild_id)
  let echoed = with_loc.length() == 1 &&
    with_loc[0].name_localizations is Some(Value(map)) &&
    map.get("ja") == Some("プローブ")
  let omitted = without_loc.length() == 1 &&
    without_loc[0].name_localizations is None
  println("[loc] with_localizations=true echoes dict: \{echoed}")
  println("[loc] default GET omits dict: \{omitted}")
  client.bulk_overwrite_guild_commands(
    application_id,
    guild_id,
    Json::array([]),
  )
  |> ignore
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  let guild_id : @model.GuildId = @model.Id::parse(
    @env.get_env_var("GUILD_ID").unwrap_or(""),
  )
  let client = @dhttp.Client(token)
  let app = @discord.App()
  let bot = @discord.Bot(app, token~, client~)
  bot.attach_cache(InMemoryCache(resources=CacheResources(messages=true)))
  let updates : @aqueue.Queue[@model.MessageUpdateEvent] = Queue(kind=Unbounded)
  let decode_errors : Array[String] = []
  bot.on_decode_error((marker, _payload) => {
    println("[decode-error] \{marker}")
    decode_errors.push(marker)
  })
  bot.on(@discord.Events::message_update(), (_ctx, event) => updates.put(event))
  bot.service(name="probe", ctx => {
    println("[probe] ready as \{ctx.ready().user.username}")
    probe_localizations(client, ctx.ready().application.id, guild_id) catch {
      error => println("[loc] FAILED: \{Repr(error)}")
    }
    let channel = ctx
      .guild_ref(guild_id)
      .create_channel("probe-msg-update", typ=GuildText)
    println("[probe] created channel \{channel.id}")
    let ch = ctx.channel_ref(channel.id)
    errdefer @async.protect_from_cancel(() => {
      try ch.delete(reason="update probe cleanup") |> ignore catch {
        _ => ()
      }
      ctx.shutdown()
    })
    try {
      // 1. Unfurl: a URL-only message gains embeds without an edit.
      let sent = ch.send(content="probe https://github.com/gaato/discord.mbt")
      println("[probe] sent message \{sent.id}")
      let unfurl = next_update(updates, "unfurl", 20000)
      if unfurl is Some(event) && event.is_edit() {
        println("[probe] UNEXPECTED: unfurl classified as edit")
      }
      // 2. Edit: is_edit must be true and before must hold the old content.
      let msg = ch.message_ref(sent.id)
      msg.edit(content="probe edited") |> ignore
      let edited = next_update(updates, "edit", 15000)
      if edited is Some(event) && !event.is_edit() {
        println("[probe] UNEXPECTED: edit not classified as edit")
      }
      // 3. Pin after edit: with `before`, the unchanged edited_timestamp must
      // keep is_edit() false (the no-before heuristic would say true).
      msg.pin(reason="update probe")
      let pinned = next_update(updates, "pin", 15000)
      if pinned is Some(event) && event.is_edit() {
        println("[probe] UNEXPECTED: pin classified as edit despite before")
      }
      // 4. Typing keepalive across the 10s indicator expiry.
      try {
        ch.with_typing(() => @async.sleep(12000))
        println("[typing] with_typing over 12s completed without error")
      } catch {
        error => println("[typing] FAILED: \{Repr(error)}")
      }
      // 5. Heartbeat latency.
      let mut latency = None
      for _ in 0..<90 {
        latency = ctx.latency_ms()
        if latency is Some(_) {
          break
        }
        @async.sleep(1000)
      }
      println("[latency] GatewayCtx::latency_ms() = \{Repr(latency)}")
    } catch {
      error if @async.is_being_cancelled() => raise error
      error => {
        println("[probe] FAILED: \{Repr(error)}")
        raise error
      }
    }
    ch.delete(reason="update probe cleanup") |> ignore
    println("[probe] decode errors observed: \{decode_errors.length()}")
    println("[probe] done")
    ctx.shutdown()
  })
  ignore(
    @async.handle_cancellation(() => {
      @async.with_timeout_opt(180_000, () => bot.run())
    }) catch {
      error => {
        println("[probe] run failed: \{Repr(error)}")
        None
      }
    },
  )
}
