///|
fn[A] app_route_button_id(
  route : @app.ComponentRoute[A],
  state : A,
) -> String raise {
  let button = @interaction.button(
    custom_id=route.custom_id(state),
    label="Run",
  )
  guard button is Button(button) else { fail("expected a button") }
  button.custom_id.unwrap()
}

///|
async fn[A : Eq + Debug] assert_component_route_roundtrip(
  codec : @app.CustomIdCodec[A],
  value : A,
) -> Unit {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let application_id : @model.ApplicationId = @model.Id::parse(
    "400000000000000001",
  )
  for mode in 0..<3 {
    let route = @app.component_route(id="roundtrip", state=codec)
    let app = @app.App()
    let seen : Array[A] = []
    let errors : Array[String] = []
    app.error_policy((_, error) => errors.push("\{Repr(error)}"))
    let handler : @app.ComponentHandler[A] = match mode {
      0 =>
        Immediate((_, state) => {
          seen.push(state)
          @app.ComponentReply::update_message(content="ok")
        })
      1 => DeferredUpdate((_, state) => seen.push(state))
      _ => DeferredMessage(ephemeral=true, (_, state) => seen.push(state))
    }
    app.on_component(route, handler)
    app.validate()
    let fw = @framework.Framework(client, application_id)
    app.attach(fw, client~, application_id~) |> ignore
    let interaction = app_component(
      app_route_button_id(route, value),
      "500000000000002301",
    )
    let (gate, capture) = @framework.ResponseGate::capture(interaction)
    assert_true(fw.process_with(interaction, gate~))
    assert_eq(errors, [])
    assert_eq(seen, [value])
    assert_true(capture.try_get() is Some(_))
  }
}

///|
async test "component route round-trips unit state into the handler" {
  let route = @app.component_route(id="unit", state=@app.CustomIdCodec::unit())
  assert_eq(route.custom_id(()), "unit")
  assert_component_route_roundtrip(@app.CustomIdCodec::unit(), ())
}

///|
async test "component route round-trips string state into the handler" {
  for state in ["", "ticket:close:42", "日本語😀"] {
    assert_component_route_roundtrip(@app.CustomIdCodec::string(), state)
  }
}

///|
async test "component route round-trips int state into the handler" {
  for state in [-2147483648, 0, 2147483647] {
    assert_component_route_roundtrip(@app.CustomIdCodec::int(), state)
  }
}

///|
async test "component route round-trips id state into the handler" {
  let id : @model.UserId = @model.Id::parse("18446744073709551615")
  assert_component_route_roundtrip(@app.CustomIdCodec::id(), id)
}

///|
async test "component route round-trips zip state into the handler" {
  assert_component_route_roundtrip(
    @app.CustomIdCodec::int().zip(@app.CustomIdCodec::string()),
    (-42, "a:b:日本語😀"),
  )
}

///|
async test "component state decode failure reaches the policy as InvalidArgument" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let application_id : @model.ApplicationId = @model.Id::parse(
    "400000000000000001",
  )
  for
    codec in [
      @app.CustomIdCodec::int(),
      @app.CustomIdCodec::custom(encode=(value : Int) => value.to_string(), decode=_ => {
        raise @app.HandlerError::GuildOnly
      }),
    ] {
    for mode in 0..<3 {
      let app = @app.App()
      let called = Ref(false)
      let invalid = Ref(false)
      let pending = Ref(false)
      app.error_policy((ctx, error) => {
        invalid.val = error is @app.HandlerError::InvalidArgument(_)
        pending.val = ctx.response_state() is Some(Pending)
      })
      let route = @app.component_route(id="number", state=codec)
      let handler : @app.ComponentHandler[Int] = match mode {
        0 =>
          Immediate((_, _) => {
            called.val = true
            @app.ComponentReply::message(content="unexpected")
          })
        1 => DeferredUpdate((_, _) => called.val = true)
        _ => DeferredMessage(ephemeral=true, (_, _) => called.val = true)
      }
      app.on_component(route, handler)
      let fw = @framework.Framework(client, application_id)
      app.attach(fw, client~, application_id~) |> ignore
      let interaction = app_component("number:invalid", "500000000000002302")
      let (gate, capture) = @framework.ResponseGate::capture(interaction)
      assert_true(fw.process_with(interaction, gate~))
      assert_false(called.val)
      assert_true(invalid.val)
      assert_true(pending.val)
      assert_true(capture.try_get() is None)
    }
  }
}

///|
async test "typed raw component handlers skip decoding and raw prefixes stay literal" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let application_id : @model.ApplicationId = @model.Id::parse(
    "400000000000000001",
  )
  let app = @app.App()
  let seen : Array[String] = []
  app.on_component(
    @app.component_route(id="typed", state=@app.CustomIdCodec::int()),
    Raw(raw => seen.push(raw.data.custom_id)),
  )
  app.on_component_raw(prefix="literal", raw => seen.push(raw.data.custom_id))
  app.validate()
  let fw = @framework.Framework(client, application_id)
  app.attach(fw, client~, application_id~) |> ignore
  assert_true(fw.process(app_component("typed:invalid", "500000000000002303")))
  assert_true(fw.process(app_component("literalish", "500000000000002304")))
  assert_false(fw.process(app_component("typedish", "500000000000002305")))
  assert_eq(seen, ["typed:invalid", "literalish"])
}

///|
async test "typed modal sibling ids fall through without decoding" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let application_id : @model.ApplicationId = @model.Id::parse(
    "400000000000000001",
  )
  for sibling_route in [false, true] {
    let app = @app.App()
    let decoded : Array[String?] = []
    let errors : Array[String] = []
    let siblings : Array[String] = []
    app.error_policy((_, error) => errors.push("\{Repr(error)}"))
    app.on_modal(
      route_test_modal("feedback"),
      Immediate((ctx, _) => {
        decoded.push(ctx.state())
        @app.InitialResponse::message(content="ok")
      }),
    )
    if sibling_route {
      app.on_modal_raw(prefix="feedbackish", raw => {
        siblings.push(raw.data.custom_id)
      })
    }
    app.validate()
    let fw = @framework.Framework(client, application_id)
    app.attach(fw, client~, application_id~) |> ignore
    for id in ["feedback", "feedback:", "feedback:42"] {
      let interaction = app_modal_submit(id, "note", "500000000000002306")
      let (gate, _) = @framework.ResponseGate::capture(interaction)
      assert_true(fw.process_with(interaction, gate~))
    }
    assert_eq(
      fw.process(app_modal_submit("feedbackish", "note", "500000000000002307")),
      sibling_route,
    )
    assert_eq(decoded, [None, Some(""), Some("42")])
    assert_eq(errors, [])
    assert_eq(siblings, if sibling_route { ["feedbackish"] } else { [] })
  }
}
