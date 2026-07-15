///|
/// Interaction-first kitchen sink: App declares slash subcommands,
/// autocomplete, context menus, components, and typed modals. Bot supplies the
/// gateway lifecycle and READY subscription.
///
/// Run:
///   DISCORD_TOKEN=... GUILD_ID=... moon run --release src/examples/kitchen_sink
/// With GUILD_ID commands sync to that guild immediately; without it they sync
/// globally. RUN_SECONDS overrides the default two-minute window.
const DEFAULT_RUN_SECONDS : Int = 120

///|
struct GreetArgs {
  name : String
}

///|
struct AddArgs {
  a : Int64
  b : Int64
}

///|
struct Feedback {
  topic : String
  details : String?
}

///|
fn feedback_modal() -> @discord.Modal[Feedback] {
  @discord.modal(
    custom_id="demo-feedback",
    title="Demo feedback",
    fields=@discord.ModalFields::map2(
      @discord.text_field(
        custom_id="topic",
        label="Topic",
        placeholder="What should we improve?",
      ),
      @discord.text_field(
        custom_id="details",
        label="Details",
        style=Paragraph,
        placeholder="Optional context",
      ).optional(),
      (topic, details) => { topic, details },
    ),
  )
}

///|
fn name_argument() -> @discord.Arg[String] {
  @discord.arg_string(
    name="name",
    description="Who should be greeted?",
    max_length=50,
    suggest=(_, input) => {
      let query = input.to_lower()
      ["Ada", "Grace", "Linus", "MoonBit"]
      .filter(name => query.is_empty() || name.to_lower().has_prefix(query))
      .map(name => @discord.string_choice(name, name))
    },
  )
}

///|
fn demo_command() -> @discord.Command[Unit] {
  @discord.slash_group(name="demo", description="Try discord.mbt v3 features", children=[
    @discord.subcommand(
      name="greet",
      description="Greet somebody",
      args=@discord.Args::map1(name_argument(), name => { name, }),
      handler=Immediate((_, args) => {
        @discord.CommandReply::message(content="Hello, \{args.name}!", components=[
          @discord.action_row([
            @discord.button(
              custom_id="demo:feedback:\{args.name}",
              label="Open feedback form",
            ),
            @discord.button(
              custom_id="demo:done:\{args.name}",
              label="Mark as done",
              style=Success,
            ),
          ]),
        ])
      }),
    ),
    @discord.subcommand(
      name="add",
      description="Add two integers",
      args=@discord.Args::map2(
        @discord.arg_int(name="a", description="First integer"),
        @discord.arg_int(name="b", description="Second integer"),
        (a, b) => { a, b },
      ),
      handler=Immediate((_, args) => {
        @discord.CommandReply::message(
          content="\{args.a} + \{args.b} = \{args.a + args.b}",
        )
      }),
    ),
  ])
  .check(@discord.guild_only())
  .cooldown(seconds=2, bucket=User)
}

///|
fn wave_command() -> @discord.Command[@discord.TargetUser] {
  @discord.user_command(
    name="Wave",
    handler=Immediate((_, target) => {
      @discord.CommandReply::message(
        content="👋 <@\{target.user.id}>",
        ephemeral=true,
      )
    }),
  )
}

///|
fn quote_command() -> @discord.Command[@model.Message] {
  @discord.message_command(
    name="Quote",
    handler=Immediate((_, message) => {
      @discord.CommandReply::message(
        content="> \{message.content}\n— <@\{message.author.id}>",
      )
    }),
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
        Some(value) => Guild(value)
        None => {
          println("[bot] invalid GUILD_ID, syncing globally")
          Global
        }
      }
    }
    None => Global
  }
}

///|
fn run_seconds() -> Int {
  match @env.get_env_var("RUN_SECONDS") {
    Some(value) => @string.parse_int(value) catch { _ => DEFAULT_RUN_SECONDS }
    None => DEFAULT_RUN_SECONDS
  }
}

///|
async fn main {
  let feedback = feedback_modal()
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  let app = @discord.App(sync=command_sync())
  app
  ..command(demo_command())
  ..command(wave_command())
  ..command(quote_command())
  ..on_component(
    prefix="demo:feedback:",
    Immediate(ctx => ShowModal(feedback.show(state=ctx.suffix()))),
  )
  ..on_component(
    prefix="demo:done:",
    DeferredUpdate(ctx => {
      ctx.edit_original(
        content="✅ \{ctx.suffix()} marked this greeting as done.",
        components=[],
      )
      |> ignore
    }),
  )
  .on_modal(
    feedback,
    Immediate((ctx, form) => {
      let details = form.details.unwrap_or("(no details)")
      @discord.InitialResponse::message(
        content="Feedback from \{ctx.state().unwrap_or("unknown")}:\n" +
          "**\{form.topic}**\n\{details}",
        ephemeral=true,
      )
    }),
  )

  let bot = @discord.Bot(app, token~)
  bot.on(@discord.Events::ready(), (_ctx, ready) => {
    println("[bot] ready as \{ready.user.username}")
  })
  bot.on(@discord.Events::message_create(), (ctx, event) => {
    if event.guild_id is None && event.message.content == "!ping" {
      ctx.message_ref(event).reply(content="pong") |> ignore
    }
  })
  println("[try] /demo greet name:<autocomplete>")
  println("[try] /demo add a:2 b:3")
  println("[try] Apps → Wave on a user")
  println("[try] Apps → Quote on a message")
  println("[try] use both buttons on the /demo greet response")
  println("[try] DM the bot !ping")
  try @async.with_timeout_opt(run_seconds() * 1000, () => bot.run()) catch {
    @discord.AppConfigError::EmptyToken =>
      println("[error] EmptyToken: set DISCORD_TOKEN to run the bot")
    error => raise error
  } noraise {
    _ => ()
  }
  println("[done]")
}
