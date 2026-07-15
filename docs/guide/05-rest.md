# REST client

`gaato/discord/http.Client` can be used without the Gateway or interaction
framework. It provides typed endpoint methods, connection pooling, rate-limit
coordination, multipart uploads, and a raw route escape hatch.

## Typed requests

```moonbit
///|
async fn send_message(
  client : @dhttp.Client,
  channel_id : @model.ChannelId,
) -> @model.Message {
  client.create_message(channel_id, content="hello")
}
```

Create a client with a raw bot token:

```moonbit
let client = @dhttp.Client(token, max_connections=4)
```

Call `client.close()` when the client is no longer needed. HTTP methods raise
`DiscordHttpError`: validation failures are raised before I/O, Discord error
responses use `Api`, and transport, deserialization, and rate-limit failures
have separate variants.

## Allowed mentions

Ordinary `create_message` calls default to
`AllowedMentions::safe_default()`: user and role mentions are parsed, while
`@everyone` and `@here` are suppressed. Override the client default or one
request:

```moonbit
///|
let client = @dhttp.Client(
  token,
  default_allowed_mentions=@model.AllowedMentions::none(),
)

///|
let mentions = @model.AllowedMentions(
  users=[recipient_id],
  replied_user=false,
)

///|
client.create_message(
  channel_id,
  content="Hello <@\{recipient_id}>",
  allowed_mentions=mentions,
)
|> ignore
```

`AllowedMentions(...)` rejects more than 100 role or user IDs and rejects a
category supplied in both `parse` and its explicit ID list. Interaction,
followup, and webhook methods omit `allowed_mentions` when it is not supplied,
preserving Discord's endpoint default.

## Pagination

Paginator constructors validate cursor combinations and page sizes before the
first request:

```moonbit
///|
let history = client.paginate_messages(channel_id, page_size=100)
let newest_250 = history.collect(max=250)

///|
let members = client.paginate_guild_members(guild_id, page_size=1000)
members.each(member => println("\{to_repr(member.user)}"))
```

`next_page()` returns `Array[T]?`, where `None` is the terminal state.
`next_page`, `collect`, and `each` consume the same paginator state and must be
called sequentially. See the [pagination cookbook](../cookbook/pagination.md)
for cursor direction details.

## Custom routes

Use `Route::custom` for an endpoint that does not yet have a typed wrapper:

```moonbit
///|
let route = @dhttp.Route::custom(
  request_method=@dhttp.RequestMethod::Get,
  path="/guilds/123/widgets/456",
  bucket="GET:/guilds/123/widgets/{}",
)

///|
let response : Json = client.request(route)
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

```moonbit
client.middleware((request, next) => {
  let method = request.route.method_().to_string()
  let path = request.route.path()
  println("http -> \{method} \{path}")
  let response = next(request)
  println("http <- \{method} \{path} \{response.status}")
  response
})
```

Middleware sees the final wire response before status-code-to-error mapping.
See [Middleware](09-middleware.md) for header injection, short-circuiting, and
retry visibility.
