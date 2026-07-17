///|
fn paginator_message_page(ids : Array[Int]) -> Json raise {
  Json::array(
    ids.map(id => {
      @json.parse(
        "{\"id\":\"\{id}\",\"channel_id\":\"10\",\"author\":{\"id\":\"20\",\"username\":\"Nelly\",\"discriminator\":\"0\",\"global_name\":null,\"avatar\":null},\"content\":\"page \{id}\",\"timestamp\":\"2026-07-16T00:00:00Z\",\"edited_timestamp\":null,\"tts\":false,\"mention_everyone\":false,\"mentions\":[],\"mention_roles\":[],\"attachments\":[],\"embeds\":[],\"pinned\":false,\"type\":0}",
      )
    }),
  )
}

///|
async test "message paginator after uses maximum cursor from canned pages" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    calls.val += 1
    let body = if calls.val == 1 {
      paginator_message_page([101, 103])
    } else {
      Json::array([])
    }
    { status: 200, headers: Map([]), body }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let after : @model.MessageId = Id(100UL)
  let paginator = client.paginate_messages(channel_id, after~, page_size=2)
  guard paginator.next_page() is Some(first) else {
    fail("expected first page")
  }
  assert_eq(first.map(message => message.id.value()), [101UL, 103UL])
  assert_true(paginator.next_page() is None)
  assert_eq(paths, [
    "/api/v10/channels/10/messages?limit=2&after=100", "/api/v10/channels/10/messages?limit=2&after=103",
  ])
}

///|
async test "message paginator before uses minimum cursor from canned pages" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    calls.val += 1
    let body = if calls.val == 1 {
      paginator_message_page([99, 98])
    } else {
      Json::array([])
    }
    { status: 200, headers: Map([]), body }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let before : @model.MessageId = Id(100UL)
  let paginator = client.paginate_messages(channel_id, before~, page_size=2)
  guard paginator.next_page() is Some(first) else {
    fail("expected first page")
  }
  assert_eq(first.map(message => message.id.value()), [99UL, 98UL])
  assert_true(paginator.next_page() is None)
  assert_eq(paths, [
    "/api/v10/channels/10/messages?limit=2&before=100", "/api/v10/channels/10/messages?limit=2&before=98",
  ])
}

///|
async test "message paginator around performs one fixed-cursor page" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    paths.push(path)
    { status: 200, headers: Map([]), body: paginator_message_page([100]) }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let around : @model.MessageId = Id(100UL)
  let paginator = client.paginate_messages(channel_id, around~, page_size=2)
  guard paginator.next_page() is Some(first) else {
    fail("expected first page")
  }
  assert_eq(first.map(message => message.id.value()), [100UL])
  assert_true(paginator.next_page() is None)
  assert_eq(paths, ["/api/v10/channels/10/messages?limit=2&around=100"])
}
