///|
/// Low-level reference wiring without App or Bot: it connects a gateway Shard,
/// constructs Framework after READY, synchronizes commands, and routes
/// InteractionCreate by hand.
///
/// Run: DISCORD_TOKEN=... GUILD_ID=... moon run --release src/examples/low_level
/// With GUILD_ID the command syncs to that guild (instant); without it the
/// command syncs globally (may take up to an hour to appear).
/// RUN_SECONDS overrides the default 120s window.
const DEFAULT_RUN_SECONDS : Int = 120

///|
/// The typed view of one /echo invocation.
struct Echo {
  text : String
  times : Int
} derive(Debug)

///|
impl @interaction.CommandModel for Echo with fn from_options(options) {
  {
    text: options.string("text"),
    times: options.int_opt("times").unwrap_or(1L).to_int(),
  }
}

///|
fn echo_spec() -> @interaction.CommandSpec {
  @interaction.CommandSpec::slash("echo", "Echo your text back", options=[
    @interaction.string_option("text", "What to echo", required=true),
    @interaction.integer_option(
      "times",
      "How many times (1-5)",
      min_value=1,
      max_value=5,
    ),
  ])
}

///|
async fn handle_echo(ctx : @framework.CommandCtx) -> Unit {
  let echo : Echo = ctx.model()
  let lines = []
  for _ in 0..<echo.times.max(1).min(5) {
    lines.push(echo.text)
  }
  ctx.respond(content=lines.join("\n"))
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  try {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    let run_seconds = match @env.get_env_var("RUN_SECONDS") {
      Some(s) => @string.parse_int(s) catch { _ => DEFAULT_RUN_SECONDS }
      None => DEFAULT_RUN_SECONDS
    }
    let client = @dhttp.Client(token)
    let gateway_url = client.get_gateway()
    @async.with_timeout_opt(run_seconds * 1000, () => {
      @async.with_task_group((group : @async.TaskGroup[Unit]) => {
        let shard = @gateway.Shard::start(
          group,
          token~,
          intents=@model.Intents::guilds(),
          gateway_url~,
        )
        let mut framework : @framework.Framework? = None
        for ;; {
          match shard.next() {
            Dispatch(Ready(ready)) => {
              println("[shard] ready as \{ready.user.username}")
              let fw = @framework.Framework(client, ready.application.id)
                .command(echo_spec(), handle_echo)
                .on_error((label, error) => {
                  println("[fw] \{label} failed: \{to_repr(error)}")
                })
              match @env.get_env_var("GUILD_ID") {
                Some(raw) => {
                  let guild_id : @model.GuildId = @model.Id::parse(raw) catch {
                    _ => {
                      println("[fw] invalid GUILD_ID, skipping sync")
                      continue
                    }
                  }
                  fw.sync_guild(guild_id) |> ignore
                  println("[fw] synced /echo to guild \{guild_id}")
                }
                None => {
                  fw.sync_global() |> ignore
                  println("[fw] synced /echo globally")
                }
              }
              framework = Some(fw)
            }
            Dispatch(InteractionCreate(interaction)) => {
              guard framework is Some(fw) else { continue }
              if fw.process(interaction) {
                println("[fw] handled interaction \{interaction.id}")
              } else {
                println("[fw] unhandled interaction \{interaction.id}")
              }
            }
            FatallyClosed(code~) => {
              println("[shard] fatally closed: code=\{code}")
              break
            }
            _ => ()
          }
        }
      })
    })
    |> ignore
  } catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      ()
    error => raise error
  }
  println("[bot] shutting down")
}
