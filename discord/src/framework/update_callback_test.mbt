///|
fn modal_from_component() -> @model.Interaction raise {
  { ..modal_interaction(), message: Some(interaction_test_message()), }
}

///|
async test "modal opened from a component can update that message" {
  let fw = test_framework()
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
  fw.modal("feedback", ctx => {
    ctx.update_message(
      clear_content=true,
      files=[@dhttp.FileUpload("chart.png", b"png")],
      keep_attachments=keep,
    )
  })
  |> ignore
  let interaction = modal_from_component()
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(fw.process_with(interaction, gate~))
  let captured = capture.get()
  json_inspect(captured.response.to_json(), content={
    "type": 7,
    "data": {
      "content": null,
      "attachments": [
        { "id": "900000000000000001" },
        { "id": 0, "filename": "chart.png" },
      ],
    },
  })
  debug_inspect(captured.files.map(files => files.length()), content="Some(1)")
}

///|
async test "modal opened from a component can defer an update" {
  let fw = test_framework()
  fw.modal("feedback", ctx => ctx.defer_update()) |> ignore
  let interaction = modal_from_component()
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(fw.process_with(interaction, gate~))
  json_inspect(capture.get().response.to_json(), content={ "type": 6 })
}

///|
async test "modal opened from a command refuses update callbacks before sending" {
  let fw = test_framework()
  let errors : Array[String] = []
  fw.modal("feedback", ctx => {
    ctx.update_message(content="nope") catch {
      error => errors.push("\{Repr(error)}")
    }
    ctx.defer_update() catch {
      error => errors.push("\{Repr(error)}")
    }
    assert_true(ctx.response_state() is Pending)
  })
  |> ignore
  let interaction = modal_interaction()
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(fw.process_with(interaction, gate~))
  inspect(
    errors.join("\n"),
    content=(
      #|InvalidCallback(kind=ModalSubmit, typ=UpdateMessage)
      #|InvalidCallback(kind=ModalSubmit, typ=DeferredUpdateMessage)
    ),
  )
  assert_true(capture.try_get() is None)
}

///|
async test "component update carries a poll and cleared content" {
  let fw = test_framework()
  fw.component("vote:", ctx => {
    ctx.update_message(clear_content=true, poll={
      question: { text: Some("Lunch?"), emoji: None, },
      answers: [{ text: Some("Soup"), emoji: None, }],
      duration: Some(1),
      allow_multiselect: None,
      layout_type: None,
    })
  })
  |> ignore
  let interaction = component_interaction("vote:1")
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(fw.process_with(interaction, gate~))
  json_inspect(capture.get().response.to_json(), content={
    "type": 7,
    "data": {
      "content": null,
      "poll": {
        "question": { "text": "Lunch?" },
        "answers": [{ "poll_media": { "text": "Soup" } }],
        "duration": 1,
      },
    },
  })
}
