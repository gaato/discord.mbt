///|
/// Live probe for the interaction behaviours that only a Discord client can
/// exercise: error-policy recovery driven by the response gate's real state,
/// and user-restricted component waits. Every command prints what the error
/// policy saw, so the terminal and the Discord client together show whether
/// the recovery reached the user.
///
/// Run (GUILD_ID is required so the probe never registers global commands):
///   DISCORD_TOKEN=... GUILD_ID=... moon run --release src/examples/gate_probe
///
/// Expected results are printed at startup and in each command's description.
const DEFAULT_RUN_SECONDS : Int = 600

///|
priv suberror ProbeFailure {
  ProbeFailure(String)
} derive(Debug)

///|
/// `/probe-overflow`: the initial response is one character over Discord's
/// 2000-character limit, so Discord rejects the callback with HTTP 400. The
/// gate reopens (`Pending`) and the policy's message must arrive as the
/// initial response.
fn overflow_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="probe-overflow",
    description="Rejected initial response: expect the policy message as the first reply",
    args=@discord.Args::unit(),
    handler=Immediate((_, _) => {
      @discord.CommandReply::message(content="x".repeat(2001))
    }),
  )
}

///|
/// `/probe-raw`: a Raw handler responds and then fails. The gate is
/// `Sent(ChannelMessageWithSource)`, so the policy's message must arrive as a
/// followup under the first reply.
fn raw_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="probe-raw",
    description="Raw handler responds then fails: expect a first reply plus a policy followup",
    args=@discord.Args::unit(),
    handler=Raw(ctx => {
      ctx.respond(content="first reply from the Raw handler", ephemeral=true)
      raise ProbeFailure("raised after responding")
    }),
  )
}

///|
/// `/probe-modal`: a Raw handler opens a modal and then fails. The gate is
/// `Sent(Modal)`; whether Discord accepts a followup in that state is the
/// open question this command answers (watch the terminal for
/// "error policy failed").
fn modal_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="probe-modal",
    description="Raw handler opens a modal then fails: does a followup arrive?",
    args=@discord.Args::unit(),
    handler=Raw(ctx => {
      ctx.show_modal(custom_id="probe-note", title="Gate probe", components=[
        @discord.label(
          label="Note",
          component=@discord.text_input(custom_id="note", required=false),
        ),
      ])
      raise ProbeFailure("raised after opening a modal")
    }),
  )
}

///|
fn note_modal() -> @discord.Modal[Unit, String?] {
  @discord.modal(
    custom_id="probe-note",
    title="Gate probe",
    state=@discord.CustomIdCodec::unit(),
    fields=@discord.ModalFields::of(
      @discord.text_field(custom_id="note", label="Note").optional(),
    ),
  )
}

///|
/// `/probe-wait anyone:<bool>`: posts a public button and waits for it. By
/// default only the invoker satisfies the wait; another account's click falls
/// through to the `probe-wait:` raw route, which tells that user so. With
/// `anyone:true` the first click from any account satisfies it.
fn wait_command() -> @discord.Command[Bool] {
  @discord.slash(
    name="probe-wait",
    description="Public button + wait: by default only you can satisfy it",
    args=@discord.Args::of(
      @discord.arg_bool(
        name="anyone",
        description="Let any user satisfy the wait",
      ).with_default(false),
    ),
    handler=Deferred(ephemeral=false, (ctx, anyone) => {
      // The interaction id makes each wait's button unique; the same route
      // builds the button and the wait.
      let wait_route = @discord.component_route(
        id="probe-wait",
        state=@discord.CustomIdCodec::id(),
      )
      let waited = ctx.interaction().id
      let from : @discord.WaitFrom = if anyone { Anyone } else { Invoker }
      ctx.edit_original(
        content="Waiting 60 s for a click (from=\{Repr(from)}). Ask another account to press it too.",
        components=[
          @discord.action_row([
            @discord.button(
              custom_id=wait_route.custom_id(waited),
              label="Press me",
            ),
          ]),
        ],
      )
      |> ignore
      match
        ctx.wait_for_component(wait_route, waited, from~, timeout_ms=60000) {
        Some(click) => {
          println("[wait] satisfied by \{click.user().username}")
          click.update_message(
            content="✅ wait satisfied by \{click.user().username} (from=\{Repr(from)})",
            components=[],
          )
        }
        None => {
          println("[wait] timed out")
          ctx.edit_original(content="⌛ wait timed out", components=[])
          |> ignore
        }
      }
    }),
  )
}

