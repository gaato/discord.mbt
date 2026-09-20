///|
fn echo_command() -> @discord.Command[String] {
  @discord.slash(
    name="echo",
    description="Echo text from a Cloudflare Worker",
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
    description="Defer, then finish in waitUntil",
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
    description="Return a small attachment from a Cloudflare Worker",
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
/// The worker's command set. The `register` runner builds the same app on
/// native, so the deployed worker and the registered commands cannot drift.
pub fn worker_app() -> @discord.App {
  let app = @discord.App()
  app
  ..command(echo_command())
  ..command(file_command())
  ..command(slow_command())
  .command(vanish_command())
  app
}
