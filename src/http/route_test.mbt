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
    method_name: @debug.to_string(route.method_()),
    path: route.path(),
    bucket: route.bucket(),
    needs_auth: route.needs_auth(),
    supports_reason: route.supports_reason(),
  }
}

///|
fn route_signature(route : @http.Route) -> String {
  "\{@debug.to_string(route.method_())} \{route.path()} | \{route.bucket()} | reason=\{route.supports_reason()}"
}

///|
test "edit current application REST route metadata" {
  let route = @http.Route::EditCurrentApplication
  inspect(
    route_signature(route),
    content=(
      #|Patch /applications/@me | PATCH:/applications/@me | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get application role connection metadata records REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let route = @http.Route::GetApplicationRoleConnectionMetadataRecords(
    application_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Get /applications/10/role-connections/metadata | GET:/applications/10/role-connections/metadata | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "update application role connection metadata records REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let route = @http.Route::UpdateApplicationRoleConnectionMetadataRecords(
    application_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Put /applications/10/role-connections/metadata | PUT:/applications/10/role-connections/metadata | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get current user application role connection REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let route = @http.Route::GetCurrentUserApplicationRoleConnection(
    application_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Get /users/@me/applications/10/role-connection | GET:/users/@me/applications/10/role-connection | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "update current user application role connection REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let route = @http.Route::UpdateCurrentUserApplicationRoleConnection(
    application_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Put /users/@me/applications/10/role-connection | PUT:/users/@me/applications/10/role-connection | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "delete current user application role connection REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let route = @http.Route::DeleteCurrentUserApplicationRoleConnection(
    application_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Delete /users/@me/applications/10/role-connection | DELETE:/users/@me/applications/10/role-connection | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get guild application command permissions REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let guild_id : @model.GuildId = Id(20UL)
  let route = @http.Route::GetGuildApplicationCommandPermissions(
    application_id~,
    guild_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Get /applications/10/guilds/20/commands/permissions | GET:/applications/10/guilds/20/commands/permissions | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get application command permissions REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let guild_id : @model.GuildId = Id(20UL)
  let command_id : @model.CommandId = Id(30UL)
  let route = @http.Route::GetApplicationCommandPermissions(
    application_id~,
    guild_id~,
    command_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Get /applications/10/guilds/20/commands/30/permissions | GET:/applications/10/guilds/20/commands/{}/permissions | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "edit application command permissions REST route metadata" {
  let application_id : @model.ApplicationId = Id(10UL)
  let guild_id : @model.GuildId = Id(20UL)
  let command_id : @model.CommandId = Id(30UL)
  let route = @http.Route::EditApplicationCommandPermissions(
    application_id~,
    guild_id~,
    command_id~,
  )
  inspect(
    route_signature(route),
    content=(
      #|Put /applications/10/guilds/20/commands/30/permissions | PUT:/applications/10/guilds/20/commands/{}/permissions | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "list voice regions REST route metadata" {
  let route = @http.Route::ListVoiceRegions
  inspect(
    route_signature(route),
    content=(
      #|Get /voice/regions | GET:/voice/regions | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get current user voice state REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let route = @http.Route::GetCurrentUserVoiceState(guild_id~)
  inspect(
    route_signature(route),
    content=(
      #|Get /guilds/10/voice-states/@me | GET:/guilds/10/voice-states/@me | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get user voice state REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let route = @http.Route::GetUserVoiceState(guild_id~, user_id~)
  inspect(
    route_signature(route),
    content=(
      #|Get /guilds/10/voice-states/20 | GET:/guilds/10/voice-states/{} | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "modify current user voice state REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let route = @http.Route::ModifyCurrentUserVoiceState(guild_id~)
  inspect(
    route_signature(route),
    content=(
      #|Patch /guilds/10/voice-states/@me | PATCH:/guilds/10/voice-states/@me | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "modify user voice state REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let route = @http.Route::ModifyUserVoiceState(guild_id~, user_id~)
  inspect(
    route_signature(route),
    content=(
      #|Patch /guilds/10/voice-states/20 | PATCH:/guilds/10/voice-states/{} | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "current user guild REST route metadata" {
  let route = @http.Route::GetCurrentUserGuilds(query="?limit=200&before=10")
  inspect(
    route_signature(route),
    content=(
      #|Get /users/@me/guilds?limit=200&before=10 | GET:/users/@me/guilds | reason=false
    ),
  )
}

///|
test "thread REST route metadata" {
  let channel_id : @model.ChannelId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let guild_id : @model.GuildId = Id(30UL)
  let routes : Array[@http.Route] = [
    ListThreadMembers(channel_id~, query="?with_member=true&after=20&limit=100"),
    GetThreadMember(channel_id~, user_id~, query="?with_member=false"),
    AddThreadMember(channel_id~, user_id~),
    RemoveThreadMember(channel_id~, user_id~),
    ListPublicArchivedThreads(
      channel_id~,
      query="?before=2024-01-02T03:04:05.000000+00:00&limit=50",
    ),
    ListPrivateArchivedThreads(channel_id~, query=""),
    ListJoinedPrivateArchivedThreads(channel_id~, query="?before=40&limit=25"),
    ListActiveGuildThreads(guild_id~),
  ]
  debug_inspect(
    routes.map(route_signature),
    content=(
      #|[
      #|  "Get /channels/10/thread-members?with_member=true&after=20&limit=100 | GET:/channels/10/thread-members | reason=false",
      #|  "Get /channels/10/thread-members/20?with_member=false | GET:/channels/10/thread-members/{} | reason=false",
      #|  "Put /channels/10/thread-members/20 | PUT:/channels/10/thread-members/{} | reason=false",
      #|  "Delete /channels/10/thread-members/20 | DELETE:/channels/10/thread-members/{} | reason=false",
      #|  "Get /channels/10/threads/archived/public?before=2024-01-02T03:04:05.000000+00:00&limit=50 | GET:/channels/10/threads/archived/public | reason=false",
      #|  "Get /channels/10/threads/archived/private | GET:/channels/10/threads/archived/private | reason=false",
      #|  "Get /channels/10/users/@me/threads/archived/private?before=40&limit=25 | GET:/channels/10/users/@me/threads/archived/private | reason=false",
      #|  "Get /guilds/30/threads/active | GET:/guilds/30/threads/active | reason=false",
      #|]
    ),
  )
  for route in routes {
    assert_true(route.needs_auth())
    assert_false(route.is_interaction())
    assert_false(route.supports_reason())
  }
}

///|
test "get current user connections REST route metadata" {
  let route = @http.Route::GetCurrentUserConnections
  inspect(
    route_signature(route),
    content=(
      #|Get /users/@me/connections | GET:/users/@me/connections | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get current user guild member REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let route = @http.Route::GetCurrentUserGuildMember(guild_id~)
  inspect(
    route_signature(route),
    content=(
      #|Get /users/@me/guilds/10/member | GET:/users/@me/guilds/10/member | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "leave guild REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let route = @http.Route::LeaveGuild(guild_id~)
  inspect(
    route_signature(route),
    content=(
      #|Delete /users/@me/guilds/10 | DELETE:/users/@me/guilds/10 | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get current authorization information REST route metadata" {
  let route = @http.Route::GetCurrentAuthorizationInformation
  inspect(
    route_signature(route),
    content=(
      #|Get /oauth2/@me | GET:/oauth2/@me | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "get current bot application information REST route metadata" {
  let route = @http.Route::GetCurrentBotApplicationInformation
  inspect(
    route_signature(route),
    content=(
      #|Get /oauth2/applications/@me | GET:/oauth2/applications/@me | reason=false
    ),
  )
  assert_true(route.needs_auth())
  assert_false(route.is_interaction())
}

///|
test "automod and sticker REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let rule_id : @model.AutoModerationRuleId = Id(40UL)
  let sticker_id : @model.StickerId = Id(50UL)
  let pack_id : @model.StickerPackId = Id(80UL)
  debug_inspect(
    [
      route_signature(ListAutoModerationRules(guild_id~)),
      route_signature(GetAutoModerationRule(guild_id~, rule_id~)),
      route_signature(CreateAutoModerationRule(guild_id~)),
      route_signature(ModifyAutoModerationRule(guild_id~, rule_id~)),
      route_signature(DeleteAutoModerationRule(guild_id~, rule_id~)),
      route_signature(GetSticker(sticker_id~)),
      route_signature(ListStickerPacks),
      route_signature(GetStickerPack(pack_id~)),
      route_signature(ListGuildStickers(guild_id~)),
      route_signature(GetGuildSticker(guild_id~, sticker_id~)),
      route_signature(CreateGuildSticker(guild_id~)),
      route_signature(ModifyGuildSticker(guild_id~, sticker_id~)),
      route_signature(DeleteGuildSticker(guild_id~, sticker_id~)),
    ],
    content=(
      #|[
      #|  "Get /guilds/10/auto-moderation/rules | GET:/guilds/10/auto-moderation/rules | reason=false",
      #|  "Get /guilds/10/auto-moderation/rules/40 | GET:/guilds/10/auto-moderation/rules/{} | reason=false",
      #|  "Post /guilds/10/auto-moderation/rules | POST:/guilds/10/auto-moderation/rules | reason=true",
      #|  "Patch /guilds/10/auto-moderation/rules/40 | PATCH:/guilds/10/auto-moderation/rules/{} | reason=true",
      #|  "Delete /guilds/10/auto-moderation/rules/40 | DELETE:/guilds/10/auto-moderation/rules/{} | reason=true",
      #|  "Get /stickers/50 | GET:/stickers/{} | reason=false",
      #|  "Get /sticker-packs | GET:/sticker-packs | reason=false",
      #|  "Get /sticker-packs/80 | GET:/sticker-packs/{} | reason=false",
      #|  "Get /guilds/10/stickers | GET:/guilds/10/stickers | reason=false",
      #|  "Get /guilds/10/stickers/50 | GET:/guilds/10/stickers/{} | reason=false",
      #|  "Post /guilds/10/stickers | POST:/guilds/10/stickers | reason=true",
      #|  "Patch /guilds/10/stickers/50 | PATCH:/guilds/10/stickers/{} | reason=true",
      #|  "Delete /guilds/10/stickers/50 | DELETE:/guilds/10/stickers/{} | reason=true",
      #|]
    ),
  )
}

///|
test "scheduled event and stage REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let channel_id : @model.ChannelId = Id(20UL)
  let event_id : @model.ScheduledEventId = Id(60UL)
  debug_inspect(
    [
      route_signature(
        ListGuildScheduledEvents(guild_id~, query="?with_user_count=true"),
      ),
      route_signature(CreateGuildScheduledEvent(guild_id~)),
      route_signature(
        GetGuildScheduledEvent(
          guild_id~,
          event_id~,
          query="?with_user_count=true",
        ),
      ),
      route_signature(ModifyGuildScheduledEvent(guild_id~, event_id~)),
      route_signature(DeleteGuildScheduledEvent(guild_id~, event_id~)),
      route_signature(
        ListGuildScheduledEventUsers(guild_id~, event_id~, query="?limit=25"),
      ),
      route_signature(CreateStageInstance),
      route_signature(GetStageInstance(channel_id~)),
      route_signature(ModifyStageInstance(channel_id~)),
      route_signature(DeleteStageInstance(channel_id~)),
    ],
    content=(
      #|[
      #|  "Get /guilds/10/scheduled-events?with_user_count=true | GET:/guilds/10/scheduled-events | reason=false",
      #|  "Post /guilds/10/scheduled-events | POST:/guilds/10/scheduled-events | reason=true",
      #|  "Get /guilds/10/scheduled-events/60?with_user_count=true | GET:/guilds/10/scheduled-events/{} | reason=false",
      #|  "Patch /guilds/10/scheduled-events/60 | PATCH:/guilds/10/scheduled-events/{} | reason=true",
      #|  "Delete /guilds/10/scheduled-events/60 | DELETE:/guilds/10/scheduled-events/{} | reason=true",
      #|  "Get /guilds/10/scheduled-events/60/users?limit=25 | GET:/guilds/10/scheduled-events/{}/users | reason=false",
      #|  "Post /stage-instances | POST:/stage-instances | reason=true",
      #|  "Get /stage-instances/20 | GET:/stage-instances/20 | reason=false",
      #|  "Patch /stage-instances/20 | PATCH:/stage-instances/20 | reason=true",
      #|  "Delete /stage-instances/20 | DELETE:/stage-instances/20 | reason=true",
      #|]
    ),
  )
}

///|
test "poll and soundboard REST route metadata" {
  let guild_id : @model.GuildId = Id(10UL)
  let channel_id : @model.ChannelId = Id(20UL)
  let message_id : @model.MessageId = Id(30UL)
  let sound_id : @model.SoundboardSoundId = Id(70UL)
  debug_inspect(
    [
      route_signature(
        GetPollAnswerVoters(
          channel_id~,
          message_id~,
          answer_id=2,
          query="?limit=25",
        ),
      ),
      route_signature(ExpirePoll(channel_id~, message_id~)),
      route_signature(SendSoundboardSound(channel_id~)),
      route_signature(ListDefaultSoundboardSounds),
      route_signature(ListGuildSoundboardSounds(guild_id~)),
      route_signature(CreateGuildSoundboardSound(guild_id~)),
      route_signature(GetGuildSoundboardSound(guild_id~, sound_id~)),
      route_signature(ModifyGuildSoundboardSound(guild_id~, sound_id~)),
      route_signature(DeleteGuildSoundboardSound(guild_id~, sound_id~)),
    ],
    content=(
      #|[
      #|  "Get /channels/20/polls/30/answers/2?limit=25 | GET:/channels/20/polls/{}/answers/{} | reason=false",
      #|  "Post /channels/20/polls/30/expire | POST:/channels/20/polls/{}/expire | reason=false",
      #|  "Post /channels/20/send-soundboard-sound | POST:/channels/20/send-soundboard-sound | reason=false",
      #|  "Get /soundboard-default-sounds | GET:/soundboard-default-sounds | reason=false",
      #|  "Get /guilds/10/soundboard-sounds | GET:/guilds/10/soundboard-sounds | reason=false",
      #|  "Post /guilds/10/soundboard-sounds | POST:/guilds/10/soundboard-sounds | reason=true",
      #|  "Get /guilds/10/soundboard-sounds/70 | GET:/guilds/10/soundboard-sounds/{} | reason=false",
      #|  "Patch /guilds/10/soundboard-sounds/70 | PATCH:/guilds/10/soundboard-sounds/{} | reason=true",
      #|  "Delete /guilds/10/soundboard-sounds/70 | DELETE:/guilds/10/soundboard-sounds/{} | reason=true",
      #|]
    ),
  )
}

///|
test "new route buckets preserve majors and squash minor resources" {
  let guild_a : @model.GuildId = Id(10UL)
  let guild_b : @model.GuildId = Id(11UL)
  let rule_a : @model.AutoModerationRuleId = Id(40UL)
  let rule_b : @model.AutoModerationRuleId = Id(41UL)
  let first = @http.Route::ModifyAutoModerationRule(
    guild_id=guild_a,
    rule_id=rule_a,
  )
  let same_major = @http.Route::ModifyAutoModerationRule(
    guild_id=guild_a,
    rule_id=rule_b,
  )
  let other_major = @http.Route::ModifyAutoModerationRule(
    guild_id=guild_b,
    rule_id=rule_a,
  )
  assert_true(first.bucket() == same_major.bucket())
  assert_false(first.bucket() == other_major.bucket())
  assert_false(
    first.bucket() == @http.Route::ModifyGuild(guild_id=guild_a).bucket(),
  )
}

///|
test "route paths and buckets" {
  let channel_id : @model.ChannelId = Id(100UL)
  let message_id : @model.MessageId = Id(200UL)
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
test "custom route derives a stable query-free bucket" {
  let route = @http.Route::custom(
    request_method=Get,
    path="/guilds/100/auto-moderation/rules?limit=25",
  )
  inspect(@debug.to_string(route.method_()), content="Get")
  inspect(route.path(), content="/guilds/100/auto-moderation/rules?limit=25")
  inspect(
    route.bucket(),
    content="CUSTOM:GET:/guilds/100/auto-moderation/rules",
  )
  let other_query = @http.Route::custom(
    request_method=Get,
    path="/guilds/100/auto-moderation/rules?limit=100&before=200",
  )
  assert_true(route.bucket() == other_query.bucket())
  assert_false(route.is_interaction())
  assert_true(route.needs_auth())
  assert_false(route.supports_reason())
}

///|
test "custom route accepts explicit bucket and interaction metadata" {
  let first = @http.Route::custom(
    request_method=Patch,
    path="/guilds/100/auto-moderation/rules/200",
    bucket="PATCH:/guilds/100/auto-moderation/rules/{}",
    supports_reason=true,
  )
  let second = @http.Route::custom(
    request_method=Patch,
    path="/guilds/100/auto-moderation/rules/201",
    bucket="PATCH:/guilds/100/auto-moderation/rules/{}",
    supports_reason=true,
  )
  inspect(first.bucket(), content="PATCH:/guilds/100/auto-moderation/rules/{}")
  assert_true(first.bucket() == second.bucket())
  assert_true(first.supports_reason())
  let interaction = @http.Route::custom(
    request_method=Post,
    path="/interactions/1/token/callback",
    is_interaction=true,
  )
  assert_true(interaction.is_interaction())
  assert_false(interaction.needs_auth())
}

///|
test "default custom buckets do not collide with typed routes" {
  let channel_id : @model.ChannelId = Id(100UL)
  let typed = @http.Route::CreateMessage(channel_id~)
  let custom = @http.Route::custom(
    request_method=Post,
    path="/channels/100/messages",
  )
  inspect(typed.bucket(), content="POST:/channels/100/messages")
  inspect(custom.bucket(), content="CUSTOM:POST:/channels/100/messages")
  assert_false(typed.bucket() == custom.bucket())
  let explicitly_shared = @http.Route::custom(
    request_method=Post,
    path="/channels/100/messages",
    bucket=typed.bucket(),
  )
  assert_true(explicitly_shared.bucket() == typed.bucket())
}

///|
test "custom route rejects invalid paths and empty buckets" {
  try
    @http.Route::custom(request_method=Get, path="guilds/100/stickers")
  catch {
    InvalidPath(path~) => inspect(path, content="guilds/100/stickers")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected invalid path")
  }
  try
    @http.Route::custom(
      request_method=Get,
      path="/guilds/100/stickers",
      bucket="",
    )
  catch {
    EmptyBucket => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected empty bucket")
  }
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
  let channel_id : @model.ChannelId = Id(10UL)
  let guild_id : @model.GuildId = Id(20UL)
  let webhook_id : @model.WebhookId = Id(30UL)
  let message_id : @model.MessageId = Id(40UL)
  debug_inspect(
    [
      route_metadata("create", CreateWebhook(channel_id~)),
      route_metadata("channel", GetChannelWebhooks(channel_id~)),
      route_metadata("guild", GetGuildWebhooks(guild_id~)),
      route_metadata("get", GetWebhook(webhook_id~)),
      route_metadata("modify", ModifyWebhook(webhook_id~)),
      route_metadata("delete", DeleteWebhook(webhook_id~)),
      route_metadata(
        "execute",
        ExecuteWebhook(webhook_id~, token="tok", query="?wait=true"),
      ),
      route_metadata(
        "get-message",
        GetWebhookMessage(webhook_id~, token="tok", message_id~),
      ),
      route_metadata(
        "edit-message",
        EditWebhookMessage(webhook_id~, token="tok", message_id~),
      ),
      route_metadata(
        "delete-message",
        DeleteWebhookMessage(webhook_id~, token="tok", message_id~),
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
  let channel_id : @model.ChannelId = Id(10UL)
  let overwrite_id : @model.GenericId = Id(50UL)
  debug_inspect(
    [
      route_metadata("bulk-delete", BulkDeleteMessages(channel_id~)),
      route_metadata("pins", GetPinnedMessages(channel_id~)),
      route_metadata(
        "edit-permissions",
        EditChannelPermissions(channel_id~, overwrite_id~),
      ),
      route_metadata(
        "delete-permission",
        DeleteChannelPermission(channel_id~, overwrite_id~),
      ),
      route_metadata("invites", GetChannelInvites(channel_id~)),
      route_metadata("create-invite", CreateChannelInvite(channel_id~)),
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
        GetInvite(
          code="moonbit",
          query="?with_counts=true&with_expiration=true",
        ),
      ),
      route_metadata("delete", DeleteInvite(code="moonbit")),
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
  let guild_id : @model.GuildId = Id(20UL)
  let emoji_id : @model.EmojiId = Id(60UL)
  debug_inspect(
    [
      route_metadata("list", ListGuildEmojis(guild_id~)),
      route_metadata("get", GetGuildEmoji(guild_id~, emoji_id~)),
      route_metadata("create", CreateGuildEmoji(guild_id~)),
      route_metadata("modify", ModifyGuildEmoji(guild_id~, emoji_id~)),
      route_metadata("delete", DeleteGuildEmoji(guild_id~, emoji_id~)),
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
test "application emoji route metadata" {
  let application_id : @model.ApplicationId = Id(20UL)
  let emoji_id : @model.EmojiId = Id(60UL)
  let routes = [
    @http.Route::ListApplicationEmojis(application_id~),
    GetApplicationEmoji(application_id~, emoji_id~),
    CreateApplicationEmoji(application_id~),
    ModifyApplicationEmoji(application_id~, emoji_id~),
    DeleteApplicationEmoji(application_id~, emoji_id~),
  ]
  debug_inspect(
    [
      route_metadata("list", routes[0]),
      route_metadata("get", routes[1]),
      route_metadata("create", routes[2]),
      route_metadata("modify", routes[3]),
      route_metadata("delete", routes[4]),
    ],
    content=(
      #|[
      #|  {
      #|    name: "list",
      #|    method_name: "Get",
      #|    path: "/applications/20/emojis",
      #|    bucket: "GET:/applications/20/emojis",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "get",
      #|    method_name: "Get",
      #|    path: "/applications/20/emojis/60",
      #|    bucket: "GET:/applications/20/emojis/{}",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "create",
      #|    method_name: "Post",
      #|    path: "/applications/20/emojis",
      #|    bucket: "POST:/applications/20/emojis",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "modify",
      #|    method_name: "Patch",
      #|    path: "/applications/20/emojis/60",
      #|    bucket: "PATCH:/applications/20/emojis/{}",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|  {
      #|    name: "delete",
      #|    method_name: "Delete",
      #|    path: "/applications/20/emojis/60",
      #|    bucket: "DELETE:/applications/20/emojis/{}",
      #|    needs_auth: true,
      #|    supports_reason: false,
      #|  },
      #|]
    ),
  )
  for route in routes {
    assert_false(route.is_interaction())
  }
}

///|
test "interaction routes are global-exempt and unauthenticated" {
  let interaction_id : @model.InteractionId = Id(1UL)
  let callback = @http.Route::CreateInteractionResponse(
    interaction_id~,
    token="tok",
  )
  assert_true(callback.is_interaction())
  assert_false(callback.needs_auth())
  inspect(callback.path(), content="/interactions/1/tok/callback")
  let msg = @http.Route::CreateMessage(channel_id=Id(2UL))
  assert_false(msg.is_interaction())
  assert_true(msg.needs_auth())
}

///|
test "reaction buckets squash message emoji and user ids" {
  let channel_id : @model.ChannelId = Id(10UL)
  let first_message : @model.MessageId = Id(20UL)
  let second_message : @model.MessageId = Id(21UL)
  let first_user : @model.UserId = Id(30UL)
  let second_user : @model.UserId = Id(31UL)
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
  let application_id : @model.ApplicationId = Id(100UL)
  let message_id : @model.MessageId = Id(200UL)
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
  let guild_id : @model.GuildId = Id(500UL)
  let first_role : @model.RoleId = Id(600UL)
  let second_role : @model.RoleId = Id(601UL)
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
  let user_id : @model.UserId = Id(700UL)
  let member_role = @http.Route::AddGuildMemberRole(
    guild_id~,
    user_id~,
    role_id=first_role,
  )
  assert_true(member_role.supports_reason())
}
