# REST client

`gaato/discord/http.Client` can be used without the Gateway or interaction
framework. It provides typed endpoint methods, connection pooling, rate-limit
coordination, multipart uploads, and a raw route escape hatch.

## Typed requests

```mbt check
///|
async fn send_message(
  client : @dhttp.Client,
  channel_id : @model.ChannelId,
) -> @model.Message {
  client.create_message(channel_id, content="hello")
}
```

Create a client with a raw bot token:

```mbt check
///|
fn make_client(token : String) -> @dhttp.Client {
  Client(token, max_connections=4)
}
```

Call `client.close()` when the client is no longer needed. HTTP methods raise
`DiscordHttpError`: validation failures are raised before I/O, Discord error
responses use `Api`, and transport, deserialization, and rate-limit failures
have separate variants.

## Handles

Client-bound handles organize resource APIs into two levels. A parent ref uses
collection verbs such as `roles`, `members`, or `create_role`; a child ref
binds the returned resource id and uses individual verbs such as `fetch`,
`edit`, or `delete`. Handles do not cache values or defer requests: each verb
delegates immediately to the corresponding typed `Client` method.

```mbt check
///|
async fn rename_guild_role(
  client : @dhttp.Client,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
) -> @model.Role {
  let guild = client.guild_ref(guild_id)
  let current_roles = guild.roles()
  ignore(current_roles)
  guild.role_ref(role_id).edit(name="moderator", reason="role cleanup")
}

///|
async fn fetch_member(
  client : @dhttp.Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.GuildMember {
  client.guild_ref(guild_id).member_ref(user_id).fetch()
}
```

`fetch()` is the uniform name for retrieving the individual resource bound by
a ref. Stateful `Paginator` values are returned by
`ChannelRef::messages`, `GuildRef::members`, `GuildRef::bans`,
`GuildRef::audit_log`, `ScheduledEventRef::users`, and
`MessageRef::poll_answer_voters`; their cursors advance through `next_page`,
`collect`, or `each` just like the direct paginator constructors.

```mbt check
///|
fn channel_history(
  client : @dhttp.Client,
  channel_id : @model.ChannelId,
) -> @dhttp.Paginator[@model.Message] raise @dhttp.DiscordHttpError {
  client.channel_ref(channel_id).messages(page_size=100)
}

///|
test "handle declarations compile" {
  ignore(rename_guild_role)
  ignore(fetch_member)
  ignore(channel_history)
}
```

### Typing during long operations

`ChannelRef::with_typing` sends a typing request immediately, refreshes it
every eight seconds while the body runs, then stops when the body returns or
raises. The initial typing failure is propagated; a later refresh failure only
stops the keepalive loop.

```mbt check
///|
async fn produce_slow_answer(prompt : String) -> String {
  @async.sleep(1)
  "answer to: \{prompt}"
}

///|
async fn send_slow_answer(
  channel : @dhttp.ChannelRef,
  prompt : String,
) -> @model.Message {
  let answer = channel.with_typing(() => produce_slow_answer(prompt))
  channel.send(content=answer)
}

///|
test "typing keepalive declaration compiles" {
  ignore(send_slow_answer)
}
```

Discord expires a typing indicator after about ten seconds, which is why the
keepalive interval is eight seconds. Structured concurrency ensures the
background refresh task does not survive the wrapped operation.

Endpoints that support audit-log reasons expose `reason?`; the handle forwards
it as the request's URL-encoded `X-Audit-Log-Reason` header. Webhook
authentication is encoded in the handle type: `WebhookRef` performs bot-token
management, while `WebhookTokenRef` is created with `with_token` and executes
through the webhook URL token without bot authentication. Add the URL token
before executing, then bind the returned message for later edits:

```mbt check
///|
async fn send_and_edit_webhook(
  client : @dhttp.Client,
  webhook_id : @model.WebhookId,
  token : String,
) -> @model.Message {
  let webhook = client.webhook_ref(webhook_id).with_token(token)
  let sent = webhook.send(content="hello")
  webhook.message_ref(sent.id).edit(content="hello again")
}

///|
test "webhook handle declarations compile" {
  ignore(send_and_edit_webhook)
}
```

Every REST endpoint with a resource anchor is available from the
corresponding ref verb. The entry points:

