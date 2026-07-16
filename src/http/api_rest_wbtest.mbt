///|
test "edit current application body includes provided values" {
  let install_params : @model.InstallParams = {
    scopes: ["bot", "applications.commands"],
    permissions: @model.Permissions::none(),
  }
  let integration_types_config : Map[
    String,
    @model.ApplicationIntegrationTypeConfiguration,
  ] = { "0": { oauth2_install_params: Some(install_params) } }
  json_inspect(
    edit_current_application_body(
      custom_install_url="https://example.com/install",
      description="MoonBit bot",
      role_connections_verification_url="https://example.com/roles",
      install_params~,
      integration_types_config~,
      flags=@model.ApplicationFlags::gateway_presence_limited(),
      icon="data:image/png;base64,aWNvbg==",
      cover_image="data:image/png;base64,Y292ZXI=",
      interactions_endpoint_url="https://example.com/interactions",
      tags=["moonbit", "discord"],
      event_webhooks_url="https://example.com/events",
      event_webhooks_status=Enabled,
      event_webhooks_types=["APPLICATION_AUTHORIZED"],
    ),
    content={
      "custom_install_url": "https://example.com/install",
      "description": "MoonBit bot",
      "role_connections_verification_url": "https://example.com/roles",
      "install_params": {
        "scopes": ["bot", "applications.commands"],
        "permissions": "0",
      },
      "integration_types_config": {
        "0": {
          "oauth2_install_params": {
            "scopes": ["bot", "applications.commands"],
            "permissions": "0",
          },
        },
      },
      "flags": 8192,
      "icon": "data:image/png;base64,aWNvbg==",
      "cover_image": "data:image/png;base64,Y292ZXI=",
      "interactions_endpoint_url": "https://example.com/interactions",
      "tags": ["moonbit", "discord"],
      "event_webhooks_url": "https://example.com/events",
      "event_webhooks_status": 2,
      "event_webhooks_types": ["APPLICATION_AUTHORIZED"],
    },
  )
}

///|
test "edit current application body distinguishes clear and omission" {
  json_inspect(
    edit_current_application_body(
      clear_custom_install_url=true,
      clear_description=true,
      clear_role_connections_verification_url=true,
      clear_install_params=true,
      clear_icon=true,
      clear_cover_image=true,
      clear_interactions_endpoint_url=true,
      clear_tags=true,
      clear_event_webhooks_url=true,
    ),
    content={
      "custom_install_url": null,
      "description": null,
      "role_connections_verification_url": null,
      "install_params": null,
      "icon": null,
      "cover_image": null,
      "interactions_endpoint_url": null,
      "tags": null,
      "event_webhooks_url": null,
    },
  )
  json_inspect(edit_current_application_body(), content=Json::empty_object())
}

///|
test "application emoji request bodies contain only supported fields" {
  json_inspect(
    create_application_emoji_body("wave", "data:image/png;base64,aW1hZ2U="),
    content={ "name": "wave", "image": "data:image/png;base64,aW1hZ2U=" },
  )
  json_inspect(modify_application_emoji_body("hello"), content={
    "name": "hello",
  })
}

///|
test "application emoji list decodes the items envelope" {
  let items = decode_application_emoji_items(
    @json.parse(
      (
        #|{
        #|  "items": [
        #|    {"id": "10", "name": "wave"},
        #|    {"id": "11", "name": "party", "animated": true}
        #|  ]
        #|}
      ),
    ),
  )
  inspect(items.length(), content="2")
  debug_inspect(
    items.map(emoji => emoji.name),
    content=(
      #|[Value("wave"), Value("party")]
    ),
  )
}

///|
test "voice state patch bodies include provided values" {
  let channel_id : @model.ChannelId = Id(10UL)
  let timestamp_fixture =
    #|"2026-08-01T10:00:00Z"
  let timestamp : @model.Timestamp = @json.from_json(
    @json.parse(timestamp_fixture),
  )
  json_inspect(
    modify_current_user_voice_state_body(
      Some(channel_id),
      Some(true),
      Some(timestamp),
      false,
    ),
    content={
      "channel_id": "10",
      "suppress": true,
      "request_to_speak_timestamp": "2026-08-01T10:00:00Z",
    },
  )
  json_inspect(modify_user_voice_state_body(channel_id, Some(false)), content={
    "channel_id": "10",
    "suppress": false,
  })
}

///|
test "current user voice state body distinguishes timestamp clear and omission" {
  json_inspect(modify_current_user_voice_state_body(None, None, None, true), content={
    "request_to_speak_timestamp": null,
  })
  json_inspect(
    modify_current_user_voice_state_body(None, None, None, false),
    content=Json::empty_object(),
  )
}

///|
test "thread member query includes values and omits absent parameters" {
  let after : @model.UserId = Id(20UL)
  inspect(
    thread_members_query(Some(true), Some(after), Some(100)),
    content="?with_member=true&after=20&limit=100",
  )
  inspect(thread_members_query(None, None, None), content="")
  inspect(
    thread_members_query(Some(false), None, None),
    content="?with_member=false",
  )
}

