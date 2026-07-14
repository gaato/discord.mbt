///|
struct RouteMetadata {
  name : String
  method_name : String
  path : String
  bucket : String
  needs_auth : Bool
  supports_reason : Bool
} derive(Debug)

///|
fn route_metadata(name : String, route : @http.Route) -> RouteMetadata {
  {
    name,
    method_name: route.method_().to_string(),
    path: route.path(),
    bucket: route.bucket(),
    needs_auth: route.needs_auth(),
    supports_reason: route.supports_reason(),
  }
}

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
test "current application route metadata" {
  let route = @http.Route::GetCurrentApplication
  debug_inspect(
    route_metadata("current-application", route),
    content=(
      #|{
      #|  name: "current-application",
      #|  method_name: "Get",
      #|  path: "/applications/@me",
      #|  bucket: "GET:/applications/@me",
      #|  needs_auth: true,
      #|  supports_reason: false,
      #|}
    ),
  )
}

///|
test "webhook route metadata" {
  let channel_id : @model.ChannelId = @model.Id(10UL)
  let guild_id : @model.GuildId = @model.Id(20UL)
  let webhook_id : @model.WebhookId = @model.Id(30UL)
  let message_id : @model.MessageId = @model.Id(40UL)
  debug_inspect(
    [
      route_metadata("create", @http.Route::CreateWebhook(channel_id~)),
      route_metadata("channel", @http.Route::GetChannelWebhooks(channel_id~)),
      route_metadata("guild", @http.Route::GetGuildWebhooks(guild_id~)),
      route_metadata("get", @http.Route::GetWebhook(webhook_id~)),
      route_metadata("modify", @http.Route::ModifyWebhook(webhook_id~)),
      route_metadata("delete", @http.Route::DeleteWebhook(webhook_id~)),
      route_metadata(
        "execute",
        @http.Route::ExecuteWebhook(
          webhook_id~,
          token="tok",
          query="?wait=true",
        ),
      ),
      route_metadata(
        "get-message",
        @http.Route::GetWebhookMessage(webhook_id~, token="tok", message_id~),
      ),
      route_metadata(
        "edit-message",
        @http.Route::EditWebhookMessage(webhook_id~, token="tok", message_id~),
      ),
      route_metadata(
        "delete-message",
        @http.Route::DeleteWebhookMessage(webhook_id~, token="tok", message_id~),
      ),
    ],
    content=(
      #|[
      #|  {
      #|    name: "create",
      #|    method_name: "Post",
      #|    path: "/channels/10/webhooks",
      #|    bucket: "POST:/channels/10/webhooks",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "channel",
      #|    method_name: "Get",
      #|    path: "/channels/10/webhooks",
      #|    bucket: "GET:/channels/10/webhooks",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "guild",
      #|    method_name: "Get",
      #|    path: "/guilds/20/webhooks",
      #|    bucket: "GET:/guilds/20/webhooks",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "get",
      #|    method_name: "Get",
      #|    path: "/webhooks/30",
      #|    bucket: "GET:/webhooks/30",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "modify",
      #|    method_name: "Patch",
      #|    path: "/webhooks/30",
      #|    bucket: "PATCH:/webhooks/30",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "delete",
      #|    method_name: "Delete",
      #|    path: "/webhooks/30",
      #|    bucket: "DELETE:/webhooks/30",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "execute",
      #|    method_name: "Post",
      #|    path: "/webhooks/30/tok?wait=true",
      #|    bucket: "POST:/webhooks/30/tok",
      #|    needs_auth: false,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "get-message",
      #|    method_name: "Get",
      #|    path: "/webhooks/30/tok/messages/40",
      #|    bucket: "GET:/webhooks/30/tok/messages/{}",
      #|    needs_auth: false,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "edit-message",
      #|    method_name: "Patch",
      #|    path: "/webhooks/30/tok/messages/40",
      #|    bucket: "PATCH:/webhooks/30/tok/messages/{}",
      #|    needs_auth: false,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "delete-message",
      #|    method_name: "Delete",
      #|    path: "/webhooks/30/tok/messages/40",
      #|    bucket: "DELETE:/webhooks/30/tok/messages/{}",
      #|    needs_auth: false,
      #|    supports_reason: false,
      #|  },
      #|]
    ),
  )
}

