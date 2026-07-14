///|
fn app_interaction(fixture : String) -> @model.Interaction raise {
  @json.from_json(@json.parse(fixture))
}

///|
fn app_ping() -> @model.Interaction raise {
  app_interaction(
    (
      #|{
      #|  "id": "500000000000000100",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "token": "interaction-token",
      #|  "version": 1
      #|}
    ),
  )
}

///|
fn app_command(name : String, id : String) -> @model.Interaction raise {
  app_interaction(
    (
      #|{
      #|  "id": "INTERACTION_ID",
      #|  "application_id": "400000000000000001",
      #|  "type": 2,
      #|  "token": "interaction-token",
      #|  "version": 1,
      #|  "data": {
      #|    "id": "600000000000000100",
      #|    "name": "COMMAND_NAME",
      #|    "type": 1
      #|  }
      #|}
    )
    .replace(old="INTERACTION_ID", new=id)
    .replace(old="COMMAND_NAME", new=name),
  )
}

///|
fn app_component(custom_id : String, id : String) -> @model.Interaction raise {
  app_interaction(
    (
      #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":3,"token":"interaction-token","version":1,"data":{"custom_id":"CUSTOM_ID","component_type":2}}
    )
    .replace(old="INTERACTION_ID", new=id)
    .replace(old="CUSTOM_ID", new=custom_id),
  )
}

///|
fn app_modal_submit(
  custom_id : String,
  note : String,
  id : String,
) -> @model.Interaction raise {
  app_interaction(
    (
      #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":5,"token":"interaction-token","version":1,"data":{"custom_id":"CUSTOM_ID","components":[{"type":18,"label":"Note","component":{"type":4,"custom_id":"note","style":1,"value":"NOTE"}}]}}
    )
    .replace(old="INTERACTION_ID", new=id)
    .replace(old="CUSTOM_ID", new=custom_id)
    .replace(old="NOTE", new=note),
  )
}

///|
fn autocomplete_choices(
  response : @model.InteractionResponse,
) -> Array[@model.CommandOptionChoice] raise {
  guard response.data is Some(Object(data)) &&
    data.get("choices") is Some(value) else {
    fail("autocomplete response is missing choices")
  }
  @json.from_json(value)
}

