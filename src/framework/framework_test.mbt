///|
fn test_framework() -> @framework.Framework raise {
  @framework.Framework::new(
    @dhttp.Client::new("test-token"),
    @model.Id::parse("400000000000000001"),
  )
}

///|
fn interaction_test_user() -> @model.User raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null}
      ),
    ),
  )
}

///|
fn interaction_test_member() -> @model.GuildMember raise {
  @json.from_json(
    @json.parse(
      (
        #|{"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00.000000+00:00"}
      ),
    ),
  )
}

///|
fn interaction_test_message() -> @model.Message raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"700000000000000001","channel_id":"800000000000000001","author":{"id":"200000000000000002","username":"bot","discriminator":"0","global_name":null,"avatar":null},"content":"component host","timestamp":"2025-06-01T10:00:00.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
      ),
    ),
  )
}

///|
fn echo_interaction(text : String) -> @model.Interaction raise {
  let json =
    #|{
    #|  "id": "500000000000000001",
    #|  "application_id": "400000000000000001",
    #|  "type": 2,
    #|  "token": "interaction-token",
    #|  "version": 1,
    #|  "data": {
    #|    "id": "600000000000000001",
    #|    "name": "echo",
    #|    "type": 1,
    #|    "options": [{"name": "text", "type": 3, "value": "PLACEHOLDER"}]
    #|  }
    #|}
  let interaction : @model.Interaction = @json.from_json(
    @json.parse(json.replace(old="PLACEHOLDER", new=text)),
  )
  { ..interaction, user: Some(interaction_test_user()) }
}

///|
fn named_command_interaction(
  name : String,
  typ : Int,
) -> @model.Interaction raise {
  let interaction : @model.Interaction = @json.from_json(
    @json.parse(
      (
        #|{
        #|  "id": "500000000000000011",
        #|  "application_id": "400000000000000001",
        #|  "type": 2,
        #|  "token": "interaction-token",
        #|  "version": 1,
        #|  "data": {
        #|    "id": "600000000000000011",
        #|    "name": "NAME",
        #|    "type": COMMAND_TYPE
        #|  }
        #|}
      )
      .replace(old="NAME", new=name)
      .replace(old="COMMAND_TYPE", new=typ.to_string()),
    ),
  )
  { ..interaction, user: Some(interaction_test_user()) }
}

///|
fn component_interaction(custom_id : String) -> @model.Interaction raise {
  let json =
    #|{
    #|  "id": "500000000000000002",
    #|  "application_id": "400000000000000001",
    #|  "type": 3,
    #|  "token": "interaction-token",
    #|  "version": 1,
    #|  "data": {"custom_id": "PLACEHOLDER", "component_type": 2}
    #|}
  let interaction : @model.Interaction = @json.from_json(
    @json.parse(json.replace(old="PLACEHOLDER", new=custom_id)),
  )
  {
    ..interaction,
    user: Some(interaction_test_user()),
    message: Some(interaction_test_message()),
  }
}

///|
fn modal_interaction() -> @model.Interaction raise {
  let interaction : @model.Interaction = @json.from_json(
    @json.parse(
      (
        #|{
        #|  "id": "500000000000000003",
        #|  "application_id": "400000000000000001",
        #|  "type": 5,
        #|  "token": "interaction-token",
        #|  "version": 1,
        #|  "data": {
        #|    "custom_id": "feedback:42",
        #|    "components": [
        #|      {
        #|        "type": 18,
        #|        "label": "Note",
        #|        "component": {
        #|          "type": 4,
        #|          "custom_id": "note",
        #|          "style": 2,
        #|          "value": "hello from modal"
        #|        }
        #|      }
        #|    ]
        #|  }
        #|}
      ),
    ),
  )
  { ..interaction, user: Some(interaction_test_user()) }
}

