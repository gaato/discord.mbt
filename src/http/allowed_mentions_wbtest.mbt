///|
test "create_message applies the safe client allowed mentions default" {
  let client = Client::new("test-token")
  let body = client
    .with_channel_allowed_mentions(
      @model.ObjBuilder::new().field("content", "hello"),
      None,
    )
    .build()
  json_inspect(body, content={
    "content": "hello",
    "allowed_mentions": { "parse": ["users", "roles"] },
  })
}

///|
test "create_message honors client and per-request allowed mention overrides" {
  let client = Client::new(
    "test-token",
    default_allowed_mentions=@model.AllowedMentions::none(),
  )
  json_inspect(
    client.with_channel_allowed_mentions(@model.ObjBuilder::new(), None).build(),
    content={ "allowed_mentions": { "parse": [] } },
  )
  let explicit = @model.AllowedMentions::new(parse=[
    @model.AllowedMentionType::Everyone,
  ])
  json_inspect(
    client
    .with_channel_allowed_mentions(@model.ObjBuilder::new(), Some(explicit))
    .build(),
    content={ "allowed_mentions": { "parse": ["everyone"] } },
  )
}