| Ref | Entry points | Representative verbs |
|---|---|---|
| `ChannelRef` | `Client::channel_ref`, `GatewayCtx::channel_ref` | `fetch`, `send`, `messages`, `edit`, `start_thread` |
| `MessageRef` | `Client::message_ref`, `Client::ref_of_message`, `ChannelRef::message_ref`, `GatewayCtx::message_ref` | `fetch`, `reply`, `edit`, `react`, `poll_answer_voters` |
| `MemberRef` | `Client::member_ref`, `GuildRef::member_ref`, `GatewayCtx::member_ref` | `fetch`, `edit`, `ban`, `unban`, `edit_voice_state` |
| `UserRef` | `Client::user_ref`, `GatewayCtx::user_ref` | `fetch`, `dm` |
| `GuildRef` | `Client::guild_ref`, `GatewayCtx::guild_ref` | `fetch`, `edit`, `members`, `channels`, `search_messages` |
| `RoleRef` | `Client::role_ref`, `GuildRef::role_ref` | `fetch`, `edit`, `delete` |
| `EmojiRef` | `Client::emoji_ref`, `GuildRef::emoji_ref` | `fetch`, `edit`, `delete` |
| `StickerRef` | `Client::sticker_ref`, `GuildRef::sticker_ref` | `fetch`, `edit`, `delete` |
| `SoundboardSoundRef` | `Client::soundboard_sound_ref`, `GuildRef::soundboard_sound_ref` | `fetch`, `edit`, `delete` |
| `ScheduledEventRef` | `Client::scheduled_event_ref`, `GuildRef::scheduled_event_ref` | `fetch`, `edit`, `delete`, `users` |
| `AutoModerationRuleRef` | `Client::auto_moderation_rule_ref`, `GuildRef::auto_moderation_rule_ref` | `fetch`, `edit`, `delete` |
| `TemplateRef` | `Client::guild_template_ref`, `GuildRef::template_ref` | `fetch`, `sync`, `edit`, `create_guild` |
| `InviteRef` | `Client::invite_ref` | `fetch`, `delete`, `update_target_users` |
| `WebhookRef` | `Client::webhook_ref` | `fetch`, `edit`, `delete`, `with_token` |
| `WebhookTokenRef` | `Client::webhook_token_ref`, `WebhookRef::with_token` | `fetch`, `edit`, `send`, `message_ref` |
| `WebhookMessageRef` | `WebhookTokenRef::message_ref` | `fetch`, `edit`, `delete` |
| `ApplicationRef` | `Client::application_ref`, `AppCtx::application_ref` | `emojis`, `global_commands`, `entitlements`, `skus` |
| `ApplicationEmojiRef` | `Client::application_emoji_ref`, `ApplicationRef::emoji_ref` | `fetch`, `edit`, `delete` |
| `GlobalCommandRef` | `Client::global_command_ref`, `ApplicationRef::global_command_ref` | `fetch`, `edit`, `delete` |
| `GuildCommandRef` | `Client::guild_command_ref`, `ApplicationRef::guild_command_ref` | `fetch`, `edit`, `permissions`, `edit_permissions` |
| `EntitlementRef` | `Client::entitlement_ref`, `ApplicationRef::entitlement_ref` | `fetch`, `consume`, `delete_test` |
| `SkuRef` | `Client::sku_ref`, `ApplicationRef::sku_ref` | `subscriptions`, `subscription` |

The following endpoints remain direct `Client` methods because they do not
have a stable resource-id anchor compatible with a ref:

| Client method | Why it remains direct |
|---|---|
| `get_current_user` | The authenticated bot user is selected by the `/users/@me` route. |
| `modify_current_user` | The authenticated bot user is selected by the `/users/@me` route. |
| `get_current_user_guilds` | The guild list belongs to the authenticated `/users/@me` identity. |
| `get_current_authorization_information` | It uses a user OAuth bearer token instead of the bot client's authentication model. |
| `get_current_user_connections` | It uses a user OAuth bearer token instead of the bot client's authentication model. |
| `get_current_user_guild_member` | It uses a user OAuth bearer token instead of the bot client's authentication model. |
| `get_current_user_application_role_connection` | It uses a user OAuth bearer token instead of the bot client's authentication model. |
| `update_current_user_application_role_connection` | It uses a user OAuth bearer token instead of the bot client's authentication model. |
| `delete_current_user_application_role_connection` | It uses a user OAuth bearer token instead of the bot client's authentication model. |
| `edit_current_application` | The bot application is selected by an `@me` route rather than an application id. |
| `get_current_bot_application_information` | The bot application is selected by an `@me` route rather than an application id. |
| `get_sticker` | This is a global catalog lookup without a guild or application anchor. |
| `get_sticker_pack` | This is a global catalog lookup without a guild or application anchor. |
| `list_sticker_packs` | This is a global catalog listing without a resource anchor. |
| `list_default_soundboard_sounds` | This is a global catalog listing without a guild anchor. |
| `list_voice_regions` | This is a global catalog listing without a guild anchor. |

## Allowed mentions

Ordinary `create_message` calls default to
`AllowedMentions::safe_default()`: user and role mentions are parsed, while
`@everyone` and `@here` are suppressed. Override the client default or one
request:

```mbt check
///|
async fn greet_without_pings(
  token : String,
  channel_id : @model.ChannelId,
  recipient_id : @model.UserId,
) -> Unit {
  let client = @dhttp.Client(
    token,
    default_allowed_mentions=@model.AllowedMentions::none(),
  )
  let mentions = @model.AllowedMentions(
    users=[recipient_id],
    replied_user=false,
  )
  client.create_message(
    channel_id,
    content="Hello <@\{recipient_id}>",
    allowed_mentions=mentions,
  )
  |> ignore
}
```

