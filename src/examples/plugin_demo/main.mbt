///|
/// Feature-installation example.
///
/// Run with:
///   DISCORD_TOKEN=... FEEDBACK_CHANNEL_ID=... moon run src/examples/plugin_demo
fn command_scope() -> @discord.CommandScope {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId? = Some(@model.Id::parse(raw)) catch {
        _ => None
      }
      match guild_id {
        Some(value) => Guild(value)
        None => Global
      }
    }
    None => Global
  }
}

///|
fn feedback_channel() -> @model.ChannelId? {
  @env.get_env_var("FEEDBACK_CHANNEL_ID").bind(raw => {
    Some(@model.Id::parse(raw)) catch {
      _ => None
    }
  })
}

///|
async fn run_bot(channel_id : @model.ChannelId) -> Unit {
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  let app = @discord.App()
  @feedback.install_feedback(
    app,
    config=FeedbackConfig(destination_channel=channel_id, cooldown_seconds=30),
  )
  let bot = @discord.Bot(app, token~, sync=command_scope())
  bot.on(@discord.Events::ready(), (_, ready) => {
    println("[bot] ready as \{ready.user.username}; try /feedback")
  })
  bot.run()
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  @async.handle_cancellation(() => {
    match feedback_channel() {
      Some(channel_id) => run_bot(channel_id)
      None => println("set FEEDBACK_CHANNEL_ID to a Discord channel id")
    }
  })
  |> ignore
  println("[bot] shutting down")
}
