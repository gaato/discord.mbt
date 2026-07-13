///|
fn test_framework() -> @framework.Framework raise {
  @framework.Framework::new(
    @dhttp.Client::new("test-token"),
    @model.Id::parse("400000000000000001"),
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
  @json.from_json(@json.parse(json.replace(old="PLACEHOLDER", new=text)))
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
  @json.from_json(@json.parse(json.replace(old="PLACEHOLDER", new=custom_id)))
}

///|
fn modal_interaction() -> @model.Interaction raise {
  @json.from_json(
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
        #|        "type": 1,
        #|        "components": [
        #|          {
        #|            "type": 4,
        #|            "custom_id": "note",
        #|            "style": 2,
        #|            "label": "Note",
        #|            "value": "hello from modal"
        #|          }
        #|        ]
        #|      }
        #|    ]
        #|  }
        #|}
      ),
    ),
  )
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
