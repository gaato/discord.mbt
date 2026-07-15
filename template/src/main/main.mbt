///|
fn ping_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="ping",
    description="Check whether the bot is online",
    args=@discord.Args::unit(),
    handler=Immediate((_, _) => @discord.CommandReply::message(content="pong")),
  )
}

///|
fn command_sync() -> @discord.CommandSync {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId? = Some(@model.Id::parse(raw)) catch {
        _ => None
      }
      match guild_id {
        Some(value) => @discord.CommandSync::Guild(value)
        None => {
          println("[bot] invalid GUILD_ID, syncing globally")
          @discord.CommandSync::Global
        }
      }
    }
    None => @discord.CommandSync::Global
  }
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  try {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    let app = @discord.App(sync=command_sync())
    app.command(ping_command())

    let bot = @discord.Bot(app, token~)
    bot.on(@discord.Events::ready(), (_, ready) => {
      println("[bot] ready as \{ready.user.username}")
    })
    bot.run()
  } catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      ()
    error => raise error
  }
  println("[bot] shutting down")
}
