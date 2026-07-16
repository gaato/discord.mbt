///|
priv suberror PolicyTestFailure derive(Debug)

///|
fn policy_test_embed(title : String) -> @model.Embed {
  {
    title: Some(title),
    typ: None,
    url: None,
    description: None,
    timestamp: None,
    color: None,
    footer: None,
    image: None,
    thumbnail: None,
    video: None,
    provider: None,
    author: None,
    fields: None,
    flags: None,
  }
}

///|
fn policy_test_interaction(
  name : String,
  id : String,
) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"data":{"id":"600000000000000001","name":"COMMAND_NAME","type":1}}
      )
      .replace(old="INTERACTION_ID", new=id)
      .replace(old="COMMAND_NAME", new=name),
    ),
  )
}

///|
fn policy_test_framework(
  app : App,
  client : @dhttp.Client,
) -> @framework.Framework raise {
  let framework = @framework.Framework(
    client,
    @model.Id::parse("400000000000000001"),
  )
  app.attach(
    framework,
    client~,
    application_id=@model.Id::parse("400000000000000001"),
  )
  |> ignore
  framework
}

///|
async test "error policy exposes the user and sends a rich initial response" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App(sync=Disabled)
  app.command(
    slash(
      name="rich-failure",
      description="Fail richly",
      args=@interaction.Args::unit(),
      handler=Raw(_ => raise PolicyTestFailure),
    ),
  )
  app.error_policy((ctx, _) => {
    guard ctx.user() is Some(user) else { fail("expected invoking user") }
    assert_eq(user.id.to_string(), "200000000000000001")
    assert_true(ctx.phase() is Some(BeforeInitial))
    assert_true(ctx.raw() is Some(RawCommand(_)))
    guard ctx.interaction() is Some(interaction) else {
      fail("expected interaction payload")
    }
    assert_eq(interaction.token, "interaction-token")
    ctx.respond_error(
      content="rich failure",
      embeds=[policy_test_embed("Failure")],
      components=[
        @interaction.action_row([
          @interaction.button(custom_id="ack", label="Acknowledge"),
        ]),
      ],
      files=[FileUpload("error.txt", b"error", content_type="text/plain")],
      allowed_mentions=@model.AllowedMentions::none(),
    )
  })
  let framework = policy_test_framework(app, client)
  let interaction = policy_test_interaction(
    "rich-failure", "500000000000000701",
  )
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  let captured = capture.get()
  json_inspect(captured.response.to_json(), content={
    "type": 4,
    "data": {
      "content": "rich failure",
      "embeds": [{ "title": "Failure" }],
      "components": [
        {
          "components": [
            {
              "style": 1,
              "label": "Acknowledge",
              "custom_id": "ack",
              "type": 2,
            },
          ],
          "type": 1,
        },
      ],
      "allowed_mentions": { "parse": [] },
      "attachments": [{ "id": 0, "filename": "error.txt" }],
      "flags": 64,
    },
  })
  debug_inspect(
    captured.files,
    content=(
      #|Some([("error.txt", 5, "text/plain", None)])
    ),
  )
}

///|
async test "error policy uses a followup after a deferred failure" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let followup_path = Ref("")
  let followup_body = Ref(Json::null())
  client.middleware((request, _next) => {
    followup_path.val = request.route.path()
    followup_body.val = request.body.unwrap_or(Json::null())
    {
      status: 200,
      headers: Map([]),
      body: @json.parse(
        (
          #|{"id":"700000000000000001","channel_id":"800000000000000001","author":{"id":"200000000000000002","username":"bot","discriminator":"0","global_name":null,"avatar":null},"content":"followup failure","timestamp":"2025-06-01T10:00:00Z","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
        ),
      ),
    }
  })
  let app = App(sync=Disabled)
  app.command(
    slash(
      name="deferred-failure",
      description="Fail after deferring",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (_, _) => raise PolicyTestFailure),
    ),
  )
  app.error_policy((ctx, _) => {
    assert_true(ctx.phase() is Some(AfterDeferred))
    ctx.respond_error(content="followup failure")
  })
  let framework = policy_test_framework(app, client)
  let interaction = policy_test_interaction(
    "deferred-failure", "500000000000000702",
  )
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  assert_true(capture.get().response.typ == DeferredChannelMessageWithSource)
  inspect(
    followup_path.val,
    content=(
      #|/webhooks/400000000000000001/interaction-token
    ),
  )
  json_inspect(followup_body.val, content={
    "content": "followup failure",
    "flags": 64,
  })
}

///|
async test "non-interaction error responses warn with a payload summary" {
  let warnings : Array[String] = []
  let ctx = failure_context(Service(name="worker"), None, None, message => {
    warnings.push(message)
  })
  assert_true(ctx.raw() is None)
  assert_true(ctx.interaction() is None)
  assert_true(ctx.user() is None)
  ctx.respond_error(content="plain failure")
  ctx.respond_error(embeds=[policy_test_embed("Failure")])
  debug_inspect(
    warnings,
    content=(
      #|[
      #|  "cannot respond to a non-interaction failure: plain failure",
      #|  "cannot respond to a non-interaction failure: embeds-only error response",
      #|]
    ),
  )
}
