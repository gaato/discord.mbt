///|
fn message_stub_client(paths : Array[String]) -> @dhttp.Client {
  let client = @dhttp.Client("test-token")
  client.middleware((request, _next) => {
    paths.push(
      "\{@debug.to_string(request.route.method_())} \{request.route.path()}",
    )
    let body : Json = if request.route.method_() is Delete {
      Json::null()
    } else {
      @json.parse(
        (
          #|{"id":"700000000000000009","channel_id":"800000000000000001","author":{"id":"1","username":"bot","discriminator":"0","avatar":null},"content":"managed","timestamp":"2025-06-01T10:00:00.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
        ),
      )
    }
    {
      status: if request.route.method_() is Delete {
        204
      } else {
        200
      },
      headers: Map([]),
      body,
    }
  })
  client
}

///|
async test "interaction contexts manage originals and followups over REST" {
  let paths : Array[String] = []
  let client = message_stub_client(paths)
  defer client.close()
  let fw = @framework.Framework(client, @model.Id::parse("400000000000000001"))
  let followup_id : @model.MessageId = @model.Id::parse("700000000000000009")
  fw.component("manage:", ctx => {
    inspect(ctx.original_response().content, content="managed")
    inspect(ctx.get_followup(followup_id).content, content="managed")
    inspect(
      ctx.edit_followup(followup_id, content="edited").content,
      content="managed",
    )
    ctx.delete_followup(followup_id)
    ctx.delete_response()
  })
  |> ignore
  assert_true(fw.process(component_interaction("manage:now")))
  inspect(
    paths.join("\n"),
    content=(
      #|Get /webhooks/400000000000000001/interaction-token/messages/@original
      #|Get /webhooks/400000000000000001/interaction-token/messages/700000000000000009
      #|Patch /webhooks/400000000000000001/interaction-token/messages/700000000000000009
      #|Delete /webhooks/400000000000000001/interaction-token/messages/700000000000000009
      #|Delete /webhooks/400000000000000001/interaction-token/messages/@original
    ),
  )

  // The command and modal contexts delegate through the same helpers.
  paths.clear()
  fw.command(@interaction.CommandSpec::slash("manage", "Manage responses"), ctx => {
    inspect(ctx.original_response().content, content="managed")
    ctx.delete_response()
  })
  |> ignore
  assert_true(fw.process(named_command_interaction("manage", 1)))
  fw.modal("feedback", ctx => {
    inspect(ctx.original_response().content, content="managed")
    ctx.delete_response()
  })
  |> ignore
  assert_true(fw.process(modal_interaction()))
  inspect(paths.length(), content="4")
}

///|
async test "every raw context exposes the same followup management" {
  let paths : Array[String] = []
  let client = message_stub_client(paths)
  defer client.close()
  let fw = @framework.Framework(client, @model.Id::parse("400000000000000001"))
  let followup_id : @model.MessageId = @model.Id::parse("700000000000000009")
  fw.command(@interaction.CommandSpec::slash("manage", "Manage responses"), ctx => {
    ctx.defer_response()
    ctx.edit_response(content="edited") |> ignore
    ctx.followup(content="more") |> ignore
  })
  |> ignore
  assert_true(fw.process(named_command_interaction("manage", 1)))
  fw.modal("feedback", ctx => {
    ctx.defer_response()
    ctx.edit_response(content="edited") |> ignore
    ctx.followup(content="more") |> ignore
    ctx.get_followup(followup_id) |> ignore
    ctx.edit_followup(followup_id, content="edited") |> ignore
    ctx.delete_followup(followup_id)
  })
  |> ignore
  assert_true(fw.process(modal_interaction()))
  fw.component("more:", ctx => {
    ctx.defer_update()
    ctx.edit_response(content="edited") |> ignore
    ctx.followup(content="more") |> ignore
  })
  |> ignore
  assert_true(fw.process(component_interaction("more:1")))
  inspect(
    paths.join("\n"),
    content=(
      #|Post /interactions/500000000000000011/interaction-token/callback
      #|Patch /webhooks/400000000000000001/interaction-token/messages/@original
      #|Post /webhooks/400000000000000001/interaction-token
      #|Post /interactions/500000000000000003/interaction-token/callback
      #|Patch /webhooks/400000000000000001/interaction-token/messages/@original
      #|Post /webhooks/400000000000000001/interaction-token
      #|Get /webhooks/400000000000000001/interaction-token/messages/700000000000000009
      #|Patch /webhooks/400000000000000001/interaction-token/messages/700000000000000009
      #|Delete /webhooks/400000000000000001/interaction-token/messages/700000000000000009
      #|Post /interactions/500000000000000002/interaction-token/callback
      #|Patch /webhooks/400000000000000001/interaction-token/messages/@original
      #|Post /webhooks/400000000000000001/interaction-token
    ),
  )
}