///|
async test "framework routes commands by name" {
  let fw = test_framework()
  let seen : Array[String] = []
  fw.command(@interaction.CommandSpec::slash("echo", "Echo text back"), ctx => {
    seen.push(ctx.options.string("text"))
  })
  |> ignore
  assert_true(fw.process(echo_interaction("hello")))
  debug_inspect(
    seen,
    content=(
      #|["hello"]
    ),
  )
  // an interaction for a command nobody registered is reported unhandled
  let unknown = {
    ..echo_interaction("hi"),
    data: Some(
      Command({
        id: @model.Id::parse("600000000000000002"),
        name: "missing",
        typ: ChatInput,
        resolved: None,
        options: None,
        guild_id: None,
        target_id: None,
      }),
    ),
  }
  assert_false(fw.process(unknown))
}

///|
async test "interaction contexts expose DM and guild invocation scopes" {
  let fw = test_framework()
  let scopes : Array[String] = []
  fw.command(@interaction.CommandSpec::slash("echo", "Echo"), ctx => {
    match ctx.scope() {
      Dm(user) => scopes.push("dm:\{user.id}:\{ctx.user().id}")
      Guild(guild_invoker) =>
        scopes.push("guild:\{guild_invoker.user.unwrap().id}:\{ctx.user().id}")
    }
  })
  |> ignore
  assert_true(fw.process(echo_interaction("dm")))
  let guild_interaction = {
    ..echo_interaction("guild"),
    guild_id: Some(@model.Id::parse("800000000000000001")),
    guild_member: Some(interaction_test_member()),
    user: None,
  }
  assert_true(fw.process(guild_interaction))
  debug_inspect(
    scopes,
    content=(
      #|[
      #|  "dm:200000000000000001:200000000000000001",
      #|  "guild:200000000000000001:200000000000000001",
      #|]
    ),
  )
}

///|
async test "interaction contexts reject invalid invoker combinations" {
  let fw = test_framework()
  fw.command(@interaction.CommandSpec::slash("echo", "Echo"), _ => ()) |> ignore
  let missing = { ..echo_interaction("missing"), user: None }
  try fw.process(missing) |> ignore catch {
    @framework.InteractionContextError::MissingInvoker => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected MissingInvoker")
  }
  // Both member and user present: tolerated, resolved as a guild invocation.
  let ambiguous = {
    ..echo_interaction("ambiguous"),
    guild_member: Some(interaction_test_member()),
  }
  assert_true(fw.process(ambiguous))
  let member_without_user = { ..interaction_test_member(), user: None }
  let invalid_guild = {
    ..echo_interaction("missing-member-user"),
    guild_member: Some(member_without_user),
    user: None,
  }
  try fw.process(invalid_guild) |> ignore catch {
    @framework.InteractionContextError::MissingGuildMemberUser => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected MissingGuildMemberUser")
  }
}

///|
async test "framework routes same-name commands by type" {
  let fw = test_framework()
  let seen : Array[String] = []
  fw
  .command(@interaction.CommandSpec::slash("inspect", "Inspect"), _ => {
    seen.push("slash")
  })
  .command(@interaction.CommandSpec::user("inspect"), _ => seen.push("user"))
  |> ignore
  assert_true(fw.process(named_command_interaction("inspect", 1)))
  assert_true(fw.process(named_command_interaction("inspect", 2)))
  inspect(seen.join(","), content="slash,user")
}

///|
async test "process_with captures handler and ping callbacks" {
  let fw = test_framework()
  fw.command(@interaction.CommandSpec::slash("echo", "Echo"), ctx => {
    ctx.respond(content="captured")
  })
  |> ignore
  let command = echo_interaction("hello")
  let (command_gate, command_capture) = @framework.ResponseGate::capture(
    command,
  )
  assert_true(fw.process_with(command, gate=command_gate))
  let command_response = command_capture.get().response
  assert_true(command_response.typ == ChannelMessageWithSource)
  inspect(
    command_response.to_json().stringify(),
    content=(
      #|{"type":4,"data":{"content":"captured"}}
    ),
  )
  let ping = gate_interaction(1)
  let (ping_gate, ping_capture) = @framework.ResponseGate::capture(ping)
  assert_true(fw.process_with(ping, gate=ping_gate))
  assert_true(ping_capture.get().response.typ == Pong)
}

