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
fn command_scope() -> @discord.CommandScope {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId? = Some(@model.Id::parse(raw)) catch {
        _ => None
      }
      match guild_id {
        Some(value) => @discord.CommandScope::Guild(value)
        None => {
          println("[bot] invalid GUILD_ID, syncing globally")
          @discord.CommandScope::Global
        }
      }
    }
    None => @discord.CommandScope::Global
  }
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  @async.handle_cancellation(() => {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    let app = @discord.App()
    app.command(ping_command())

    let bot = @discord.Bot(app, token~, sync=command_scope())
    bot.on(@discord.Events::ready(), (_, ready) => {
      println("[bot] ready as \{ready.user.username}")
    })
    bot.run()
  })
  |> ignore
  println("[bot] shutting down")
}
