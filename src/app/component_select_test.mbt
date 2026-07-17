///|
fn app_select_component(
  custom_id : String,
  id : String,
  with_resolved~ : Bool,
) -> @model.Interaction raise {
  let resolved =
    #|,"resolved":{"users":{"200000000000000009":{"id":"200000000000000009","username":"pick-me","discriminator":"0","avatar":null}},"roles":{"300000000000000009":{"id":"300000000000000009","name":"picked-role","color":0,"hoist":false,"position":0,"permissions":"0","managed":false,"mentionable":false}},"channels":{"400000000000000009":{"id":"400000000000000009","type":0}}}
  let interaction = app_interaction(
    (
      #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":3,"token":"interaction-token","version":1,"data":{"custom_id":"CUSTOM_ID","component_type":3,"values":["200000000000000009","300000000000000009","400000000000000009","999999999999999999"]RESOLVED}}
    )
    .replace(old="INTERACTION_ID", new=id)
    .replace(old="CUSTOM_ID", new=custom_id)
    .replace(old="RESOLVED", new=if with_resolved { resolved } else { "" }),
  )
  {
    ..interaction,
    user: Some(app_test_user()),
    message: Some(app_test_message()),
  }
}

///|
async test "component selects expose values, resolved objects, and reply kinds" {
  let app = @app.App(sync=Disabled)
  app.on_component(
    prefix="pick:",
    Immediate(ctx => {
      assert_eq(ctx.values(), [
        "200000000000000009", "300000000000000009", "400000000000000009", "999999999999999999",
      ])
      guard ctx.selected_users() is [picked_user] else {
        fail("expected one resolved user")
      }
      assert_eq(picked_user.username, "pick-me")
      guard ctx.selected_roles() is [picked_role] else {
        fail("expected one resolved role")
      }
      assert_eq(picked_role.name, "picked-role")
      guard ctx.selected_channels() is [picked_channel] else {
        fail("expected one resolved channel")
      }
      assert_eq(picked_channel.id.to_string(), "400000000000000009")
      assert_eq(ctx.custom_id(), "pick:colors")
      assert_eq(ctx.suffix(), "colors")
      assert_true(ctx.guild_id() is None)
      assert_eq(ctx.interaction().token, "interaction-token")
      @app.ComponentReply::message(content="picked", ephemeral=true)
    }),
  )
  app.on_component(
    prefix="bare:",
    Immediate(ctx => {
      // values without a resolved payload resolve to nothing...
      assert_eq(ctx.values().length(), 4)
      assert_true(ctx.selected_users() is [])
      assert_true(ctx.selected_roles() is [])
      assert_true(ctx.selected_channels() is [])
      @app.ComponentReply::update_message(content="ok")
    }),
  )
  app.on_component(
    prefix="btn:",
    DeferredMessage(ephemeral=true, ctx => {
      // ...and buttons carry no values at all.
      assert_eq(ctx.values(), [])
      assert_true(ctx.selected_users() is [])
      assert_eq(ctx.suffix(), "press")
      assert_true(ctx.guild_id() is None)
      assert_eq(ctx.interaction().token, "interaction-token")
    }),
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
    match
      served.handle_interaction(
        app_select_component(
          "pick:colors",
          "500000000000000301",
          with_resolved=true,
        ),
      ) {
      Reply(response~, files~) => {
        assert_true(files is None)
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":4,"data":{"content":"picked","flags":64}}
          ),
        )
      }
      outcome => fail("expected select reply, got \{to_repr(outcome)}")
    }
    match
      served.handle_interaction(
        app_select_component(
          "bare:x",
          "500000000000000302",
          with_resolved=false,
        ),
      ) {
      Reply(response~, ..) => assert_true(response.typ == UpdateMessage)
      outcome => fail("expected update reply, got \{to_repr(outcome)}")
    }
    match
      served.handle_interaction(
        app_component("btn:press", "500000000000000303"),
      ) {
      Reply(response~, ..) =>
        assert_true(response.typ == DeferredChannelMessageWithSource)
      outcome => fail("expected deferred reply, got \{to_repr(outcome)}")
    }
  })
}

///|
async test "dm_only checks pass for direct-message invocations" {
  let app = @app.App(sync=Disabled)
  let handled : Array[String] = []
  app.command(
    @app.slash(
      name="dm-ok",
      description="DM-only command",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => {
        handled.push("dm-ok")
        @app.CommandReply::message(content="dm fine")
      }),
    ).check(@app.dm_only()),
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
    match
      served.handle_interaction(app_command("dm-ok", "500000000000000304")) {
      Reply(response~, ..) =>
        assert_true(response.typ == ChannelMessageWithSource)
      outcome => fail("expected DM command reply, got \{to_repr(outcome)}")
    }
    assert_eq(handled, ["dm-ok"])
  })
}
