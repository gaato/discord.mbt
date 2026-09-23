///|
/// The one command handled by this gateway example.
pub fn worker_app() -> @discord.App {
  let app = @discord.App()
  app.command(
    @discord.slash(
      name="ping",
      description="Check whether the gateway bot is online",
      args=@discord.Args::unit(),
      handler=Immediate((_, _) => @discord.CommandReply::message(content="pong")),
    ),
  )
  app
}
