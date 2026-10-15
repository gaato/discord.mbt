///|
/// Invite target users set without a CSV: the single-user and bulk endpoints
/// and `target_user_ids` on invite creation.

///|
async test "invite target user endpoints send the documented requests" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured : Array[String] = []
  perform.val = Some((route, path, _headers, body, files) => {
    assert_true(files is None)
    captured.push(
      "\{@debug.to_string(route.method_())} \{path} \{body.map(json => json.stringify()).unwrap_or("-")}",
    )
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let user : @model.UserId = Id(7UL)
  let others : Array[@model.UserId] = [Id(8UL), Id(9UL)]
  client.add_invite_target_user("code a", user)
  client.remove_invite_target_user("code a", user)
  client.bulk_add_invite_target_users("code a", others)
  client.bulk_delete_invite_target_users("code a", others)
  let invite = client.invite_ref("code a")
  invite.add_target_user(user)
  invite.remove_target_user(user)
  invite.bulk_add_target_users(others)
  invite.bulk_delete_target_users(others)
  let expected = [
    "Put /api/v10/invites/code%20a/target-users/7 -", "Delete /api/v10/invites/code%20a/target-users/7 -",
    "Post /api/v10/invites/code%20a/target-users/bulk-add {\"user_ids\":[\"8\",\"9\"]}",
    "Post /api/v10/invites/code%20a/target-users/bulk-delete {\"user_ids\":[\"8\",\"9\"]}",
  ]
  assert_eq(captured, expected + expected)
}

///|
async test "invite target user bulk endpoints accept at most 1000 users" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let sent = Ref(0)
  perform.val = Some((_route, _path, _headers, _body, _files) => {
    sent.val += 1
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let limit : Array[@model.UserId] = Array::makei(1000, i => Id(i.to_uint64()))
  client.bulk_add_invite_target_users("code", limit)
  let over = limit + [Id(1000UL)]
  for
    call in [
      () => client.bulk_add_invite_target_users("code", over),
      () => client.bulk_delete_invite_target_users("code", over),
    ] {
    try call() catch {
      Validation(message~) =>
        inspect(message, content="invite target users exceed 1000 users")
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected a validation error")
    }
  }
  inspect(sent.val, content="1")
}

///|
async test "create channel invite sends target_user_ids as JSON" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  let captured_files = Ref(-1)
  perform.val = Some((_route, _path, _headers, body, files) => {
    captured_body.val = body.unwrap_or(Json::null())
    captured_files.val = files.map_or(0, fs => fs.length())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(1UL)
  try
    client
    .channel_ref(channel_id)
    .create_invite(max_uses=1, target_user_ids=[Id(7UL)])
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail invite decoding")
  }
  json_inspect(captured_body.val, content={
    "max_uses": 1,
    "target_user_ids": ["7"],
  })
  assert_eq(captured_files.val, 0)
}

///|
async test "create channel invite rejects both target user sources and over 1000 ids" {
  let (client, perform) = offline_test_client()
  defer client.close()
  perform.val = Some((_route, _path, _headers, _body, _files) => {
    fail("an invalid invite must not be sent")
  })
  let channel_id : @model.ChannelId = Id(1UL)
  let file = FileUpload("users.csv", b"user_id\n7\n", content_type="text/csv")
  let over : Array[@model.UserId] = Array::makei(1001, i => Id(i.to_uint64()))
  for
    case in [
      (
        () => {
          client.create_channel_invite(
            channel_id,
            target_user_ids=[Id(7UL)],
            target_users_file=file,
          )
        },
        "target_user_ids and target_users_file are mutually exclusive",
      ),
      (
        () => client.create_channel_invite(channel_id, target_user_ids=over),
        "target_user_ids exceeds 1000 users",
      ),
    ] {
    let (call, expected) = case
    try call() catch {
      Validation(message~) => assert_eq(message, expected)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected a validation error")
    }
  }
}
