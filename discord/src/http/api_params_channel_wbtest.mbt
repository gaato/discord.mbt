///|
/// Wire-shape coverage for the channel parameters added from the 2026-07-16
/// parameter-completeness audit.
async test "modify channel forwards voice and forum fields" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(1UL)
  try
    client.modify_channel(
      channel_id,
      typ=GuildAnnouncement,
      bitrate=64000,
      user_limit=5,
      permission_overwrites=[
        {
          id: Id(9UL),
          typ: Role,
          allow: @model.Permissions::none(),
          deny: @model.Permissions::send_messages(),
        },
      ],
      rtc_region="japan",
      video_quality_mode=Full,
      default_auto_archive_duration=OneDay,
      available_tags=[
        {
          id: None,
          name: "bug",
          moderated: Some(true),
          emoji_id: None,
          emoji_name: Some("🐛"),
        },
      ],
      default_reaction_emoji={ emoji_id: Null, emoji_name: Value("👍"), },
      default_thread_rate_limit_per_user=30,
      default_sort_order=CreationDate,
      default_forum_layout=GalleryView,
      icon="data:image/png;base64,AAAA",
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail channel decoding")
  }
  json_inspect(captured_body.val, content={
    "type": 5,
    "bitrate": 64000,
    "user_limit": 5,
    "permission_overwrites": [
      { "id": "9", "type": 0, "allow": "0", "deny": "2048" },
    ],
    "rtc_region": "japan",
    "video_quality_mode": 2,
    "default_auto_archive_duration": 1440,
    "available_tags": [
      { "name": "bug", "moderated": true, "emoji_name": "🐛" },
    ],
    "default_reaction_emoji": { "emoji_id": null, "emoji_name": "👍" },
    "default_thread_rate_limit_per_user": 30,
    "default_sort_order": 1,
    "default_forum_layout": 2,
    "icon": "data:image/png;base64,AAAA",
  })
  // nullable clears send explicit nulls
  try
    client.modify_channel(
      channel_id,
      clear_rtc_region=true,
      clear_video_quality_mode=true,
      clear_default_reaction_emoji=true,
      clear_default_sort_order=true,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail channel decoding")
  }
  json_inspect(captured_body.val, content={
    "rtc_region": null,
    "video_quality_mode": null,
    "default_reaction_emoji": null,
    "default_sort_order": null,
  })
}

///|
async test "create guild channel forwards forum defaults" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(1UL)
  try
    client.create_guild_channel(
      guild_id,
      "probe-forum",
      typ=GuildForum,
      rtc_region="japan",
      video_quality_mode=Auto,
      default_auto_archive_duration=OneHour,
      available_tags=[
        {
          id: None,
          name: "tag",
          moderated: None,
          emoji_id: None,
          emoji_name: None,
        },
      ],
      default_reaction_emoji={ emoji_id: Null, emoji_name: Value("👍"), },
      default_thread_rate_limit_per_user=10,
      default_sort_order=LatestActivity,
      default_forum_layout=ListView,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail channel decoding")
  }
  json_inspect(captured_body.val, content={
    "name": "probe-forum",
    "type": 15,
    "rtc_region": "japan",
    "video_quality_mode": 1,
    "default_auto_archive_duration": 60,
    "available_tags": [{ "name": "tag" }],
    "default_reaction_emoji": { "emoji_id": null, "emoji_name": "👍" },
    "default_thread_rate_limit_per_user": 10,
    "default_sort_order": 0,
    "default_forum_layout": 1,
  })
}

///|
async test "create channel invite forwards targets and roles" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(1UL)
  try
    client.create_channel_invite(
      channel_id,
      max_age=0,
      target_type=Stream,
      target_user_id=Id(5UL),
      role_ids=[Id(6UL)],
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail invite decoding")
  }
  json_inspect(captured_body.val, content={
    "max_age": 0,
    "target_type": 1,
    "target_user_id": "5",
    "role_ids": ["6"],
  })
  // required-if validations
  try client.create_channel_invite(channel_id, target_type=Stream) catch {
    Validation(message~) =>
      inspect(message, content="target_type Stream requires target_user_id")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a validation error")
  }
  try
    client.create_channel_invite(channel_id, target_type=EmbeddedApplication)
  catch {
    Validation(message~) =>
      inspect(
        message,
        content="target_type EmbeddedApplication requires target_application_id",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a validation error")
  }
}

///|
async test "create channel invite uploads the target-users file as multipart" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  let captured_files = Ref(0)
  perform.val = Some((_route, _path, _headers, body, files) => {
    captured_body.val = body.unwrap_or(Json::null())
    captured_files.val = files.map_or(0, fs => fs.length())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(1UL)
  try
    client.create_channel_invite(
      channel_id,
      max_uses=1,
      target_users_file=FileUpload("users.csv", b"123", content_type="text/csv"),
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail invite decoding")
  }
  json_inspect(captured_body.val, content={ "max_uses": 1 })
  assert_eq(captured_files.val, 1)
}

///|
async test "edit channel permissions omits unset allow and deny" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(1UL)
  let overwrite_id : @model.GenericId = Id(2UL)
  client.edit_channel_permissions(
    channel_id,
    overwrite_id,
    Role,
    deny=@model.Permissions::send_messages(),
  )
  json_inspect(captured_body.val, content={ "deny": "2048", "type": 0 })
  client
  .channel_ref(channel_id)
  .edit_permissions(
    overwrite_id,
    Member,
    allow=@model.Permissions::view_channel(),
  )
  json_inspect(captured_body.val, content={ "allow": "1024", "type": 1 })
}
