///|
/// Attach `app` with a waiter that records `custom_id:filter` and never
/// resolves, then run `interaction` through it.
async fn record_waits(
  app : @app.AppBuilder,
  interaction : @model.Interaction,
) -> Array[String] {
  let seen : Array[String] = []
  let waiter : @app.ComponentWaiter = (custom_id, user, _) => {
    let filter = match user {
      Some(id) => id.to_string()
      None => "anyone"
    }
    seen.push("\{custom_id}:\{filter}")
    None
  }
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((_, _) => {
    status: 200,
    headers: Map([]),
    body: app_test_message().to_json(),
  })
  let application_id = @model.Id::parse("400000000000000001")
  let framework = @framework.Framework(client, application_id)
  app.build().attach(framework, client~, application_id~, waiter~) |> ignore
  let (gate, _) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  seen
}

///|
async test "a modal submit can wait for a component by route and state" {
  let confirm = @app.component_route(
    id="confirm",
    state=@app.CustomIdCodec::int(),
  )
  let form = @app.modal(
    custom_id="order",
    title="Order",
    state=@app.CustomIdCodec::int(),
    fields=@app.ModalFields::of(@app.text_field(custom_id="note", label="Note")),
  )
  let app = @app.AppBuilder()
  app.on_modal(
    form,
    DeferredMessage(ephemeral=true, (ctx, order, _) => {
      let everyone = ctx.wait_for_component(confirm, order, from=Anyone)
      let invoker = ctx.wait_for_component(confirm, order + 1)
      assert_true(everyone is None && invoker is None)
    }),
  )
  let seen = record_waits(
    app,
    app_modal_submit("order:41", "note", "500000000000000961"),
  )
  assert_eq(seen, ["confirm:41:anyone", "confirm:42:200000000000000001"])
}

///|
async test "a wait whose state does not encode raises before waiting" {
  let pair = @app.component_route(
    id="pair",
    state=@app.CustomIdCodec::string().zip(@app.CustomIdCodec::string()),
  )
  let errors : Array[String] = []
  let app = @app.AppBuilder()
  app.error_policy((_, error) => errors.push("\{Repr(error)}"))
  app.command(
    @app.slash(
      name="pair",
      description="Wait on a bad pair",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (ctx, _) => {
        ctx.wait_for_component(pair, ("a:b", "c")) |> ignore
      }),
    ),
  )
  let seen = record_waits(app, app_command("pair", "500000000000000962"))
  assert_eq(seen, [])
  debug_inspect(
    errors,
    content=(
      #|["SeparatorInSegment(segment=\"a:b\")"]
    ),
  )
}
