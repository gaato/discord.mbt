// Compiled twins of the README's code blocks. overview.mbt.md keeps its
// examples as `mbt nocheck` so readers see no test scaffolding; every MoonBit
// block there must have a mirror here (same declarations, same API surface)
// so `moon test --target native` still fails when an example drifts from the
// library. Keep this file in README order.

// README "Quickstart"

///|
struct QuickstartEchoArgs {
  text : String
  times : Int32
}

///|
async fn run_echo_bot(token : String) -> Unit {
  let args : @discord.Args[QuickstartEchoArgs] = @discord.Args::map2(
    @discord.arg_string(name="text", description="What to echo"),
    @discord.arg_int32(
      name="times",
      description="How many times (1-5)",
      min=1,
      max=5,
    ).with_default(1),
    (text, times) => { text, times, },
  )
  let echo = @discord.slash(
    name="echo",
    description="Echo your text back",
    args~,
    handler=Immediate((_ctx, value) => {
      @discord.CommandReply::message(
        content=Array::make(value.times, value.text).join("\n"),
      )
    }),
  )
  let app = @discord.AppBuilder()
  app.command(echo)
  let bot = @discord.BotBuilder(app.build(), token~, sync=Global)
  bot.on(@discord.Events::ready(), (_ctx, ready) => {
    println("ready as \{ready.user.username}")
  })
  bot.build().run()
}

///|
test "readme examples are wired" {
  ignore(run_echo_bot)
}
