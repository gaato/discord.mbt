///|
test "route paths and buckets" {
  let channel_id : @model.ChannelId = @model.Id(100UL)
  let message_id : @model.MessageId = @model.Id(200UL)
  let create = @http.Route::CreateMessage(channel_id~)
  inspect(create.path(), content="/channels/100/messages")
  inspect(create.bucket(), content="POST:/channels/100/messages")
  let del = @http.Route::DeleteMessage(channel_id~, message_id~)
  inspect(del.path(), content="/channels/100/messages/200")
  // message ids are squashed in the bucket; delete has its own bucket
  inspect(del.bucket(), content="DELETE:/channels/100/messages/{}")
  let edit = @http.Route::EditMessage(channel_id~, message_id~)
  inspect(edit.bucket(), content="PATCH:/channels/100/messages/{}")
}

///|
test "interaction routes are global-exempt and unauthenticated" {
  let interaction_id : @model.InteractionId = @model.Id(1UL)
  let callback = @http.Route::CreateInteractionResponse(
    interaction_id~,
    token="tok",
  )
  assert_true(callback.is_interaction())
  assert_false(callback.needs_auth())
  inspect(callback.path(), content="/interactions/1/tok/callback")
  let msg = @http.Route::CreateMessage(channel_id=@model.Id(2UL))
  assert_false(msg.is_interaction())
  assert_true(msg.needs_auth())
}
