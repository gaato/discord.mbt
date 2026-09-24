///|
async test "channel pins v2 encodes pagination and decodes an empty page" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  perform.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: { "items": [], "has_more": false }, }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let before : @model.Timestamp = @json.from_json(
    @json.parse("\"2026-08-26T12:34:56Z\""),
  )
  let page = client.get_channel_pins(channel_id, before~, limit=25)
  assert_true(page.items.is_empty())
  assert_false(page.has_more)
  assert_eq(paths, [
    "/api/v10/channels/10/messages/pins?before=2026-08-26T12%3A34%3A56Z&limit=25",
  ])
}

///|
async test "channel pins v2 validates the documented page size" {
  let client = Client("test-token")
  defer client.close()
  let channel_id : @model.ChannelId = Id(10UL)
  for limit in [0, 51] {
    try client.get_channel_pins(channel_id, limit~) |> ignore catch {
      DiscordHttpError::Validation(message~) =>
        assert_eq(message, "channel pin limit must be between 1 and 50")
      error => fail("unexpected pin validation error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid channel pin limit unexpectedly succeeded")
    }
  }
}