///|
/// `/probe-deferred-fail` and `/probe-deferred-fail-public`: a `Deferred`
/// handler fails right after the framework deferred for it. The loading
/// message is still showing, so the policy's reply must replace it (edit
/// original) rather than arrive as a separate message. Its visibility is the
/// defer's: public for `-public` even though the policy asks for an
/// ephemeral reply.
fn deferred_fail_command(public~ : Bool) -> @discord.Command[Unit] {
  @discord.slash(
    name=if public {
      "probe-deferred-fail-public"
    } else {
      "probe-deferred-fail"
    },
    description="Fail right after deferring: the loading message becomes the policy reply",
    args=@discord.Args::unit(),
    handler=Deferred(ephemeral=!public, (_, _) => {
      raise ProbeFailure("raised while the loading message is showing")
    }),
  )
}

///|
/// `/probe-edited-fail`: a Deferred handler replaces the loading message with
/// a partial result and then fails. The partial result must stay, and the
/// policy's reply must arrive as a separate ephemeral followup.
fn edited_fail_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="probe-edited-fail",
    description="Edit the reply then fail: the edit stays and the policy follows up",
    args=@discord.Args::unit(),
    handler=Deferred(ephemeral=true, (ctx, _) => {
      ctx.edit_original(content="partial result (must stay)") |> ignore
      raise ProbeFailure("raised after editing the original response")
    }),
  )
}

///|
fn update_route() -> @discord.ComponentRoute[Unit] {
  @discord.component_route(
    id="probe-update",
    state=@discord.CustomIdCodec::unit(),
  )
}

///|
/// `/probe-update-fail`: posts a button whose DeferredUpdate handler fails.
/// The original message belongs to the button, so the policy must not edit
/// it: expect the message unchanged and an ephemeral policy followup.
fn update_fail_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="probe-update-fail",
    description="Post a button whose DeferredUpdate handler fails",
    args=@discord.Args::unit(),
    handler=Immediate((_, _) => {
      @discord.CommandReply::message(
        content="Press the button. This text must not change.",
        components=[
          @discord.action_row([
            @discord.button(
              custom_id=update_route().custom_id(()),
              label="Fail after DeferredUpdate",
            ),
          ]),
        ],
      )
    }),
  )
}

///|
/// `/probe-slow-check` and `/probe-slow-pass`: a check sleeps 2 s, past the
/// 1.5 s point where the watchdog defers a Deferred route. The loading message
/// must appear on time; then the failing check's reply (or the handler's
/// result) replaces it.
fn slow_check_command(pass~ : Bool) -> @discord.Command[Unit] {
  @discord.slash(
    name=if pass { "probe-slow-pass" } else { "probe-slow-check" },
    description=if pass {
      "2 s check that passes: automatic defer, then the handler's result"
    } else {
      "2 s check that fails: automatic defer, then the policy replaces it"
    },
    args=@discord.Args::unit(),
    handler=Deferred(ephemeral=true, (ctx, _) => {
      ctx.edit_original(content="handler ran after the automatic defer")
      |> ignore
    }),
  ).check(_ => {
    @async.sleep(2000)
    pass
  })
}

