///|
fn surface_client(requests : Array[String]) -> @dhttp.Client {
  let client = @dhttp.Client("test-token")
  client.middleware((request, _) => {
    let body = match request.body {
      Some(Object(fields)) if fields.get("attachments") is Some(attachments) =>
        " attachments=\{attachments.stringify()}"
      _ => ""
    }
    requests.push(
      "\{Repr(request.route.method_())} \{request.route.path()}\{body}",
    )
    let status = if request.route.method_() is Delete { 204 } else { 200 }
    { status, headers: Map([]), body: app_test_message().to_json(), }
  })
  client
}

///|
fn retained_attachment() -> @model.AttachmentRequest raise {
  {
    id: @model.Id::parse("900000000000000001"),
    filename: None,
    title: None,
    description: None,
    duration_secs: None,
    waveform: None,
    is_spoiler: None,
  }
}

///|
async test "deferred command context manages its original and followups" {
  let requests : Array[String] = []
  let client = surface_client(requests)
  defer client.close()
  let followup_id : @model.MessageId = @model.Id::parse("700000000000000001")
  let app = @app.AppBuilder()
  app.command(
    @app.slash(
      name="manage",
      description="Manage the deferred response",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (ctx, _) => {
        ctx.original() |> ignore
        ctx.edit_original(files=[@dhttp.FileUpload("new.png", b"png")], keep_attachments=[
          retained_attachment(),
        ])
        |> ignore
        ctx.followup(content="more") |> ignore
        ctx.get_followup(followup_id) |> ignore
        ctx.edit_followup(followup_id, content="edited") |> ignore
        ctx.delete_followup(followup_id)
        ctx.delete_original()
      }),
    ),
  )
  let framework = state_flow_framework(app.build(), client)
  let interaction = app_command("manage", "500000000000000901")
  let (gate, _) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  inspect(
    requests.join("\n"),
    content=(
      #|Get /webhooks/400000000000000001/interaction-token/messages/@original
      #|Patch /webhooks/400000000000000001/interaction-token/messages/@original attachments=[{"id":"900000000000000001"},{"id":0,"filename":"new.png"}]
      #|Post /webhooks/400000000000000001/interaction-token
      #|Get /webhooks/400000000000000001/interaction-token/messages/700000000000000001
      #|Patch /webhooks/400000000000000001/interaction-token/messages/700000000000000001
      #|Delete /webhooks/400000000000000001/interaction-token/messages/700000000000000001
      #|Delete /webhooks/400000000000000001/interaction-token/messages/@original
    ),
  )
}

///|
async test "deferred component update keeps attachments on the host message" {
  let requests : Array[String] = []
  let client = surface_client(requests)
  defer client.close()
  let route = @app.component_route(
    id="attach",
    state=@app.CustomIdCodec::unit(),
  )
  let app = @app.AppBuilder()
  app.on_component(
    route,
    DeferredUpdate((ctx, _) => {
      ctx.edit_original(files=[@dhttp.FileUpload("new.png", b"png")], keep_attachments=[
        retained_attachment(),
      ])
      |> ignore
    }),
  )
  let framework = state_flow_framework(app.build(), client)
  let interaction = app_component("attach", "500000000000000902")
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  assert_eq(capture.get().response.typ, DeferredUpdateMessage)
  inspect(
    requests.join("\n"),
    content=(
      #|Patch /webhooks/400000000000000001/interaction-token/messages/@original attachments=[{"id":"900000000000000001"},{"id":0,"filename":"new.png"}]
    ),
  )
}

///|
async test "immediate component update sends files with retained attachments" {
  let route = @app.component_route(id="swap", state=@app.CustomIdCodec::unit())
  let app = @app.AppBuilder()
  app.on_component(
    route,
    Immediate((_, _) => {
      @app.ComponentReply::update_message(
        files=[@dhttp.FileUpload("new.png", b"png")],
        keep_attachments=[retained_attachment()],
      )
    }),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  let framework = state_flow_framework(app.build(), client)
  let interaction = app_component("swap", "500000000000000903")
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  let captured = capture.get()
  json_inspect(captured.response.to_json(), content={
    "type": 7,
    "data": {
      "attachments": [
        { "id": "900000000000000001" },
        { "id": 0, "filename": "new.png" },
      ],
    },
  })
  debug_inspect(captured.files.map(files => files.length()), content="Some(1)")
}

///|
/// Exercise one deferred context's whole message surface and return the
/// routes it reached, in order.
async fn surface_routes(
  app : @app.AppBuilder,
  interaction : @model.Interaction,
  requests : Array[String],
  client : @dhttp.Client,
) -> String {
  let framework = state_flow_framework(app.build(), client)
  let (gate, _) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  requests.map(line => line.split(" ").take(2).collect().join(" ")).join("\n")
}

///|
const SURFACE_ROUTES : String =
  #|Get /webhooks/400000000000000001/interaction-token/messages/@original
  #|Patch /webhooks/400000000000000001/interaction-token/messages/@original
  #|Post /webhooks/400000000000000001/interaction-token
  #|Get /webhooks/400000000000000001/interaction-token/messages/700000000000000001
  #|Patch /webhooks/400000000000000001/interaction-token/messages/700000000000000001
  #|Delete /webhooks/400000000000000001/interaction-token/messages/700000000000000001
  #|Delete /webhooks/400000000000000001/interaction-token/messages/@original

///|
async test "component and modal deferred contexts share the message surface" {
  let followup_id : @model.MessageId = @model.Id::parse("700000000000000001")
  let requests : Array[String] = []
  let client = surface_client(requests)
  defer client.close()
  let route = @app.component_route(
    id="manage",
    state=@app.CustomIdCodec::unit(),
  )
  let components = @app.AppBuilder()
  components.on_component(
    route,
    DeferredMessage(ephemeral=true, (ctx, _) => {
      ctx.original() |> ignore
      ctx.edit_original(content="edited") |> ignore
      ctx.followup(content="more") |> ignore
      ctx.get_followup(followup_id) |> ignore
      ctx.edit_followup(followup_id, content="edited") |> ignore
      ctx.delete_followup(followup_id)
      ctx.delete_original()
    }),
  )
  let component_routes = surface_routes(
    components,
    app_component("manage", "500000000000000904"),
    requests,
    client,
  )
  assert_eq(component_routes, SURFACE_ROUTES)
  requests.clear()
  let form = @app.modal(
    custom_id="note",
    title="Note",
    state=@app.CustomIdCodec::unit(),
    fields=@app.ModalFields::of(@app.text_field(custom_id="note", label="Note")),
  )
  let modals = @app.AppBuilder()
  modals.on_modal(
    form,
    DeferredMessage(ephemeral=true, (ctx, _, _) => {
      ignore(ctx.raw())
      ctx.original() |> ignore
      ctx.edit_original(content="edited") |> ignore
      ctx.followup(content="more") |> ignore
      ctx.get_followup(followup_id) |> ignore
      ctx.edit_followup(followup_id, content="edited") |> ignore
      ctx.delete_followup(followup_id)
      ctx.delete_original()
    }),
  )
  let modal_routes = surface_routes(
    modals,
    app_modal_submit("note", "hello", "500000000000000905"),
    requests,
    client,
  )
  assert_eq(modal_routes, SURFACE_ROUTES)
}
