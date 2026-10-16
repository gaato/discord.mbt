///|
async test "thread endpoints build paths and bodies for every optional shape" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  let bodies : Array[Json?] = []
  perform.val = Some((_route, path, _headers, body, _files) => {
    paths.push(path)
    bodies.push(body)
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let channel_id : @model.ChannelId = Id(1UL)
  let message_id : @model.MessageId = Id(2UL)
  client.get_reactions(channel_id, message_id, "x", after=Id(3UL)) |> ignore
  // Archive listings without a cursor send no `before`.
  for
    list in [
      () => client.list_public_archived_threads(channel_id),
      () => client.list_private_archived_threads(channel_id),
      () => client.list_joined_private_archived_threads(channel_id),
    ] {
    try list() catch {
      Deserialize(_) => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("fake archive response should not decode")
    }
  }
  try
    client.start_thread_from_message(
      channel_id,
      message_id,
      "thread",
      auto_archive_duration=OneDay,
      rate_limit_per_user=10,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("fake thread response should not decode")
  }
  assert_eq(paths, [
    "/api/v10/channels/1/messages/2/reactions/x?after=3", "/api/v10/channels/1/threads/archived/public",
    "/api/v10/channels/1/threads/archived/private", "/api/v10/channels/1/users/@me/threads/archived/private",
    "/api/v10/channels/1/messages/2/threads",
  ])
  guard bodies[bodies.length() - 1] is Some(body) else {
    fail("expected a thread body")
  }
  json_inspect(body, content={
    "name": "thread",
    "auto_archive_duration": 1440,
    "rate_limit_per_user": 10,
  })
}

///|
async test "forum threads need a starter message without Components V2" {
  let client = Client("test-token")
  defer client.close()
  let channel_id : @model.ChannelId = Id(1UL)
  try
    client.start_thread_in_forum_or_media_channel(channel_id, "thread")
  catch {
    Validation(message~) =>
      inspect(
        message,
        content="one of content/embeds/components/sticker_ids/files is required",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("empty starter message accepted")
  }
  try
    client.start_thread_in_forum_or_media_channel(channel_id, "thread", components=[
      TextDisplay({ id: None, content: "layout", }),
    ])
  catch {
    Validation(message~) => assert_true(message.contains("Components V2"))
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("Components V2 starter message accepted")
  }
}