///|
async test "framework error hook captures handler failures" {
  let fw = test_framework()
  let errors : Array[String] = []
  fw
  .command(@interaction.CommandSpec::slash("echo", "Echo text back"), ctx => {
    ctx.options.string("no-such-option") |> ignore
  })
  .on_error((label, error) => errors.push("\{label}: \{to_repr(error)}"))
  |> ignore
  assert_true(fw.process(echo_interaction("boom")))
  debug_inspect(
    errors,
    content=(
      #|["command:echo: MissingOption(name=\"no-such-option\")"]
    ),
  )
}

///|
async test "component waiters beat prefix handlers and time out cleanly" {
  @async.with_task_group((group : @async.TaskGroup[Unit]) => {
    let fw = test_framework()
    let log : Array[String] = []
    fw.component("confirm", ctx => log.push("handler:\{ctx.data.custom_id}"))
    |> ignore
    group.spawn_bg(no_wait=true, () => {
      match fw.wait_for_component(custom_id="confirm:1", timeout_ms=1000) {
        Some(ctx) => log.push("waiter:\{ctx.data.custom_id}")
        None => log.push("waiter:none")
      }
    })
    @async.sleep(20)
    // the waiter wins over the registered prefix handler
    assert_true(fw.process(component_interaction("confirm:1")))
    @async.sleep(20)
    // with the waiter gone, the prefix handler takes over
    assert_true(fw.process(component_interaction("confirm:2")))
    // no waiter, no matching prefix
    assert_false(fw.process(component_interaction("other:1")))
    debug_inspect(
      log,
      content=(
        #|["waiter:confirm:1", "handler:confirm:2"]
      ),
    )
    // timeout path returns None
    guard fw.wait_for_component(custom_id="never", timeout_ms=20) is None
  })
}

///|
async test "component contexts require and expose their attached message" {
  let fw = test_framework()
  let seen : Array[String] = []
  fw.component("inspect", ctx => {
    seen.push("\{ctx.message().id}:\{ctx.user().id}")
  })
  |> ignore
  assert_true(fw.process(component_interaction("inspect:message")))
  debug_inspect(
    seen,
    content=(
      #|["700000000000000001:200000000000000001"]
    ),
  )
  let malformed = { ..component_interaction("inspect:missing"), message: None }
  try fw.process(malformed) |> ignore catch {
    @framework.InteractionContextError::MissingComponentMessage => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected MissingComponentMessage")
  }
  assert_true(seen.length() == 1)
}

///|
async test "modal routing extracts text input values" {
  let fw = test_framework()
  let values : Array[String?] = []
  fw.modal("feedback", ctx => {
    values.push(ctx.text_value("note"))
    values.push(ctx.text_value("absent"))
  })
  |> ignore
  assert_true(fw.process(modal_interaction()))
  debug_inspect(
    values,
    content=(
      #|[Some("hello from modal"), None]
    ),
  )
}

///|
async test "modal contexts distinguish command and component origins" {
  let fw = test_framework()
  let origins : Array[String] = []
  fw.modal("feedback", ctx => {
    match ctx.origin() {
      FromCommand => origins.push("command")
      FromComponent(message) => origins.push("component:\{message.id}")
    }
  })
  |> ignore
  assert_true(fw.process(modal_interaction()))
  let component_modal = {
    ..modal_interaction(),
    message: Some(interaction_test_message()),
  }
  assert_true(fw.process(component_modal))
  debug_inspect(
    origins,
    content=(
      #|["command", "component:700000000000000001"]
    ),
  )
}
