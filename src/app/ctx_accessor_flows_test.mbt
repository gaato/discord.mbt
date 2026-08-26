///|
test "app validation rejects modals with more than five fields" {
  let app = @app.App(sync=Disabled)
  let six = @app.ModalFields::map5(
    @app.text_field(custom_id="f1", label="f1"),
    @app.text_field(custom_id="f2", label="f2"),
    @app.text_field(custom_id="f3", label="f3"),
    @app.text_field(custom_id="f4", label="f4"),
    @app.text_field(custom_id="f5", label="f5"),
    (a, b, c, d, e) => (a, b, c, d, e),
  ).zip(@app.ModalFields::of(@app.text_field(custom_id="f6", label="f6")))
  app.on_modal(
    @app.modal(custom_id="too-big", title="Too big", fields=six),
    Raw(_ => ()),
  )
  try app.validate() catch {
    InvalidModalFieldCount(custom_id~, count~) => {
      inspect(custom_id, content="too-big")
      inspect(count, content="6")
    }
    _ => fail("unexpected validation error")
  } noraise {
    _ => fail("expected a modal field count error")
  }
}

///|
async test "command contexts expose their interaction and REST surfaces" {
  let app = @app.App(sync=Disabled)
  let rest_paths : Array[String] = []
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((request, _next) => {
    rest_paths.push(request.route.path())
    {
      status: 200,
      headers: Map([]),
      body: @json.parse(
        (
          #|{"id":"700000000000000010","channel_id":"800000000000000001","author":{"id":"1","username":"bot","discriminator":"0","avatar":null},"content":"edited","timestamp":"2025-06-01T10:00:00.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
        ),
      ),
    }
  })
  app.command(
    @app.slash(
      name="inspect",
      description="Inspect the immediate ctx",
      args=@interaction.Args::unit(),
      handler=Immediate((ctx, _) => {
        assert_eq(ctx.interaction().token, "interaction-token")
        assert_true(ctx.guild_id() is None)
        assert_eq(ctx.raw().interaction.token, "interaction-token")
        @app.CommandReply::message(content="inspected")
      }),
    ),
  )
  app.command(
    @app.slash(
      name="after",
      description="Deferred ctx accessors",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (ctx, _) => {
        assert_true(ctx.scope() is Dm(_))
        assert_eq(ctx.user().id.to_string(), "200000000000000001")
        assert_eq(ctx.interaction().token, "interaction-token")
        assert_true(ctx.guild_id() is None)
        assert_eq(ctx.raw().interaction.token, "interaction-token")
        inspect(ctx.edit_original(content="edited").content, content="edited")
        inspect(ctx.followup(content="more").content, content="edited")
      }),
    ),
  )
  @async.with_task_group(group => {
    let served = app.serve(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    match
      served.handle_interaction(app_command("inspect", "500000000000000501")) {
      Reply(response~, ..) =>
        assert_true(response.typ == ChannelMessageWithSource)
      outcome => fail("expected inspect reply, got \{Repr(outcome)}")
    }
    match
      served.handle_interaction(app_command("after", "500000000000000502")) {
      Reply(response~, ..) =>
        assert_true(response.typ == DeferredChannelMessageWithSource)
      outcome => fail("expected deferred reply, got \{Repr(outcome)}")
    }
    for _attempt in 0..<200 {
      if rest_paths.length() >= 2 {
        break
      }
      @async.sleep(10)
    }
    inspect(
      rest_paths.join("\n"),
      content=(
        #|/webhooks/400000000000000001/interaction-token/messages/@original
        #|/webhooks/400000000000000001/interaction-token
      ),
    )
  })
}
