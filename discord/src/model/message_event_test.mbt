///|
fn message_update_with_timestamp(
  edited_timestamp : String,
) -> @model.MessageUpdateEvent raise {
  let fixture =
    #|{"id":"500","channel_id":"400","author":{"id":"202","username":"writer","discriminator":"0","avatar":null},"content":"message","timestamp":"2025-06-01T10:00:00Z","edited_timestamp":EDITED_TIMESTAMP,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
  @json.from_json(
    @json.parse(fixture.replace(old="EDITED_TIMESTAMP", new=edited_timestamp)),
  )
}

///|
test "MessageUpdateEvent::is_edit uses before or the timestamp heuristic" {
  let unedited = message_update_with_timestamp("null")
  let edited = message_update_with_timestamp("\"2025-06-01T10:05:00Z\"")
  assert_true(unedited.before is None)
  assert_false(unedited.is_edit())
  assert_true(edited.is_edit())
  assert_false({ ..unedited, before: Some(unedited.message), }.is_edit())
  assert_true({ ..unedited, before: Some(edited.message), }.is_edit())
  assert_false({ ..edited, before: Some(edited.message), }.is_edit())
}

///|
test "MessageUpdateEvent::is_edit tolerates sub-second precision changes" {
  // Live-observed: the edit dispatch carries microseconds, while a later pin
  // update for the same message echoes the timestamp with milliseconds only.
  let microseconds = message_update_with_timestamp(
    "\"2026-07-17T01:02:51.130180+00:00\"",
  )
  let milliseconds = message_update_with_timestamp(
    "\"2026-07-17T01:02:51.130000+00:00\"",
  )
  assert_false(
    { ..milliseconds, before: Some(microseconds.message), }.is_edit(),
  )
  let changed = message_update_with_timestamp(
    "\"2026-07-17T01:02:52.000000+00:00\"",
  )
  assert_true({ ..changed, before: Some(microseconds.message), }.is_edit())
}
