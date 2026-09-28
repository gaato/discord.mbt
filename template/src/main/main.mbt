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
    let app = @discord.AppBuilder()
    app.command(ping_command())

    let bot = @discord.BotBuilder(app.build(), token~, sync=command_scope())
    bot.on(@discord.Events::ready(), (_, ready) => {
      println("[bot] ready as \{ready.user.username}")
    })
    bot.build().run()
  })
  |> ignore
  println("[bot] shutting down")
}
