///|
/// Wire-shape coverage for the interaction parameters added from the
/// 2026-07-16 parameter-completeness audit. The with_response callback
/// envelope cannot be probed live (it needs a user-initiated interaction),
/// so its query and decode are pinned here.
async test "create interaction response with callback asks for the envelope" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_path = Ref("")
  perform.val = Some((_route, path, _headers, _body, _files) => {
    captured_path.val = path
    {
      status: 200,
      headers: Map([]),
      body: {
        "interaction": {
          "id": "1",
          "type": 2,
          "response_message_id": "9",
          "response_message_loading": false,
          "response_message_ephemeral": false,
        },
        "resource": { "type": 4 },
      },
    }
  })
  let interaction_id : @model.InteractionId = Id(1UL)
  let response = @model.InteractionResponse::{
    typ: ChannelMessageWithSource,
    data: Some({ "content": "hi" }),
  }
  let callback = client.create_interaction_response_with_callback(
    interaction_id, "tok", response,
  )
  inspect(
    captured_path.val,
    content="/api/v10/interactions/1/tok/callback?with_response=true",
  )
  assert_eq(callback.interaction.response_message_id, Some(Id(9UL)))
  assert_eq(callback.resource.unwrap().typ, ChannelMessageWithSource)
  // the plain variant keeps an empty query
  client.create_interaction_response(interaction_id, "tok", response)
  inspect(captured_path.val, content="/api/v10/interactions/1/tok/callback")
}

///|
async test "create followup forwards the poll body" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let application_id : @model.ApplicationId = Id(1UL)
  let poll = @model.PollCreateRequest::{
    question: { text: Some("q?"), emoji: None, },
    answers: [{ text: Some("a"), emoji: None, }],
    duration: None,
    allow_multiselect: None,
    layout_type: None,
  }
  try client.create_followup(application_id, "tok", poll~) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "poll": {
      "question": { "text": "q?" },
      "answers": [{ "poll_media": { "text": "a" } }],
    },
  })
}

///|
async test "edit original response forwards flags, poll, and kept attachments" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let application_id : @model.ApplicationId = Id(1UL)
  let poll = @model.PollCreateRequest::{
    question: { text: Some("q?"), emoji: None, },
    answers: [{ text: Some("a"), emoji: None, }],
    duration: None,
    allow_multiselect: None,
    layout_type: None,
  }
  try
    client.edit_original_response(
      application_id,
      "tok",
      flags=@model.MessageFlags::suppress_embeds(),
      poll~,
      keep_attachments=[
        {
          id: Id(7UL),
          filename: None,
          title: None,
          description: None,
          duration_secs: None,
          waveform: None,
          is_spoiler: None,
        },
      ],
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "flags": 4,
    "poll": {
      "question": { "text": "q?" },
      "answers": [{ "poll_media": { "text": "a" } }],
    },
    "attachments": [{ "id": "7" }],
  })
}

///|
async test "edit followup forwards flags" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let application_id : @model.ApplicationId = Id(1UL)
  let message_id : @model.MessageId = Id(2UL)
  try
    client.edit_followup(
      application_id,
      "tok",
      message_id,
      content="hi",
      flags=@model.MessageFlags::suppress_embeds(),
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={ "content": "hi", "flags": 4 })
}
