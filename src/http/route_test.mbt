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

///|
test "reaction buckets squash message emoji and user ids" {
  let channel_id : @model.ChannelId = @model.Id(10UL)
  let first_message : @model.MessageId = @model.Id(20UL)
  let second_message : @model.MessageId = @model.Id(21UL)
  let first_user : @model.UserId = @model.Id(30UL)
  let second_user : @model.UserId = @model.Id(31UL)
  let own = @http.Route::DeleteOwnReaction(
    channel_id~,
    message_id=first_message,
    emoji="wave%3A40",
  )
  let first_user_reaction = @http.Route::DeleteUserReaction(
    channel_id~,
    message_id=first_message,
    emoji="wave%3A40",
    user_id=first_user,
  )
  let second_user_reaction = @http.Route::DeleteUserReaction(
    channel_id~,
    message_id=second_message,
    emoji="future%3A41",
    user_id=second_user,
  )
  inspect(own.bucket(), content="DELETE:/channels/10/messages/{}/reactions/{}")
  assert_true(own.bucket() == first_user_reaction.bucket())
  assert_true(first_user_reaction.bucket() == second_user_reaction.bucket())
  let get = @http.Route::GetReactions(
    channel_id~,
    message_id=first_message,
    emoji="wave%3A40",
    query="?limit=25&after=30",
  )
  inspect(
    get.path(),
    content="/channels/10/messages/20/reactions/wave%3A40?limit=25&after=30",
  )
  inspect(get.bucket(), content="GET:/channels/10/messages/{}/reactions/{}")
}

///|
test "followup routes keep webhook majors and need no bot auth" {
  let application_id : @model.ApplicationId = @model.Id(100UL)
  let message_id : @model.MessageId = @model.Id(200UL)
  let get = @http.Route::GetFollowupMessage(
    application_id~,
    token="tok",
    message_id~,
  )
  let edit = @http.Route::EditFollowupMessage(
    application_id~,
    token="tok",
    message_id~,
  )
  let del = @http.Route::DeleteFollowupMessage(
    application_id~,
    token="tok",
    message_id~,
  )
  inspect(get.path(), content="/webhooks/100/tok/messages/200")
  inspect(get.bucket(), content="GET:/webhooks/100/tok/messages/{}")
  for route in [get, edit, del] {
    assert_true(route.is_interaction())
    assert_false(route.needs_auth())
  }
  let original = @http.Route::DeleteOriginalInteractionResponse(
    application_id~,
    token="tok",
  )
  assert_true(original.is_interaction())
  assert_false(original.needs_auth())
}

///|
test "guild role routes keep guild major and support audit reasons" {
  let guild_id : @model.GuildId = @model.Id(500UL)
  let first_role : @model.RoleId = @model.Id(600UL)
  let second_role : @model.RoleId = @model.Id(601UL)
  let modify = @http.Route::ModifyGuildRole(guild_id~, role_id=first_role)
  let other = @http.Route::ModifyGuildRole(guild_id~, role_id=second_role)
  inspect(modify.path(), content="/guilds/500/roles/600")
  inspect(modify.bucket(), content="PATCH:/guilds/500/roles/{}")
  assert_true(modify.bucket() == other.bucket())
  assert_true(modify.supports_reason())
  assert_true(@http.Route::CreateGuildRole(guild_id~).supports_reason())
  assert_true(
    @http.Route::DeleteGuildRole(guild_id~, role_id=first_role).supports_reason(),
  )
  let user_id : @model.UserId = @model.Id(700UL)
  let member_role = @http.Route::AddGuildMemberRole(
    guild_id~,
    user_id~,
    role_id=first_role,
  )
  assert_true(member_role.supports_reason())
}
