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
    @discord.arg_int(
      name="times",
      description="How many times (1-5)",
      min=1,
      max=5,
    ).with_default(1L),
    (text, times) => { text, times: times.to_int(), },
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
fn command_scope() -> @discord.CommandScope {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId? = Some(@model.Id::parse(raw)) catch {
        _ => None
      }
      match guild_id {
        Some(value) => Guild(value)
        None => {
          println("[bot] invalid GUILD_ID, syncing globally")
          Global
        }
      }
    }
    None => Global
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
    let app = @discord.App()
    app.command(echo_command())

    let bot = @discord.Bot(app, token~, sync=command_scope())
    bot.on(@discord.Events::ready(), (_ctx, ready) => {
      println("[bot] ready as \{ready.user.username}")
    })
    @async.with_timeout_opt(run_seconds * 1000, () => bot.run()) |> ignore
  })
  |> ignore
  println("[bot] shutting down")
}
