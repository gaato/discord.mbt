///|
async test "component and modal failures flow through the error policy" {
  let app = @app.App(sync=Disabled)
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  app.on_component(
    prefix="boom:",
    Immediate(_ => {
      raise @app.HandlerError::UserMessage(
        message="component exploded",
        ephemeral=true,
      )
    }),
  )
  app.on_component(
    prefix="late-boom:",
    DeferredUpdate(_ => {
      raise @app.HandlerError::UserMessage(
        message="deferred component exploded",
        ephemeral=true,
      )
    }),
  )
  let boom_form = @app.modal(
    custom_id="boom-form",
    title="Boom",
    fields=@app.ModalFields::of(@app.text_field(custom_id="note", label="Note")),
  )
  app.on_modal(
    boom_form,
    Immediate((_, _) => raise @app.HandlerError::GuildOnly),
  )
  let client = @dhttp.Client(
    "test-token",
    base_url="http://127.0.0.1:1",
    max_connections=1,
  )
  defer client.close()
  @async.with_task_group(group => {
    let served = app.serve(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    // A failing immediate component handler answers through the policy.
    match
      served.handle_interaction(app_component("boom:now", "500000000000000401")) {
      Reply(response~, ..) =>
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":4,"data":{"content":"component exploded","flags":64}}
          ),
        )
      outcome => fail("expected a policy reply, got \{Repr(outcome)}")
    }
    // A failing modal handler renders the fixed guild-only message.
    match
      served.handle_interaction(
        app_modal_submit("boom-form", "n/a", "500000000000000402"),
      ) {
      Reply(response~, ..) => {
        let rendered = response.to_json().stringify()
        assert_true(
          rendered.contains("This command can only be used in a server."),
        )
      }
      outcome => fail("expected a modal policy reply, got \{Repr(outcome)}")
    }
    // A failure after a deferred update must use a followup; with no REST
    // backend reachable the policy failure lands in the warn hook instead of
    // being swallowed.
    match
      served.handle_interaction(
        app_component("late-boom:now", "500000000000000403"),
      ) {
      Reply(response~, ..) => assert_true(response.typ == DeferredUpdateMessage)
      outcome => fail("expected a deferred update, got \{Repr(outcome)}")
    }
    for _attempt in 0..<200 {
      if warnings.iter().any(warning => warning.contains("error policy failed")) {
        break
      }
      @async.sleep(10)
    }
    assert_true(
      warnings.iter().any(warning => warning.contains("error policy failed")),
    )
  })
}
