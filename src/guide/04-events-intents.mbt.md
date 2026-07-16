# Events and intents

The native `Bot` executor exposes typed Gateway event descriptors through
`Events`. Each descriptor fixes both the payload type and the delivery intents
associated with that event.

## Typed subscriptions

```mbt check
///|
fn register_handlers(bot : @discord.Bot) -> Unit {
  bot.on(@discord.Events::ready(), (_, ready) => {
    println("ready as \{ready.user.username}")
  })
  bot.on(@discord.Events::message_create(), (ctx, event) => {
    let message = event.message
    println("\{message.author.username}: \{message.content}")
    let _client = ctx.app().http()
  })
  bot.on(@discord.Events::guild_member_add(), (_, event) => {
    let joined = event.guild_member
    println("member joined guild \{event.guild_id}: \{to_repr(joined.user)}")
  })
}
```

Some Gateway payloads contain fields in addition to the underlying REST
object. Their descriptors expose wrapper types such as `MessageCreateEvent`,
`ThreadCreateEvent`, and `GuildMemberAddEvent`; access the embedded object
through the wrapper field shown by `moon ide doc`.

## Automatic intent derivation

When `Bot(...)` omits `intents`, `Bot` unions the delivery intents required by
all typed subscriptions, then removes privileged intents. For example,
`message_create()` contributes `GUILD_MESSAGES | DIRECT_MESSAGES`.

The privileged intents are:

- `GUILD_MEMBERS`
- `GUILD_PRESENCES`
- `MESSAGE_CONTENT`

Enable them in the developer portal and pass them explicitly:

```mbt check
///|
let explicit_intents : @model.Intents = @model.Intents::guilds() |
  @model.Intents::guild_messages() |
  @model.Intents::direct_messages() |
  @model.Intents::guild_members() |
  @model.Intents::message_content()

///|
fn bot_with_explicit_intents(
  app : @discord.App,
  token : String,
) -> @discord.Bot {
  @discord.Bot(app, token~, intents=explicit_intents)
}

///|
test "privileged intents must be passed explicitly" {
  assert_true(explicit_intents.contains(@model.Intents::message_content()))
  assert_true(explicit_intents.contains(@model.Intents::guild_members()))
}
```

`MESSAGE_CONTENT` controls field visibility rather than event delivery, so it
is never inferred from `message_create()`. Pass it explicitly when handlers
need ordinary user-authored message content.

Raw handlers registered with `bot.on_event` also cannot imply an intent set.
If any raw handlers are used, pass the complete intended bitfield to
`Bot(...)`.

## Decode errors

Known events that fail typed decoding are still delivered to raw handlers as
an `Event::Unknown` value whose marker starts with `DECODE_ERROR:`. The `App`
warning hook receives a summary without the payload.

Register a decode observer only when the raw payload is needed for diagnostics:

```mbt check
///|
fn observe_decode_errors(app : @discord.App, bot : @discord.Bot) -> Unit {
  app.on_warn(message => println("[warn] \{message}"))
  bot.on_decode_error((marker, payload) => {
    println("\{marker}: \{payload.stringify()}")
  })
}
```

Decode observers run synchronously in the dispatch loop. Keep them short and
avoid logging payloads where message content or credentials could be exposed.
Registering one does not add intents.

## Gateway event middleware

`Bot::middleware` can filter an event by omitting `next`, or transform the
event passed to typed and raw handlers:

```mbt check
///|
fn filter_and_tag(bot : @discord.Bot) -> Unit {
  bot.middleware((_, event, next) => {
    match event {
      @model.Event::MessageCreate(created) if created.message.author.bot
        is Some(true) => ()
      @model.Event::MessageCreate(created) => {
        let message = {
          ..created.message,
          content: "[gateway] \{created.message.content}",
        }
        next(@model.Event::MessageCreate({ ..created, message, }))
      }
      _ => next(event)
    }
  })
}
```

This chain wraps handler fan-out only. Cache updates, collectors, decode-error
observation, and interaction routing stay outside it. Middleware also cannot
add intents. See [Middleware](09-middleware.mbt.md) for the dispatch-loop
contract and registration order.

## Sharding

`Bot` runs a single shard by default. For larger bots, select shards with the
`shards` option:

```mbt check
///|
fn sharded_bots(app : @discord.App, token : String) -> Array[@discord.Bot] {
  let auto = @discord.Bot(app, token~, shards=Auto) // recommended count
  let fixed = @discord.Bot(app, token~, shards=Fixed(count=4)) // explicit local count
  let ranged = @discord.Bot(app, token~, shards=Range(ids=[0, 1], count=8))
  [auto, fixed, ranged]
}

///|
test "event and shard declarations compile" {
  ignore(register_handlers)
  ignore(bot_with_explicit_intents)
  ignore(observe_decode_errors)
  ignore(filter_and_tag)
  ignore(sharded_bots)
}
```

Every shard feeds the same handlers, cache, and collectors. Identify calls are
serialized according to the `max_concurrency` rules Discord returns from
`GET /gateway/bot`, and startup fails early if the remaining session-start
allowance cannot cover the selected shards. For multiple processes, use the
bundled coordinator described in
[Scaling across processes](08-scaling-processes.mbt.md).

## Gateway compression

Gateway `zlib-stream` transport compression is opt-in. Pass `compress=true`
to `Bot(...)` (or `Shard::start` at the lower level):

```mbt check
///|
fn compressed_bot(app : @discord.App, token : String) -> @discord.Bot {
  @discord.Bot(app, token~, compress=true)
}
```

Each Gateway connection then requests `compress=zlib-stream` and retains one
inflate context for that connection, including across consecutive Gateway
messages. Only server-to-client binary messages are decompressed; identify,
heartbeat, and other client-to-server payloads remain uncompressed text.

The zlib shared library is loaded at runtime (like the async runtime loads
OpenSSL), so neither this library nor applications using it need extra link
flags; building only requires the zlib header. If the shared library is
missing at runtime, enabling compression raises before any connection is
attempted. A successful compressed connection emits `ShardCompressionEnabled`
telemetry.

## Opt-in cache

`gaato/discord/cache` is a portable, gateway-driven in-memory cache. Attach
it to a `Bot` to apply every decoded event before event handlers run:

```mbt check
///|
fn install_cache(bot : @discord.Bot) -> @cache.InMemoryCache {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(presences=true),
    max_messages_per_channel=100,
  )
  bot.attach_cache(cache)
  cache
}

///|
fn can_send_in(
  cache : @cache.InMemoryCache,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
  user_id : @model.UserId,
) -> Bool {
  match cache.permissions_in(guild_id, channel_id, user_id) {
    Some(permissions) =>
      permissions.contains(@model.Permissions::send_messages())
    None => false
  }
}

///|
test "compression and cache declarations compile" {
  ignore(compressed_bot)
  ignore(install_cache)
  ignore(can_send_in)
}
```

Guilds, channels, roles, members, users, and voice states are cached by
default. Presences and messages are opt-in because of their volume; enable
only the resources the application reads. The cache only sees events allowed
by the bot's configured intents. Entity getters return shared read-only model
values, while list getters return fresh outer arrays.