///|
/// `/probe-unconfirmed` and `/probe-unconfirmed-edit-fails`: the REST
/// middleware in `main` lets the defer callback reach Discord and then
/// reports a transport failure, so the gate is
/// `Unconfirmed(DeferredChannelMessageWithSource)` and the policy runs.
/// Without `-edit-fails` the policy's edit replaces the loading message. With
/// it, the edit fails before it is sent and the policy falls back to a
/// followup, which Discord still turns into an edit of the loading message
/// (observed 2026-09-28; documented as deprecated).
fn unconfirmed_command(edit_fails~ : Bool) -> @discord.Command[Unit] {
  @discord.slash(
    name=if edit_fails {
      "probe-unconfirmed-edit-fails"
    } else {
      "probe-unconfirmed"
    },
    description=if edit_fails {
      "Uncertain defer and a failed edit: does the fallback followup arrive?"
    } else {
      "Uncertain defer: the policy's edit replaces the loading message"
    },
    args=@discord.Args::unit(),
    handler=Deferred(ephemeral=true, (_, _) => {
      println("[unconfirmed] unexpected: the handler ran after a failed defer")
    }),
  )
}

///|
/// Simulate lost callback responses for `/probe-unconfirmed*`, keyed by
/// interaction token. The value says whether the placeholder edit fails too.
fn simulate_unconfirmed(
  client : @discord.Client,
  tokens : Map[String, Bool],
) -> Unit {
  client.middleware((request, next) => {
    let path = request.route.path()
    for token, edit_fails in tokens {
      if !path.contains(token) {
        continue
      }
      if path.contains("/callback") {
        next(request) |> ignore
        println("[unconfirmed] defer delivered; reporting a transport failure")
        raise @dhttp.DiscordHttpError::Transport(
          message="gate_probe: simulated lost callback response",
        )
      }
      if edit_fails && path.contains("/messages/@original") {
        println("[unconfirmed] failing the placeholder edit before sending it")
        raise @dhttp.DiscordHttpError::Transport(
          message="gate_probe: simulated failed edit",
        )
      }
    }
    next(request)
  })
}

///|
fn guild_scope() -> @discord.CommandScope? {
  guard @env.get_env_var("GUILD_ID") is Some(raw) else { return None }
  let guild_id : @model.GuildId? = Some(@model.Id::parse(raw)) catch {
    _ => None
  }
  guild_id.map(value => @discord.CommandScope::Guild(value))
}

