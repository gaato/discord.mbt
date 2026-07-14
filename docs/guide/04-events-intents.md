# Events and intents

The native `Bot` executor exposes typed Gateway event descriptors through
`Events`. Each descriptor fixes both the payload type and the delivery intents
associated with that event.

## Typed subscriptions

```moonbit
///|
bot.on(@discord.Events::ready(), (_, ready) => {
  println("ready as \{ready.user.username}")
})

///|
bot.on(@discord.Events::message_create(), (ctx, event) => {
  let message = event.message
  println("\{message.author.username}: \{message.content}")
  let client = ctx.app().http()
})

///|
bot.on(@discord.Events::guild_member_add(), (_, event) => {
  let member = event.guild_member
  println("member joined guild \{event.guild_id}: \{to_repr(member.user)}")
})
```

Some Gateway payloads contain fields in addition to the underlying REST
object. Their descriptors expose wrapper types such as `MessageCreateEvent`,
`ThreadCreateEvent`, and `GuildMemberAddEvent`; access the embedded object
through the wrapper field shown by `moon doc`.

## Automatic intent derivation

When `Bot::new` omits `intents`, `Bot` unions the delivery intents required by
all typed subscriptions, then removes privileged intents. For example,
`message_create()` contributes `GUILD_MESSAGES | DIRECT_MESSAGES`.

The privileged intents are:

- `GUILD_MEMBERS`
- `GUILD_PRESENCES`
- `MESSAGE_CONTENT`

Enable them in the developer portal and pass them explicitly:

```moonbit
///|
let intents = @model.Intents::guilds() |
  @model.Intents::guild_messages() |
  @model.Intents::direct_messages() |
  @model.Intents::guild_members() |
  @model.Intents::message_content()

///|
let bot = @discord.Bot::new(app, token~, intents~)
```

`MESSAGE_CONTENT` controls field visibility rather than event delivery, so it
is never inferred from `message_create()`. Pass it explicitly when handlers
need ordinary user-authored message content.

Raw handlers registered with `bot.on_event` also cannot imply an intent set.
If any raw handlers are used, pass the complete intended bitfield to
`Bot::new`.

## Decode errors

Known events that fail typed decoding are still delivered to raw handlers as
an `Event::Unknown` value whose marker starts with `DECODE_ERROR:`. The `App`
warning hook receives a summary without the payload.

Register a decode observer only when the raw payload is needed for diagnostics:

```moonbit
///|
app.on_warn(message => println("[warn] \{message}"))

///|
bot.on_decode_error((marker, payload) => {
  println("\{marker}: \{payload.stringify()}")
})
```

Decode observers run synchronously in the dispatch loop. Keep them short and
avoid logging payloads where message content or credentials could be exposed.
Registering one does not add intents.

## Sharding

`Bot` runs a single shard by default. For larger bots, select shards with the
`shards` option:

```moonbit
let bot = @discord.Bot::new(app, token~, shards=Auto)          // recommended count
let bot = @discord.Bot::new(app, token~, shards=Fixed(count=4)) // explicit local count
let bot = @discord.Bot::new(app, token~, shards=Range(ids=[0, 1], count=8))
```

Every shard feeds the same handlers, cache, and collectors. Identify calls are
serialized according to the `max_concurrency` rules Discord returns from
`GET /gateway/bot`, and startup fails early if the remaining session-start
allowance cannot cover the selected shards. For multiple processes, use the
bundled coordinator described in
[Scaling across processes](08-scaling-processes.md).
