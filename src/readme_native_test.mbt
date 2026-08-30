// Compiled twins of the README's code blocks. README.mbt.md keeps its
// examples as `mbt nocheck` so readers see no test scaffolding; every MoonBit
// block there must have a mirror here (same declarations, same API surface)
// so `moon test --target native` still fails when an example drifts from the
// library. Keep this file in README order.

// README "Quickstart"

///|
struct QuickstartEchoArgs {
  text : String
  times : Int
}

///|
async fn run_echo_bot(token : String) -> Unit {
  let args : @discord.Args[QuickstartEchoArgs] = @discord.Args::map2(
    @discord.arg_string(name="text", description="What to echo"),
    @discord.arg_int(
      name="times",
      description="How many times (1-5)",
      min=1,
      max=5,
    ).with_default(1L),
    (text, times) => { text, times: times.to_int(), },
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
  let app = @discord.App()
  app.command(echo)
  let bot = @discord.Bot(app, token~)
  bot.on(@discord.Events::ready(), (_ctx, ready) => {
    println("ready as \{ready.user.username}")
  })
  bot.run()
}

// README "Gateway executor"

///|
fn subscribe_message_create(bot : @discord.Bot) -> Unit {
  bot.on(@discord.Events::message_create(), (_ctx, event) => {
    let message = event.message
    println("\{message.author.username}: \{message.content}")
  })
}

///|
fn auto_sharded_bot(app : @discord.App, token : String) -> @discord.Bot {
  Bot(app, token~, shards=Auto)
}

// README "HTTP interactions (experimental)"

///|
async fn handle_http_interaction(
  app : @discord.App,
  group : @async.TaskGroup[Unit],
  token : String,
  body : Json,
) -> Json? {
  app.serve(group, token~).handle(body)
}

// README "Typed models"

///|
test "readme snowflake example holds" {
  let id : @model.MessageId = @model.Id::parse("175928847299117063")
  debug_inspect(id.timestamp_ms(), content="1462015105796")
}

// README "REST without the gateway"

///|
async fn readme_rest_examples(
  token : String,
  channel_id : @model.ChannelId,
  guild_id : @model.GuildId,
  emoji_id : @model.EmojiId,
) -> Unit {
  let client = @dhttp.Client(token)
  let message = client.create_message(channel_id, content="hello")
  client.create_message(channel_id, content="with reply", reply_to=message.id)
  |> ignore
  client.guild_ref(guild_id).emoji_ref(emoji_id).edit(name="renamed") |> ignore
}

///|
test "readme examples are wired" {
  ignore(run_echo_bot)
  ignore(subscribe_message_create)
  ignore(auto_sharded_bot)
  ignore(handle_http_interaction)
  ignore(readme_rest_examples)
}