///|
test "archived thread query includes values and omits absent parameters" {
  inspect(
    archived_threads_query(Some("2024-01-02T03:04:05.000000+00:00"), Some(50)),
    content="?before=2024-01-02T03:04:05.000000%2B00:00&limit=50",
  )
  inspect(archived_threads_query(None, None), content="")
  inspect(archived_threads_query(None, Some(25)), content="?limit=25")
}

///|
test "follow announcement channel body uses the destination channel id" {
  let channel_id : @model.ChannelId = Id(20UL)
  json_inspect(follow_announcement_channel_body(channel_id), content={
    "webhook_channel_id": "20",
  })
}

///|
test "voice channel status body sends a value or explicit null" {
  json_inspect(set_voice_channel_status_body(Some("In a meeting")), content={
    "status": "In a meeting",
  })
  json_inspect(set_voice_channel_status_body(None), content={ "status": null })
}

///|
test "guild message search query includes scalar parameters" {
  let max_id : @model.MessageId = Id(90UL)
  let min_id : @model.MessageId = Id(10UL)
  inspect(
    search_guild_messages_query(
      limit=25,
      offset=50,
      slop=5,
      mention_everyone=true,
      pinned=false,
      include_nsfw=true,
      sort_by="timestamp",
      sort_order="desc",
      max_id~,
      min_id~,
    ),
    content="?limit=25&offset=50&slop=5&mention_everyone=true&pinned=false&include_nsfw=true&sort_by=timestamp&sort_order=desc&max_id=90&min_id=10",
  )
}

///|
test "guild message search query repeats array parameters" {
  let channel_ids : Array[@model.ChannelId] = [Id(1UL), Id(2UL)]
  let author_ids : Array[@model.UserId] = [Id(3UL), Id(4UL)]
  let mentions : Array[@model.UserId] = [Id(5UL)]
  let role_ids : Array[@model.RoleId] = [Id(6UL)]
  let replied_users : Array[@model.UserId] = [Id(7UL)]
  let replied_messages : Array[@model.MessageId] = [Id(8UL)]
  inspect(
    search_guild_messages_query(
      channel_id=channel_ids,
      author_type=["user", "webhook"],
      author_id=author_ids,
      mentions~,
      mentions_role_id=role_ids,
      replied_to_user_id=replied_users,
      replied_to_message_id=replied_messages,
      has=["link", "file"],
      embed_type=["image"],
    ),
    content="?channel_id=1&channel_id=2&author_type=user&author_type=webhook&author_id=3&author_id=4&mentions=5&mentions_role_id=6&replied_to_user_id=7&replied_to_message_id=8&has=link&has=file&embed_type=image",
  )
}

///|
test "guild message search query percent-encodes free text" {
  inspect(
    search_guild_messages_query(
      content="hello + world/&?=雪",
      embed_provider=["Moon & Stars"],
      link_hostname=["example.com/a?b=c"],
      attachment_filename=["report #1.csv"],
      attachment_extension=["tar+gz"],
    ),
    content="?content=hello%20%2B%20world%2F%26%3F%3D%E9%9B%AA&embed_provider=Moon%20%26%20Stars&link_hostname=example.com%2Fa%3Fb%3Dc&attachment_filename=report%20%231.csv&attachment_extension=tar%2Bgz",
  )
}

///|
test "guild message search query is empty without parameters" {
  inspect(search_guild_messages_query(), content="")
}

///|
test "edit application command permissions body wraps permission records" {
  let permission : @model.ApplicationCommandPermission = {
    id: Id(10UL),
    typ: Role,
    permission: true,
  }
  json_inspect(edit_application_command_permissions_body([permission]), content={
    "permissions": [{ "id": "10", "type": 1, "permission": true }],
  })
}

///|
test "update application role connection metadata body is a raw array" {
  let fixture =
    #|[{"type":3,"key":"level","name":"Level","description":"Account level"}]
  let records : Array[@model.ApplicationRoleConnectionMetadata] = @json.from_json(
    @json.parse(fixture),
  )
  json_inspect(
    update_application_role_connection_metadata_records_body(records),
    content=[
      {
        "type": 3,
        "key": "level",
        "name": "Level",
        "description": "Account level",
      },
    ],
  )
}

///|
test "update current user application role connection body handles values and omission" {
  json_inspect(
    update_current_user_application_role_connection_body(
      Some("Steam"),
      Some("moonbit-user"),
      Some({ "level": "42", "verified": "true" }),
    ),
    content={
      "platform_name": "Steam",
      "platform_username": "moonbit-user",
      "metadata": { "level": "42", "verified": "true" },
    },
  )
  json_inspect(
    update_current_user_application_role_connection_body(None, None, None),
    content=Json::empty_object(),
  )
}