`AllowedMentions(...)` rejects more than 100 role or user IDs and rejects a
category supplied in both `parse` and its explicit ID list. Interaction,
followup, and webhook methods omit `allowed_mentions` when it is not supplied,
preserving Discord's endpoint default.

## File uploads

The client sends attachments as `multipart/form-data`. Pass `files` to any
message-shaped call — `create_message`, interaction responses and followups,
and webhook sends:

```mbt check
///|
async fn send_report(
  client : @dhttp.Client,
  channel_id : @model.ChannelId,
) -> @model.Message {
  let report = @fs.read_file("report.png").binary()
  client.create_message(channel_id, content="Here you go", files=[
    FileUpload("report.png", report, content_type="image/png"),
  ])
}

///|
test "file upload declaration compiles" {
  ignore(send_report)
}
```

## Pagination

Paginator constructors validate cursor combinations and page sizes before the
first request:

```mbt check
///|
async fn walk_history(
  client : @dhttp.Client,
  channel_id : @model.ChannelId,
  guild_id : @model.GuildId,
) -> Unit {
  let history = client.paginate_messages(channel_id, page_size=100)
  let newest_250 = history.collect(max=250)
  ignore(newest_250)
  let members = client.paginate_guild_members(guild_id, page_size=1000)
  members.each(guild_member => println("\{Repr(guild_member.user)}"))
}
```

`next_page()` returns `Array[T]?`, where `None` is the terminal state.
`next_page`, `collect`, and `each` consume the same paginator state and must be
called sequentially. See the `Client::paginate_messages` documentation for
cursor direction details.

## Custom routes

Use `Route::custom` for an endpoint that does not yet have a typed wrapper:

```mbt check
///|
test "custom routes derive stable metadata" {
  let route = @dhttp.Route::custom(
    request_method=Get,
    path="/guilds/123/widgets/456",
    bucket="GET:/guilds/123/widgets/{}",
  )
  inspect(route.bucket(), content="GET:/guilds/123/widgets/{}")
}

///|
async fn fetch_widget(client : @dhttp.Client, route : @dhttp.Route) -> Json {
  client.request(route)
}

///|
test "rest declarations compile" {
  ignore(send_message)
  ignore(make_client)
  ignore(greet_without_pings)
  ignore(walk_history)
  ignore(fetch_widget)
}
```

The path must begin with `/`. Omit `bucket` to derive an isolated key from the
method and concrete path. Supply a bucket template when minor resource IDs
should share rate-limit state. Set `is_interaction=true` only for endpoints
that Discord exempts from the global rate limit and authenticates through an
interaction or webhook token; this also omits bot-token authentication. Set
`supports_reason=true` only when the endpoint accepts `X-Audit-Log-Reason`.

## Rate-limit behavior

The default `InMemoryRateLimiter` coordinates route buckets and Discord's
global window inside one process. The client updates bucket state from response
headers and retries 429 responses after the declared delay. Typed and custom
routes use the same request path, so no separate limiter integration is
required. A custom limiter can be passed through `Client(limiter=...)`.

`Client(request_timeout_ms=30000)` bounds each single network attempt,
including reading its response body. Rate-limit waits, 429 back-off, and user
HTTP middleware are not bounded by it. Command sync can legitimately wait
about a minute for the bulk-overwrite-commands bucket. A timed-out attempt
raises `DiscordHttpError::Timeout` and is not retried: Discord may already
have received it, so retrying a non-idempotent POST could duplicate it.

For a whole-operation deadline, compose `@async.with_timeout` around the
call. This also bounds middleware and rate-limit waiting. The example uses a
synthetic response to demonstrate both deadlines without contacting Discord:

```mbt check
///|
async test "an overall REST deadline includes middleware" {
  let client = @dhttp.Client("test-token", request_timeout_ms=10)
  defer client.close()
  let cancelled = Ref(false)
  client.middleware((_, _) => {
    defer {
      cancelled.val = @async.is_being_cancelled()
    }
    @async.sleep(60)
    { status: 200, headers: Map([]), body: { "ok": true }, }
  })
  let response = @async.with_timeout(1000, () => client.request(GetGateway))
  json_inspect(response, content={ "ok": true })
  assert_false(cancelled.val)
  try @async.with_timeout(10, () => client.request(GetGateway)) catch {
    @async.TimeoutError => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the overall deadline to cancel slow middleware")
  }
  assert_true(cancelled.val)
}
```

## Request middleware

`Client::middleware` wraps each logical REST call, outside the per-attempt
timeout. The rate limiter, wire exchange, and bounded 429 retries all run
inside `next`:

```mbt check
///|
fn wire_logging(client : @dhttp.Client) -> Unit {
  client.middleware((request, next) => {
    let req_method = Repr(request.route.method_())
    let path = request.route.path()
    println("http -> \{req_method} \{path}")
    let response = next(request)
    println("http <- \{req_method} \{path} \{response.status}")
    response
  })
}

///|
test "request middleware compiles" {
  ignore(wire_logging)
}
```

Middleware sees the final wire response before status-code-to-error mapping.
See [Middleware](09-middleware.mbt.md) for header injection, short-circuiting,
and retry visibility.
