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
fn note_modal() -> @discord.Modal[String?] {
  @discord.modal(
    custom_id="probe-note",
    title="Gate probe",
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
      let custom_id = "probe-wait:\{ctx.interaction().id}"
      let from : @discord.WaitFrom = if anyone { Anyone } else { Invoker }
      ctx.edit_original(
        content="Waiting 60 s for a click (from=\{Repr(from)}). Ask another account to press it too.",
        components=[
          @discord.action_row([@discord.button(custom_id~, label="Press me")]),
        ],
      )
      |> ignore
      match ctx.wait_for_component(custom_id~, from~, timeout_ms=60000) {
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
    let app = @discord.App()
    app
    ..command(overflow_command())
    ..command(raw_command())
    ..command(modal_command())
    ..command(wait_command())
    ..on_modal(
      note_modal(),
      Immediate((_, note) => {
        @discord.InitialResponse::message(
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
    ..on_warn(message => println("[warn] \{message}"))
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
    let bot = @discord.Bot(app, token~, sync=scope)
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
    try @async.with_timeout_opt(run_seconds() * 1000, () => bot.run()) catch {
      @discord.AppConfigError::EmptyToken =>
        println("[error] EmptyToken: set DISCORD_TOKEN to run the probe")
      error => raise error
    } noraise {
      _ => ()
    }
  })
  |> ignore
  println("[bot] shutting down")
}