///|
test "auto moderation create and patch bodies preserve arrays" {
  let metadata : @model.TriggerMetadata = {
    keyword_filter: Some(["moonbit"]),
    presets: None,
    allow_list: Some([]),
    regex_patterns: None,
    mention_total_limit: None,
    mention_raid_protection_enabled: None,
  }
  let action_fixture =
    #|{"type":1,"metadata":{"custom_message":"stop"}}
  let action : @model.AutoModerationAction = @json.from_json(
    @json.parse(action_fixture),
  )
  json_inspect(
    auto_moderation_rule_body(
      Some("links"),
      Some(MessageSend),
      Some(Keyword),
      Some(metadata),
      Some([action]),
      Some(true),
      Some([]),
      Some([]),
    ),
    content={
      "name": "links",
      "event_type": 1,
      "trigger_type": 1,
      "trigger_metadata": { "keyword_filter": ["moonbit"], "allow_list": [] },
      "actions": [{ "type": 1, "metadata": { "custom_message": "stop" } }],
      "enabled": true,
      "exempt_roles": [],
      "exempt_channels": [],
    },
  )
}

///|
test "scheduled event request bodies model null and recurrence explicitly" {
  let recurrence_fixture =
    #|{"start":"2026-08-01T10:00:00Z","end":null,"frequency":2,"interval":1,"by_weekday":[0]}
  let recurrence : @model.GuildScheduledEventRecurrenceRule = @json.from_json(
    @json.parse(recurrence_fixture),
  )
  let start_fixture =
    #|"2026-08-01T10:00:00Z"
  let end_fixture =
    #|"2026-08-01T12:00:00Z"
  let start : @model.Timestamp = @json.from_json(@json.parse(start_fixture))
  let end : @model.Timestamp = @json.from_json(@json.parse(end_fixture))
  json_inspect(
    scheduled_event_create_body(
      None,
      true,
      Some({ location: Some("Community Hall") }),
      false,
      "Meetup",
      GuildOnly,
      start,
      Some(end),
      false,
      Some("Community meetup"),
      External,
      None,
      Some(recurrence),
    ),
    content={
      "channel_id": null,
      "entity_metadata": { "location": "Community Hall" },
      "name": "Meetup",
      "privacy_level": 2,
      "scheduled_start_time": "2026-08-01T10:00:00Z",
      "scheduled_end_time": "2026-08-01T12:00:00Z",
      "description": "Community meetup",
      "entity_type": 3,
      "recurrence_rule": {
        "start": "2026-08-01T10:00:00Z",
        "end": null,
        "frequency": 2,
        "interval": 1,
        "by_weekday": [0],
      },
    },
  )
}

///|
test "guild sticker multipart uses named form fields and file" {
  let body = @model.ObjBuilder()
    .field("name", "Wave")
    .field("description", "Wumpus waves")
    .field("tags", "wave,hello")
    .build()
  let file = FileUpload("wave.png", b"PNG", content_type="image/png")
  inspect(
    render_parts(
      multipart_form_parts("B", sticker_form_fields(body), "file", file),
    ),
    content=(
      #|--B<CR><LF>
      #|content-disposition: form-data; name="name"<CR><LF>
      #|<CR><LF>
      #|Wave<CR><LF>
      #|--B<CR><LF>
      #|content-disposition: form-data; name="description"<CR><LF>
      #|<CR><LF>
      #|Wumpus waves<CR><LF>
      #|--B<CR><LF>
      #|content-disposition: form-data; name="tags"<CR><LF>
      #|<CR><LF>
      #|wave,hello<CR><LF>
      #|--B<CR><LF>
      #|content-disposition: form-data; name="file"; filename="wave.png"<CR><LF>
      #|content-type: image/png<CR><LF>
      #|<CR><LF>
      #|PNG<CR><LF>
      #|--B--<CR><LF>
      #|
    ),
  )
}

///|
test "stage sticker and soundboard validation is pre-IO" {
  try validate_stage_topic(Some("")) catch {
    Validation(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected stage topic validation")
  }
  try validate_sticker_fields(Some("x"), None, None) catch {
    Validation(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected sticker name validation")
  }
  try validate_soundboard_fields(Some("ok"), Some(1.1)) catch {
    Validation(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected soundboard volume validation")
  }
}

///|
async test "REST pagination limits fail before transport" {
  let client = Client("test-token", base_url="http://127.0.0.1:1")
  defer client.close()
  let guild_id : @model.GuildId = Id(10UL)
  let event_id : @model.ScheduledEventId = Id(20UL)
  let channel_id : @model.ChannelId = Id(30UL)
  let message_id : @model.MessageId = Id(40UL)
  try client.get_guild_audit_log(guild_id, limit=0) catch {
    Validation(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected audit limit validation")
  }
  try
    client.list_guild_scheduled_event_users(guild_id, event_id, limit=101)
  catch {
    Validation(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected scheduled event user limit validation")
  }
  try
    client.get_poll_answer_voters(channel_id, message_id, 1, limit=101)
  catch {
    Validation(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected poll voter limit validation")
  }
  try client.list_thread_members(channel_id, limit=0) catch {
    Validation(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected thread member limit validation")
  }
}