///|
async test "interaction app dispatches captured responses and completion outcomes" {
  let bot = @bot.Bot::new(token="test-token", sync=Disabled)
  let warnings : Array[String] = []
  bot.on_warn(message => warnings.push(message))
  let waiter_results : @aqueue.Queue[Bool] = @aqueue.Queue::new(kind=Unbounded)
  let slow_finished : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  bot.command(
    @bot.slash(
      name="immediate",
      description="Immediate response",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => {
        @bot.CommandReply::message(content="hello from http")
      }),
    ),
  )
  bot.command(
    @bot.slash(
      name="silent",
      description="No initial response",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  bot.command(
    @bot.slash(
      name="deferred",
      description="Deferred without gateway waiter",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (ctx, _) => {
        waiter_results.put(
          ctx.wait_for_component(custom_id="never", timeout_ms=1) is None,
        )
      }),
    ),
  )
  bot.command(
    @bot.slash(
      name="slow",
      description="Slow initial response",
      args=@interaction.Args::unit(),
      handler=Raw(raw => {
        @async.sleep(100)
        raw.respond(content="late")
        slow_finished.put(())
      }),
    ),
  )
  let client = @dhttp.Client::new(
    "test-token",
    base_url="http://127.0.0.1:1",
    max_connections=1,
  )
  defer client.close()
  @async.with_task_group(group => {
    // Explicit client/id plus sync=false must perform no startup HTTP.
    let app = bot.start_interaction_app(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    match app.handle_interaction(app_ping()) {
      Reply(response~, files~) => {
        assert_true(response.typ == Pong)
        assert_true(files is None)
      }
      outcome => fail("expected Pong reply, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(app_command("immediate", "500000000000000101")) {
      Reply(response~, files~) => {
        assert_true(response.typ == ChannelMessageWithSource)
        assert_true(files is None)
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":4,"data":{"content":"hello from http"}}
          ),
        )
      }
      outcome => fail("expected command reply, got \{to_repr(outcome)}")
    }
    match app.handle_interaction(app_command("missing", "500000000000000102")) {
      NoRoute => ()
      outcome => fail("expected NoRoute, got \{to_repr(outcome)}")
    }
    match
      @async.with_timeout_opt(250, () => {
        app.handle_interaction(app_command("silent", "500000000000000103"))
      }) {
      Some(NoResponse) => ()
      outcome => fail("expected prompt NoResponse, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(app_command("deferred", "500000000000000106")) {
      Reply(response~, files=_) =>
        assert_true(response.typ == DeferredChannelMessageWithSource)
      outcome => fail("expected deferred reply, got \{to_repr(outcome)}")
    }
    assert_true(waiter_results.get())
    assert_true(
      warnings.contains(
        "component waiting is unavailable without a gateway connection",
      ),
    )
    match
      app.handle_interaction(
        app_command("slow", "500000000000000104"),
        deadline_ms=10,
      ) {
      TimedOut => ()
      outcome => fail("expected TimedOut, got \{to_repr(outcome)}")
    }
    guard @async.with_timeout_opt(500, () => slow_finished.get()) is Some(_) else {
      fail("timed-out handler did not continue in the app task group")
    }
    guard app.handle(app_command("immediate", "500000000000000105").to_json())
      is Some(json) else {
      fail("expected JSON callback")
    }
    inspect(
      json.stringify(),
      content=(
        #|{"type":4,"data":{"content":"hello from http"}}
      ),
    )
  })
}

///|
async test "interaction app dispatches component and typed modal handlers" {
  let bot = @bot.Bot::new(token="test-token", sync=Disabled)
  let feedback = @bot.modal(
    custom_id="feedback",
    title="Feedback",
    fields=@bot.ModalFields::of(@bot.text_field(custom_id="note", label="Note")),
  )
  bot.command(
    @bot.slash(
      name="open-form",
      description="Open the feedback form",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => {
        CommandReply::ShowModal(feedback.show(state="from-command"))
      }),
    ),
  )
  bot.on_component(
    prefix="update:",
    Immediate(ctx => {
      @bot.ComponentReply::update_message(content="updated:\{ctx.suffix()}")
    }),
  )
  bot.on_component(
    prefix="open:",
    Immediate(ctx => {
      ComponentReply::ShowModal(feedback.show(state=ctx.suffix()))
    }),
  )
  bot.on_component(prefix="defer:", DeferredUpdate(_ => ()))
  bot.on_modal(
    feedback,
    Immediate((ctx, note) => {
      @bot.InitialResponse::message(
        content="saved:\{note}:\{ctx.state().unwrap_or("none")}",
      )
    }),
  )
  let client = @dhttp.Client::new(
    "test-token",
    base_url="http://127.0.0.1:1",
    max_connections=1,
  )
  defer client.close()
  @async.with_task_group(group => {
    let app = bot.start_interaction_app(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    match
      app.handle_interaction(app_command("open-form", "500000000000000400")) {
      Reply(response~, files=_) => {
        assert_true(response.typ == Modal)
        guard response.data is Some(Object(data)) else {
          fail("command modal response is missing data")
        }
        inspect(
          data["custom_id"].stringify(),
          content="\"feedback:from-command\"",
        )
      }
      outcome => fail("expected command modal reply, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(
        app_component("update:item-1", "500000000000000401"),
      ) {
      Reply(response~, files=_) => {
        assert_true(response.typ == UpdateMessage)
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":7,"data":{"content":"updated:item-1"}}
          ),
        )
      }
      outcome => fail("expected update reply, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(
        app_component("open:ticket-7", "500000000000000402"),
      ) {
      Reply(response~, files=_) => {
        assert_true(response.typ == Modal)
        guard response.data is Some(Object(data)) else {
          fail("modal response is missing data")
        }
        inspect(data["custom_id"].stringify(), content="\"feedback:ticket-7\"")
        inspect(data["title"].stringify(), content="\"Feedback\"")
      }
      outcome => fail("expected modal reply, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(
        app_modal_submit(
          "feedback:ticket-7", "looks good", "500000000000000403",
        ),
      ) {
      Reply(response~, files=_) => {
        assert_true(response.typ == ChannelMessageWithSource)
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":4,"data":{"content":"saved:looks good:ticket-7"}}
          ),
        )
      }
      outcome => fail("expected modal submit reply, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(
        app_component("defer:item-2", "500000000000000404"),
      ) {
      Reply(response~, files=_) =>
        assert_true(response.typ == DeferredUpdateMessage)
      outcome => fail("expected deferred update, got \{to_repr(outcome)}")
    }
  })
}

///|
async test "typed autocomplete dispatches partial and nested focused options" {
  let bot = @bot.Bot::new(token="test-token", sync=Disabled)
  bot.command(
    @bot.slash(
      name="search",
      description="Search documents",
      args=@interaction.Args::map2(
        @interaction.arg_string(name="scope", description="Required scope"),
        @interaction.arg_string(name="query", description="Search query", suggest=(
          ctx,
          value,
        ) => {
          assert_true(ctx.locale is Some("ja"))
          assert_true(
            ctx.guild_id is Some(id) && id.to_string() == "800000000000000001",
          )
          // Autocomplete payloads are partial: the other required option is
          // intentionally absent and command decoding must not run.
          assert_false(ctx.options.has("scope"))
          let choices = []
          for i in 0..<26 {
            choices.push(
              @interaction.string_choice("\{value}-\{i}", "\{value}-\{i}"),
            )
          }
          choices
        }),
        (_, _) => (),
      ),
      handler=Raw(_ => ()),
    ),
  )
  bot.command(
    @bot.slash_group(name="tools", description="Tool commands", children=[
      @bot.subcommand_group(name="catalog", description="Catalog tools", children=[
        @bot.subcommand(
          name="lookup",
          description="Look up an item",
          args=@interaction.Args::of(
            @interaction.arg_int(name="code", description="Item code", suggest=(
              _,
              value,
            ) => [@interaction.int_choice("code \{value}", value)]),
          ),
          handler=Raw(_ => ()),
        ),
      ]),
    ]),
  )
  bot.command(
    @bot.slash(
      name="manual",
      description="Manual override",
      args=@interaction.Args::of(
        @interaction.arg_string(name="query", description="Query", suggest=(
          _,
          value,
        ) => [@interaction.string_choice("generated", value)]),
      ),
      handler=Raw(_ => ()),
    ),
  )
  bot.autocomplete("manual", raw => {
    raw.suggest([@interaction.string_choice("raw", "raw")])
  })
  let top = app_interaction(
    (
      #|{"id":"500000000000000301","application_id":"400000000000000001","type":4,"guild_id":"800000000000000001","locale":"ja","token":"interaction-token","version":1,"data":{"id":"600000000000000301","name":"search","type":1,"options":[{"name":"query","type":3,"value":"mo","focused":true}]}}
    ),
  )
  let nested = app_interaction(
    (
      #|{"id":"500000000000000302","application_id":"400000000000000001","type":4,"token":"interaction-token","version":1,"data":{"id":"600000000000000302","name":"tools","type":1,"options":[{"name":"catalog","type":2,"options":[{"name":"lookup","type":1,"options":[{"name":"code","type":4,"value":12,"focused":true}]}]}]}}
    ),
  )
  let manual = app_interaction(
    (
      #|{"id":"500000000000000303","application_id":"400000000000000001","type":4,"token":"interaction-token","version":1,"data":{"id":"600000000000000303","name":"manual","type":1,"options":[{"name":"query","type":3,"value":"m","focused":true}]}}
    ),
  )
  let client = @dhttp.Client::new(
    "test-token",
    base_url="http://127.0.0.1:1",
    max_connections=1,
  )
  defer client.close()
  @async.with_task_group(group => {
    let app = bot.start_interaction_app(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    match app.handle_interaction(top) {
      Reply(response~, files=_) => {
        assert_true(response.typ == Autocomplete)
        let choices = autocomplete_choices(response)
        inspect(choices.length(), content="25")
        inspect(choices[0].name, content="mo-0")
        inspect(choices[24].name, content="mo-24")
      }
      outcome =>
        fail("expected top-level autocomplete, got \{to_repr(outcome)}")
    }
    match app.handle_interaction(nested) {
      Reply(response~, files=_) => {
        let choices = autocomplete_choices(response)
        inspect(choices.length(), content="1")
        inspect(choices[0].name, content="code 12")
        inspect(choices[0].value.stringify(), content="12")
      }
      outcome => fail("expected nested autocomplete, got \{to_repr(outcome)}")
    }
    match app.handle_interaction(manual) {
      Reply(response~, files=_) => {
        let choices = autocomplete_choices(response)
        inspect(choices[0].name, content="raw")
      }
      outcome => fail("expected raw autocomplete, got \{to_repr(outcome)}")
    }
  })
}

///|
test "command constructors emit context types and slash attributes" {
  json_inspect(
    @bot.user_command(name="Inspect", handler=Raw(_ => ())).spec().to_json(),
    content={ "name": "Inspect", "description": "", "type": 2 },
  )
  json_inspect(
    @bot.message_command(name="Inspect", handler=Raw(_ => ())).spec().to_json(),
    content={ "name": "Inspect", "description": "", "type": 3 },
  )
  json_inspect(
    @bot.slash(
      name="configured",
      description="Configured command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
      default_member_permissions=@model.Permissions::manage_guild(),
      nsfw=false,
      integration_types=[GuildInstall, UserInstall],
      contexts=[Guild, PrivateChannel],
    )
    .spec()
    .to_json(),
    content={
      "name": "configured",
      "description": "Configured command",
      "default_member_permissions": "32",
      "nsfw": false,
      "integration_types": [0, 1],
      "contexts": [0, 2],
    },
  )
}

///|
async test "context menu commands decode resolved targets" {
  let bot = @bot.Bot::new(token="test-token", sync=Disabled)
  bot.command(
    @bot.user_command(
      name="Inspect",
      handler=Immediate((_, target) => {
        @bot.CommandReply::message(
          content="user:\{target.user.username}:member=\{target.member is Some(_)}",
        )
      }),
    ),
  )
  bot.command(
    @bot.message_command(
      name="Inspect",
      handler=Immediate((_, message) => {
        @bot.CommandReply::message(content="message:\{message.content}")
      }),
    ),
  )
  let user_interaction = app_interaction(
    (
      #|{
      #|  "id":"500000000000000201",
      #|  "application_id":"400000000000000001",
      #|  "type":2,
      #|  "token":"interaction-token",
      #|  "version":1,
      #|  "data":{
      #|    "id":"600000000000000201",
      #|    "name":"Inspect",
      #|    "type":2,
      #|    "target_id":"80351110224678912",
      #|    "resolved":{
      #|      "users":{
      #|        "80351110224678912":{
      #|          "id":"80351110224678912",
      #|          "username":"Nelly",
      #|          "discriminator":"0",
      #|          "global_name":"Nelly",
      #|          "avatar":null
      #|        }
      #|      },
      #|      "members":{
      #|        "80351110224678912":{
      #|          "nick":"Nelly in guild",
      #|          "roles":[],
      #|          "joined_at":null,
      #|          "deaf":false,
      #|          "mute":false,
      #|          "flags":0
      #|        }
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
  let message_interaction = app_interaction(
    (
      #|{
      #|  "id":"500000000000000202",
      #|  "application_id":"400000000000000001",
      #|  "type":2,
      #|  "token":"interaction-token",
      #|  "version":1,
      #|  "data":{
      #|    "id":"600000000000000202",
      #|    "name":"Inspect",
      #|    "type":3,
      #|    "target_id":"700000000000000001",
      #|    "resolved":{
      #|      "messages":{
      #|        "700000000000000001":{
      #|          "id":"700000000000000001",
      #|          "channel_id":"710000000000000001",
      #|          "author":{
      #|            "id":"80351110224678912",
      #|            "username":"Nelly",
      #|            "discriminator":"0",
      #|            "global_name":"Nelly",
      #|            "avatar":null
      #|          },
      #|          "content":"target text",
      #|          "timestamp":"2024-01-02T03:04:05.000000+00:00",
      #|          "edited_timestamp":null,
      #|          "tts":false,
      #|          "mention_everyone":false,
      #|          "mentions":[],
      #|          "mention_roles":[],
      #|          "attachments":[],
      #|          "embeds":[],
      #|          "pinned":false,
      #|          "type":0
      #|        }
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
  let unresolved_interaction = app_interaction(
    (
      #|{"id":"500000000000000203","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"data":{"id":"600000000000000203","name":"Inspect","type":2,"target_id":"80351110224678912"}}
    ),
  )
  let client = @dhttp.Client::new(
    "test-token",
    base_url="http://127.0.0.1:1",
    max_connections=1,
  )
  defer client.close()
  @async.with_task_group(group => {
    let app = bot.start_interaction_app(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    match app.handle_interaction(user_interaction) {
      Reply(response~, files=_) =>
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":4,"data":{"content":"user:Nelly:member=true"}}
          ),
        )
      outcome => fail("expected user command reply, got \{to_repr(outcome)}")
    }
    match app.handle_interaction(message_interaction) {
      Reply(response~, files=_) =>
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":4,"data":{"content":"message:target text"}}
          ),
        )
      outcome => fail("expected message command reply, got \{to_repr(outcome)}")
    }
    match app.handle_interaction(unresolved_interaction) {
      Reply(response~, files=_) =>
        assert_true(
          response
          .to_json()
          .stringify()
          .contains("Invalid argument: user target is missing resolved data"),
        )
      outcome => fail("expected invalid target reply, got \{to_repr(outcome)}")
    }
  })
}

///|
async test "slash groups emit nested specs and dispatch direct and grouped paths" {
  let command = @bot.slash_group(
    name="admin",
    description="Administrative tools",
    children=[
      @bot.subcommand(
        name="ping",
        description="Check availability",
        args=@interaction.Args::unit(),
        handler=Immediate((_, _) => @bot.CommandReply::message(content="pong")),
      ),
      @bot.subcommand_group(
        name="member",
        description="Member administration",
        children=[
          @bot.subcommand(
            name="rename",
            description="Rename a member",
            args=@interaction.Args::of(
              @interaction.arg_string(
                name="name",
                description="New display name",
              ),
            ),
            handler=Immediate((_, name) => {
              @bot.CommandReply::message(content="renamed:\{name}")
            }),
          ),
        ],
      ),
    ],
  )
  json_inspect(command.spec().to_json(), content={
    "name": "admin",
    "description": "Administrative tools",
    "options": [
      { "type": 1, "name": "ping", "description": "Check availability" },
      {
        "type": 2,
        "name": "member",
        "description": "Member administration",
        "options": [
          {
            "type": 1,
            "name": "rename",
            "description": "Rename a member",
            "options": [
              {
                "type": 3,
                "name": "name",
                "description": "New display name",
                "required": true,
              },
            ],
          },
        ],
      },
    ],
  })
  let bot = @bot.Bot::new(token="test-token", sync=Disabled)
  bot.command(command)
  let direct = app_interaction(
    (
      #|{"id":"500000000000000211","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"data":{"id":"600000000000000211","name":"admin","type":1,"options":[{"name":"ping","type":1}]}}
    ),
  )
  let grouped = app_interaction(
    (
      #|{"id":"500000000000000212","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"data":{"id":"600000000000000212","name":"admin","type":1,"options":[{"name":"member","type":2,"options":[{"name":"rename","type":1,"options":[{"name":"name","type":3,"value":"Moon"}]}]}]}}
    ),
  )
  let unknown = app_interaction(
    (
      #|{"id":"500000000000000213","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"data":{"id":"600000000000000213","name":"admin","type":1,"options":[{"name":"missing","type":1}]}}
    ),
  )
  let client = @dhttp.Client::new(
    "test-token",
    base_url="http://127.0.0.1:1",
    max_connections=1,
  )
  defer client.close()
  @async.with_task_group(group => {
    let app = bot.start_interaction_app(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    for
      pair in [
        (direct, "pong"),
        (grouped, "renamed:Moon"),
        (unknown, "Invalid argument: unknown subcommand path: missing"),
      ] {
      let (interaction, expected) = pair
      match app.handle_interaction(interaction) {
        Reply(response~, files=_) =>
          assert_true(response.to_json().stringify().contains(expected))
        outcome => fail("expected slash group reply, got \{to_repr(outcome)}")
      }
    }
  })
}
