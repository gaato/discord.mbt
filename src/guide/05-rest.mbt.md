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
  @dhttp.Client(token, max_connections=4)
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

Endpoints that support audit-log reasons expose `reason?`; the handle forwards
it as the request's URL-encoded `X-Audit-Log-Reason` header. Webhook
authentication is encoded in the handle type: `WebhookRef` performs bot-token
management, while `WebhookTokenRef` is created with `with_token` and executes
through the webhook URL token without bot authentication.

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
  members.each(guild_member => println("\{to_repr(guild_member.user)}"))
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
    request_method=@dhttp.RequestMethod::Get,
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

## Request middleware

`Client::middleware` wraps each logical REST call. The rate limiter, wire
exchange, and bounded 429 retries all run inside `next`:

```mbt check
///|
fn wire_logging(client : @dhttp.Client) -> Unit {
  client.middleware((request, next) => {
    let req_method = to_repr(request.route.method_())
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
