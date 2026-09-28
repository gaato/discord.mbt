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
  let app = @discord.AppBuilder()
  @feedback.install_feedback(
    app,
    config=FeedbackConfig(destination_channel=channel_id, cooldown_seconds=30),
  )
  let bot = @discord.BotBuilder(app.build(), token~, sync=command_scope())
  bot.on(@discord.Events::ready(), (_, ready) => {
    println("[bot] ready as \{ready.user.username}; try /feedback")
  })
  bot.build().run()
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
