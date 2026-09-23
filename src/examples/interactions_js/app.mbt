///|
fn echo_command() -> @discord.Command[String] {
  @discord.slash(
    name="echo",
    description="Echo text from MoonBit",
    args=@discord.Args::of(
      @discord.arg_string(name="text", description="What to echo"),
    ),
    handler=Immediate((_, text) => @discord.CommandReply::message(content=text)),
  )
}

///|
fn slow_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="slow",
    description="Defer, then finish in the background",
    args=@discord.Args::unit(),
    handler=Deferred(ephemeral=false, (ctx, _) => {
      @async.sleep(500)
      ctx.edit_original(content="Finished in the background.") |> ignore
    }),
  )
}

///|
fn vanish_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="vanish",
    description="Acknowledge, then delete the original response",
    args=@discord.Args::unit(),
    handler=Deferred(ephemeral=false, (ctx, _) => ctx.raw().delete_response()),
  )
}

///|
fn file_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="file",
    description="Return a small attachment from MoonBit",
    args=@discord.Args::unit(),
    handler=Immediate((_, _) => {
      @discord.CommandReply::message(content="Attached from MoonBit.", files=[
        @discord.FileUpload(
          "hello.txt",
          b"hello from MoonBit\n",
          content_type="text/plain",
        ),
      ])
    }),
  )
}

///|
/// The shared command set used by the JavaScript HTTP adapters and the native
/// registration runner.
pub fn interaction_app() -> @discord.App {
  let app = @discord.App()
  app
  ..command(echo_command())
  ..command(file_command())
  ..command(slow_command())
  .command(vanish_command())
  app
}
