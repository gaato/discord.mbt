///|
/// Interaction-first /echo example. App owns the command declaration; Bot
/// adds command synchronization, gateway events, and the managed run loop.
///
/// Run: DISCORD_TOKEN=... GUILD_ID=... moon run --release src/examples/slash_echo
/// With GUILD_ID the command syncs to that guild (instant); without it the
/// command syncs globally (may take up to an hour to appear).
/// RUN_SECONDS overrides the default 120s window.
const DEFAULT_RUN_SECONDS : Int = 120

///|
struct EchoArgs {
  text : String
  times : Int
}

///|
fn echo_args() -> @discord.Args[EchoArgs] {
  @discord.Args::map2(
    @discord.arg_string(name="text", description="What to echo"),
    @discord.arg_int32(
      name="times",
      description="How many times (1-5)",
      min=1,
      max=5,
    ).with_default(1),
    (text, times) => { text, times, },
  )
}

///|
fn echo_command() -> @discord.Command[EchoArgs] {
  @discord.slash(
    name="echo",
    description="Echo your text back",
    args=echo_args(),
    handler=Immediate((_ctx, args) => {
      @discord.CommandReply::message(
        content=Array::make(args.times, args.text).join("\n"),
      )
    }),
  )
}

///|
/// The command sync scope: the `GUILD_ID` guild when set, otherwise global.
/// An invalid `GUILD_ID` stops the program: falling back to a global sync
/// would delete every undeclared global command.
fn command_scope() -> @discord.CommandScope raise {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId = @model.Id::parse(raw) catch {
        _ => fail("GUILD_ID is not a valid guild id: \{raw}")
      }
      @discord.CommandScope::Guild(guild_id)
    }
    None => @discord.CommandScope::Global
  }
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  @async.handle_cancellation(() => {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    let run_seconds = match @env.get_env_var("RUN_SECONDS") {
      Some(s) => @string.parse_int(s) catch { _ => DEFAULT_RUN_SECONDS }
      None => DEFAULT_RUN_SECONDS
    }
    let app = @discord.AppBuilder()
    app.command(echo_command())

    let bot = @discord.BotBuilder(app.build(), token~, sync=command_scope())
    bot.on(@discord.Events::ready(), (_ctx, ready) => {
      println("[bot] ready as \{ready.user.username}")
    })
    @async.with_timeout_opt(run_seconds * 1000, () => bot.build().run())
    |> ignore
  })
  |> ignore
  println("[bot] shutting down")
}
