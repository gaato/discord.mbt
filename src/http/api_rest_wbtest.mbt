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
}