///|
fn run_seconds() -> Int {
  match @env.get_env_var("RUN_SECONDS") {
    Some(value) => @string.parse_int(value) catch { _ => DEFAULT_RUN_SECONDS }
    None => DEFAULT_RUN_SECONDS
  }
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  @async.handle_cancellation(() => {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    guard guild_scope() is Some(scope) else {
      println("[error] set GUILD_ID: the probe only registers guild commands")
      return
    }
    let client = @discord.Client(token)
    defer client.close()
    let unconfirmed : Map[String, Bool] = Map([])
    simulate_unconfirmed(client, unconfirmed)
    let app = @discord.AppBuilder()
    app
    ..command(overflow_command())
    ..command(raw_command())
    ..command(modal_command())
    ..command(wait_command())
    ..command(deferred_fail_command(public=false))
    ..command(deferred_fail_command(public=true))
    ..command(edited_fail_command())
    ..command(update_fail_command())
    ..command(slow_check_command(pass=false))
    ..command(slow_check_command(pass=true))
    ..command(unconfirmed_command(edit_fails=false))
    ..command(unconfirmed_command(edit_fails=true))
    ..on_component(
      update_route(),
      DeferredUpdate((_, _) => raise ProbeFailure("raised after DeferredUpdate")),
    )
    // Runs before the framework defers, so the REST middleware knows which
    // callbacks to intercept.
    ..middleware((ctx, next) => {
      match ctx.target() {
        Command(name="probe-unconfirmed") =>
          unconfirmed[ctx.interaction().token] = false
        Command(name="probe-unconfirmed-edit-fails") =>
          unconfirmed[ctx.interaction().token] = true
        _ => ()
      }
      next()
    })
    ..on_modal(
      note_modal(),
      Immediate((_, _, note) => {
        @discord.ModalReply::message(
          content="modal submitted: \{note.unwrap_or("(empty)")}",
          ephemeral=true,
        )
      }),
    )
    // Bystander clicks fall through the waiter to this literal-prefix route.
    ..on_component_raw(prefix="probe-wait:", ctx => {
      println(
        "[wait] \{ctx.user().username} clicked but does not satisfy the wait",
      )
      ctx.respond(
        content="This button is waiting for someone else (or the wait already ended).",
        ephemeral=true,
      )
    })
    ..on_warn(warning => println("[warn] \{warning.to_string()}"))
    .error_policy((failure, error) => {
      let state = failure.response_state()
      println(
        "[policy] origin=\{Repr(failure.origin())} state=\{Repr(state)} error=\{Repr(error)}",
      )
      failure.respond_error(
        content="policy reply — the gate was `\{Repr(state)}` when the handler failed",
        ephemeral=true,
      )
      println("[policy] respond_error delivered")
    })
    // Keep the guild's other commands: the probe shares its bot with other
    // experiments and must not delete what it does not declare.
    let bot = @discord.BotBuilder(
      app.build(),
      token~,
      client~,
      sync=scope,
      sync_unowned=Keep,
    )
    bot.on(@discord.Events::ready(), (_ctx, ready) => {
      println("[bot] ready as \{ready.user.username}")
    })
    println(
      "[try] /probe-overflow  → ONE ephemeral reply: the policy message, state Some(Pending)",
    )
    println(
      "[try] /probe-raw       → the Raw reply, then a policy followup, state Some(Sent(ChannelMessageWithSource))",
    )
    println(
      "[try] /probe-modal     → a modal opens; state Some(Sent(Modal)); note whether '[policy] respond_error delivered' or '[warn] error policy failed' follows",
    )
    println(
      "[try] /probe-wait      → your click satisfies it; another account's click gets the 'waiting for someone else' reply and the wait stays pending",
    )
    println(
      "[try] /probe-wait anyone:true → the other account's click satisfies it",
    )
    println(
      "[try] /probe-deferred-fail → the loading message turns into the policy reply (no second message); state Some(Sent(DeferredChannelMessageWithSource))",
    )
    println(
      "[try] /probe-deferred-fail-public → same, and the reply is PUBLIC (the defer's visibility wins)",
    )
    println(
      "[try] /probe-edited-fail → 'partial result (must stay)' stays; the policy reply is a separate ephemeral followup",
    )
    println(
      "[try] /probe-update-fail, then press the button → the button message is unchanged; an ephemeral policy followup arrives; state Some(Sent(DeferredUpdateMessage))",
    )
    println(
      "[try] /probe-slow-check → a loading message appears after ~1.5 s, then becomes the policy reply; error=CheckFailed, state Some(Sent(DeferredChannelMessageWithSource)); no '[warn]' about expiry",
    )
    println(
      "[try] /probe-slow-pass  → a loading message after ~1.5 s, then 'handler ran after the automatic defer'",
    )
    println(
      "[try] /probe-unconfirmed → '[unconfirmed] defer delivered…'; state Some(Unconfirmed(DeferredChannelMessageWithSource)); the loading message becomes the policy reply",
    )
    println(
      "[try] /probe-unconfirmed-edit-fails → '[unconfirmed] failing the placeholder edit…'; the fallback followup replaces the loading message (Discord's deprecated followup-as-edit)",
    )
    try
      @async.with_timeout_opt(run_seconds() * 1000, () => bot.build().run())
    catch {
      @discord.BotConfigError::EmptyToken =>
        println("[error] EmptyToken: set DISCORD_TOKEN to run the probe")
      error => raise error
    } noraise {
      _ => ()
    }
  })
  |> ignore
  println("[bot] shutting down")
}