///|
test "channel miscellaneous route metadata" {
  let channel_id : @model.ChannelId = @model.Id(10UL)
  let overwrite_id : @model.GenericId = @model.Id(50UL)
  debug_inspect(
    [
      route_metadata(
        "bulk-delete",
        @http.Route::BulkDeleteMessages(channel_id~),
      ),
      route_metadata("pins", @http.Route::GetPinnedMessages(channel_id~)),
      route_metadata(
        "edit-permissions",
        @http.Route::EditChannelPermissions(channel_id~, overwrite_id~),
      ),
      route_metadata(
        "delete-permission",
        @http.Route::DeleteChannelPermission(channel_id~, overwrite_id~),
      ),
      route_metadata("invites", @http.Route::GetChannelInvites(channel_id~)),
      route_metadata(
        "create-invite",
        @http.Route::CreateChannelInvite(channel_id~),
      ),
    ],
    content=(
      #|[
      #|  {
      #|    name: "bulk-delete",
      #|    method_name: "Post",
      #|    path: "/channels/10/messages/bulk-delete",
      #|    bucket: "POST:/channels/10/messages/bulk-delete",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "pins",
      #|    method_name: "Get",
      #|    path: "/channels/10/pins",
      #|    bucket: "GET:/channels/10/pins",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "edit-permissions",
      #|    method_name: "Put",
      #|    path: "/channels/10/permissions/50",
      #|    bucket: "PUT:/channels/10/permissions/{}",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "delete-permission",
      #|    method_name: "Delete",
      #|    path: "/channels/10/permissions/50",
      #|    bucket: "DELETE:/channels/10/permissions/{}",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "invites",
      #|    method_name: "Get",
      #|    path: "/channels/10/invites",
      #|    bucket: "GET:/channels/10/invites",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "create-invite",
      #|    method_name: "Post",
      #|    path: "/channels/10/invites",
      #|    bucket: "POST:/channels/10/invites",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|]
    ),
  )
}

///|
test "invite route metadata keeps the invite code" {
  debug_inspect(
    [
      route_metadata(
        "get",
        @http.Route::GetInvite(
          code="moonbit",
          query="?with_counts=true&with_expiration=true",
        ),
      ),
      route_metadata("delete", @http.Route::DeleteInvite(code="moonbit")),
    ],
    content=(
      #|[
      #|  {
      #|    name: "get",
      #|    method_name: "Get",
      #|    path: "/invites/moonbit?with_counts=true&with_expiration=true",
      #|    bucket: "GET:/invites/moonbit",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "delete",
      #|    method_name: "Delete",
      #|    path: "/invites/moonbit",
      #|    bucket: "DELETE:/invites/moonbit",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|]
    ),
  )
}

///|
test "guild emoji route metadata" {
  let guild_id : @model.GuildId = @model.Id(20UL)
  let emoji_id : @model.EmojiId = @model.Id(60UL)
  debug_inspect(
    [
      route_metadata("list", @http.Route::ListGuildEmojis(guild_id~)),
      route_metadata("get", @http.Route::GetGuildEmoji(guild_id~, emoji_id~)),
      route_metadata("create", @http.Route::CreateGuildEmoji(guild_id~)),
      route_metadata(
        "modify",
        @http.Route::ModifyGuildEmoji(guild_id~, emoji_id~),
      ),
      route_metadata(
        "delete",
        @http.Route::DeleteGuildEmoji(guild_id~, emoji_id~),
      ),
    ],
    content=(
      #|[
      #|  {
      #|    name: "list",
      #|    method_name: "Get",
      #|    path: "/guilds/20/emojis",
      #|    bucket: "GET:/guilds/20/emojis",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "get",
      #|    method_name: "Get",
      #|    path: "/guilds/20/emojis/60",
      #|    bucket: "GET:/guilds/20/emojis/{}",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "create",
      #|    method_name: "Post",
      #|    path: "/guilds/20/emojis",
      #|    bucket: "POST:/guilds/20/emojis",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "modify",
      #|    method_name: "Patch",
      #|    path: "/guilds/20/emojis/60",
      #|    bucket: "PATCH:/guilds/20/emojis/{}",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|  {
      #|    name: "delete",
      #|    method_name: "Delete",
      #|    path: "/guilds/20/emojis/60",
      #|    bucket: "DELETE:/guilds/20/emojis/{}",
      #|    needs_auth: true,
      #|    supports_reason: true,
      #|  },
      #|]
    ),
  )
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
