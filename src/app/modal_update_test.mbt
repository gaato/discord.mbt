///|
fn ticket_modal() -> @app.Modal[Int, String] {
  @app.modal(
    custom_id="ticket-note",
    title="Ticket note",
    state=@app.CustomIdCodec::int(),
    fields=@app.ModalFields::of(@app.text_field(custom_id="note", label="Note")),
  )
}

///|
fn from_component(interaction : @model.Interaction) -> @model.Interaction raise {
  { ..interaction, message: Some(app_test_message()), }
}

///|
/// Submit `interaction` to an app with one `ticket_modal` route and return
/// the captured initial callback plus the errors the policy saw.
async fn submit_ticket(
  handler : @app.ModalSubmitHandler[Int, String],
  interaction : @model.Interaction,
) -> (@framework.CapturedResponse, Array[String]) {
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((_, _) => {
    status: 200,
    headers: Map([]),
    body: app_test_message().to_json(),
  })
  let errors : Array[String] = []
  let app = @app.AppBuilder()
  app.on_modal(ticket_modal(), handler)
  app.error_policy((ctx, error) => {
    errors.push("\{Repr(error)}")
    ctx.respond_error(content="failed")
  })
  let framework = state_flow_framework(app.build(), client)
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  (capture.get(), errors)
}

///|
async test "immediate modal reply updates the message whose component opened it" {
  let seen : Array[(Int, String)] = []
  let (captured, errors) = submit_ticket(
    Immediate((_, ticket, note) => {
      seen.push((ticket, note))
      @app.ModalReply::update_message(content="closed", components=[])
    }),
    from_component(
      app_modal_submit("ticket-note:7", "done", "500000000000000951"),
    ),
  )
  assert_eq(errors, [])
  assert_eq(seen, [(7, "done")])
  json_inspect(captured.response.to_json(), content={
    "type": 7,
    "data": { "content": "closed", "components": [] },
  })
}

///|
async test "deferred modal update acknowledges without changing the message" {
  let seen : Array[Int] = []
  let (captured, errors) = submit_ticket(
    DeferredUpdate((ctx, ticket, _) => {
      seen.push(ticket)
      ctx.edit_original(content="closed") |> ignore
    }),
    from_component(
      app_modal_submit("ticket-note:8", "done", "500000000000000952"),
    ),
  )
  assert_eq(errors, [])
  assert_eq(seen, [8])
  json_inspect(captured.response.to_json(), content={ "type": 6 })
}

///|
async test "update replies to a command-opened modal fail before anything is sent" {
  for
    handler in [
      @app.ModalSubmitHandler::Immediate((_, _, _) => {
        @app.ModalReply::update_message(content="nope")
      }),
      DeferredUpdate((_, _, _) => fail("handler must not run")),
    ] {
    let (captured, errors) = submit_ticket(
      handler,
      app_modal_submit("ticket-note:9", "done", "500000000000000953"),
    )
    // Nothing was deferred or updated: the policy's reply is the initial
    // callback, a new ephemeral message.
    json_inspect(captured.response.to_json(), content={
      "type": 4,
      "data": { "content": "failed", "flags": 64 },
    })
    assert_eq(errors.length(), 1)
    assert_true(errors[0].has_prefix("UnsupportedResponse("))
  }
}

///|
async test "modal state that does not decode is malformed" {
  let (captured, errors) = submit_ticket(
    Immediate((_, _, _) => fail("handler must not run")),
    app_modal_submit("ticket-note:not-a-number", "done", "500000000000000954"),
  )
  assert_eq(captured.response.typ, ChannelMessageWithSource)
  assert_eq(errors.length(), 1)
  assert_true(errors[0].has_prefix("Malformed("))
}

///|
test "modal show reports each kind of invalid response" {
  let modal = ticket_modal()
  modal.show(42) |> ignore
  let failures : Array[() -> @app.ModalHandle raise @app.ModalShowError] = [
    () => {
      @app.modal(
        custom_id="x".repeat(99),
        title="Long",
        state=@app.CustomIdCodec::int(),
        fields=@app.ModalFields::of(
          @app.text_field(custom_id="note", label="Note"),
        ),
      ).show(42)
    },
    () => modal.show(1, values={ "missing": "x" }),
    () => modal.show(1, values={ "note": "x".repeat(4001) }),
  ]
  let seen = failures.map(show => {
    try show() |> ignore catch {
      InvalidCustomId(TooLong(length~, ..)) => "InvalidCustomId(\{length})"
      UnknownCustomId(custom_id~) => "UnknownCustomId(\{custom_id})"
      ValueTooLong(custom_id~, length~) =>
        "ValueTooLong(\{custom_id}, \{length})"
      error => "unexpected \{Repr(error)}"
    } noraise {
      _ => "no error"
    }
  })
  debug_inspect(
    seen,
    content=(
      #|[
      #|  "InvalidCustomId(102)",
      #|  "UnknownCustomId(missing)",
      #|  "ValueTooLong(note, 4001)",
      #|]
    ),
  )
}

///|
async test "a rejected modal update is answered even when every handler slot is busy" {
  let app = @app.AppBuilder(max_in_flight=1)
  let errors : Array[String] = []
  app.error_policy((ctx, error) => {
    errors.push("\{Repr(error)}")
    ctx.respond_error(content="failed")
  })
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let holding : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  app.command(
    @app.slash(
      name="hold",
      description="Hold the only permit",
      args=@interaction.Args::unit(),
      handler=Raw(_ => {
        holding.put(())
        release.get()
      }),
    ),
  )
  app.on_modal(
    ticket_modal(),
    DeferredUpdate((_, _, _) => fail("handler must not run")),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  @async.with_task_group(group => {
    let endpoint = app
      .build()
      .serve(
        group,
        access=Client(client),
        application_id=@model.Id::parse("400000000000000001"),
      )
    group.spawn_bg(() => {
      endpoint.handle_interaction(
        app_command("hold", "500000000000000955"),
        deadline_ms=5000,
      )
      |> ignore
    })
    holding.get()
    let outcome = endpoint.handle_interaction(
      app_modal_submit("ticket-note:3", "done", "500000000000000956"),
      deadline_ms=200,
    )
    guard outcome is Reply(response~, ..) else {
      fail("expected the policy's reply, got \{Repr(outcome)}")
    }
    json_inspect(response.to_json(), content={
      "type": 4,
      "data": { "content": "failed", "flags": 64 },
    })
    assert_eq(errors.length(), 1)
    assert_true(errors[0].has_prefix("UnsupportedResponse("))
    release.put(())
  })
}
