///|
test "interaction message data adds the Components V2 flag" {
  let components : Array[@model.Component] = [
    Container({ id: None, components: [], accent_color: None, spoiler: None, }),
  ]
  json_inspect(@http.interaction_message_data(components~), content={
    "components": [{ "components": [], "type": 17 }],
    "flags": 32768,
  })
}

///|
test "interaction message data combines ephemeral and Components V2 flags" {
  let components : Array[@model.Component] = [
    TextDisplay({ id: None, content: "private layout", }),
  ]
  json_inspect(@http.interaction_message_data(components~, ephemeral=true), content={
    "components": [{ "content": "private layout", "type": 10 }],
    "flags": 32832,
  })
}

///|
test "interaction message data leaves legacy component flags absent" {
  let components : Array[@model.Component] = [
    ActionRow({ id: None, components: [], }),
  ]
  json_inspect(@http.interaction_message_data(components~), content={
    "components": [{ "components": [], "type": 1 }],
  })
}

///|
test "interaction message data rejects content or a poll with Components V2" {
  let components : Array[@model.Component] = [
    Separator({ id: None, divider: Some(true), spacing: None, }),
  ]
  let poll : @model.PollCreateRequest = {
    question: { text: Some("Lunch?"), emoji: None, },
    answers: [{ text: Some("Soup"), emoji: None, }],
    duration: None,
    allow_multiselect: None,
    layout_type: None,
  }
  for
    attempt in [
      () => @http.interaction_message_data(content="legacy", components~),
      () => @http.interaction_message_data(poll~, components~),
    ] {
    try attempt() |> ignore catch {
      err =>
        debug_inspect(
          err,
          content=(
            #|Validation(message="Components V2 cannot be combined with content, embeds, sticker_ids, or poll")
          ),
        )
    } noraise {
      _ => fail("expected Components V2 validation")
    }
  }
}

///|
test "interaction message data distinguishes unchanged from cleared content" {
  json_inspect(@http.interaction_message_data(), content={})
  json_inspect(@http.interaction_message_data(clear_content=true), content={
    "content": null,
  })
  try
    @http.interaction_message_data(content="x", clear_content=true) |> ignore
  catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="content and clear_content cannot both be set")
        ),
      )
  } noraise {
    _ => fail("expected a conflict")
  }
}

///|
test "interaction message data merges retained attachments with uploads" {
  let upload = @http.FileUpload("chart.png", b"png")
  let keep : Array[@model.AttachmentRequest] = [
    {
      id: @model.Id::parse("900000000000000001"),
      filename: None,
      title: None,
      description: None,
      duration_secs: None,
      waveform: None,
      is_spoiler: None,
    },
  ]
  json_inspect(
    @http.interaction_message_data(files=[upload], keep_attachments=keep),
    content={
      "attachments": [
        { "id": "900000000000000001" },
        { "id": 0, "filename": "chart.png" },
      ],
    },
  )
  json_inspect(@http.interaction_message_data(keep_attachments=[]), content={
    "attachments": [],
  })
}

///|
async test "REST message bodies reject a poll with Components V2 before sending" {
  let client = @http.Client("test-token")
  defer client.close()
  let sent : Array[String] = []
  client.middleware((request, next) => {
    sent.push(request.route.path())
    next(request)
  })
  let components : Array[@model.Component] = [
    TextDisplay({ id: None, content: "layout", }),
  ]
  let poll : @model.PollCreateRequest = {
    question: { text: Some("Lunch?"), emoji: None, },
    answers: [{ text: Some("Soup"), emoji: None, }],
    duration: None,
    allow_multiselect: None,
    layout_type: None,
  }
  let application_id : @model.ApplicationId = @model.Id::parse(
    "400000000000000001",
  )
  let attempts : Array[async () -> Unit] = [
    () => {
      client.create_message(
        @model.Id::parse("800000000000000001"),
        components~,
        poll~,
      )
      |> ignore
    },
    () => {
      client.create_followup(application_id, "token", components~, poll~)
      |> ignore
    },
    () => {
      client.edit_original_response(application_id, "token", components~, poll~)
      |> ignore
    },
    () => {
      client.execute_webhook(
        @model.Id::parse("300000000000000001"),
        "token",
        components~,
        poll~,
      )
      |> ignore
    },
  ]
  for attempt in attempts {
    try attempt() catch {
      @http.DiscordHttpError::Validation(message~) =>
        inspect(
          message,
          content="Components V2 cannot be combined with content, embeds, sticker_ids, or poll",
        )
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected Components V2 validation")
    }
  }
  assert_eq(sent, [])
}
