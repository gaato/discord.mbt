# Models and utilities

`gaato/discord/model` is the pure data layer: ~24 entity domains and the
gateway payloads, with zero IO, usable on both native and JavaScript. Every
entity decodes from real API payloads. `gaato/discord/util` adds pure helpers
over those values — permissions, mentions, timestamps, and CDN URLs — and
depends only on `model`.

Code blocks marked `mbt check` in this chapter compile and run as part of the
test suite (`moon test --target native`).

## Decoding entities

Model types decode from JSON with `@json.from_json`:

```mbt check
///|
test "decode a user payload" {
  let user : @model.User = @json.from_json(
    @json.parse(
      (
        #|{"id": "80351110224678912", "username": "nelly",
        #| "discriminator": "0", "global_name": "Nelly", "avatar": null}
      ),
    ),
  )
  inspect(user.username, content="nelly")
  debug_inspect(user.id.value(), content="80351110224678912")
}
```

Unknown enum values and unknown JSON keys round-trip through `Unknown(...)`
variants instead of failing, so a new Discord feature does not break an
application built on an older model. Serializing the value back produces the
original wire form, unknown parts included.

## Typed snowflakes

IDs are phantom-typed: a `UserId` (`Id[UserMarker]`) cannot be passed where a
`ChannelId` is expected. Values above 2^53 keep full precision on every
target, and the snowflake creation time is one call away:

```mbt check
///|
test "snowflakes are typed and precise" {
  let id : @model.MessageId = @model.Id::parse("175928847299117063")
  debug_inspect(id.timestamp_ms(), content="1462015105796")
}
```

## Optional and nullable fields

Discord's wire models use `T?` for optional fields (the key may be absent)
and `Nullable[T]` for nullable fields (the key is present but may be `null`).
PATCH methods expose plain optional arguments: omit one to leave the field
unchanged, pass `[]` to clear an array, or use the corresponding
`clear_<field>=true` flag to clear a nullable scalar.

Use `@model.flatten` when reading a `Nullable[T]?` field and both absence and
JSON `null` should mean `None`:

```mbt check
///|
test "read an optional nullable guild nickname" {
  let fixtures = [
    (
      #|{"roles":[],"joined_at":null}
    ),
    (
      #|{"roles":[],"joined_at":null,"nick":null}
    ),
    (
      #|{"roles":[],"joined_at":null,"nick":"Moon"}
    ),
  ]
  let nicknames = fixtures.map(fixture => {
    let decoded : @model.GuildMember = @json.from_json(@json.parse(fixture))
    @model.flatten(decoded.nick)
  })
  debug_inspect(
    nicknames,
    content=(
      #|[None, None, Some("Moon")]
    ),
  )
}
```

`flatten` is deliberately lossy. Keep the original `Nullable[T]?` when a
PATCH body, cache merge, or other operation must distinguish a missing key
from an explicit `null`.

## Mentions and timestamps

Mention helpers format the `<...>` forms Discord renders in message content:

```mbt check
///|
test "format Discord mentions" {
  let user_id : @model.UserId = @model.Id::parse("80351110224678912")
  let channel_id : @model.ChannelId = @model.Id::parse("103735883630395392")
  inspect(@util.user_mention(user_id), content="<@80351110224678912>")
  inspect(@util.channel_mention(channel_id), content="<#103735883630395392>")
}
```

`role_mention`, `slash_command_mention`, and `custom_emoji_mention` follow
the same shape. `timestamp` formats Unix seconds as a Discord timestamp with
an optional display style:

```mbt check
///|
test "format timestamps" {
  inspect(@util.timestamp(1462015105L), content="<t:1462015105>")
  inspect(
    @util.timestamp(1462015105L, style=Relative),
    content="<t:1462015105:R>",
  )
}
```

## Safe message content

Escape user-controlled markdown and mentions before including them in a
message, then split the result to Discord's 2000 UTF-16-code-unit content
limit:

```mbt check
///|
test "escape and split user content" {
  let source = "**hello** @everyone https://example.test/a_b"
  let safe = @util.escape_mentions(@util.escape_markdown(source))
  assert_false(safe.contains("@everyone"))
  let chunks = @util.split_content(safe, limit=20)
  assert_eq(chunks.join(""), safe)
  for chunk in chunks {
    assert_true(chunk.length() <= 20)
  }
}
```

`escape_markdown` preserves HTTP, HTTPS, and Steam URLs and markdown-link
destinations while escaping markdown syntax elsewhere. `escape_mentions`
neutralizes `@everyone`, `@here`, and user or role mentions by inserting a
zero-width space. `split_content` preserves every code unit, prefers newline
and space boundaries, and never splits a surrogate pair or CRLF sequence.

## Outgoing embeds

The model constructors accept only fields Discord permits in outgoing
payloads, so receive-only fields do not need to be filled with `None`:

```mbt check
///|
let build_complete_embed : @model.Embed = Embed(
  title="Build complete",
  description="All checks passed.",
  color=0x57F287,
  author=EmbedAuthor("CI", icon_url="https://example.test/ci.png"),
  footer=EmbedFooter("discord.mbt"),
  image=EmbedImage("https://example.test/result.png"),
  thumbnail=EmbedThumbnail("https://example.test/status.png"),
  fields=[
    EmbedField("Target", "native", inline=true),
    EmbedField("Tests", "1273 passed", inline=true),
  ],
)

///|
test "outgoing embed constructor compiles" {
  let encoded = build_complete_embed.to_json()
  assert_true(encoded.stringify().contains("Build complete"))
  assert_false(encoded.stringify().contains("proxy_url"))
}
```

Unspecified optional fields are omitted from JSON. The `fields` array is
copied by `Embed(...)`, so mutating the caller's array later does not alter the
embed.

## CDN URLs

CDN helpers build image URLs from an entity id and its `ImageHash`. Animated
hashes (an `a_` prefix) default to GIF, other hashes to PNG; pass `format` to
override and `size` for a power-of-two size:

```mbt check
///|
test "build CDN URLs" {
  let user_id : @model.UserId = @model.Id::parse("80351110224678912")
  inspect(
    @util.user_avatar_url(user_id, ImageHash("deadbeef"), size=128),
    content="https://cdn.discordapp.com/avatars/80351110224678912/deadbeef.png?size=128",
  )
}
```

`guild_icon_url`, `guild_banner_url`, `emoji_url`, `sticker_url`, and the
default-avatar helpers cover the other CDN routes. An invalid `size` or a
format the asset cannot have raises `CdnUrlError` before any IO.

## Permissions

`base_permissions` follows Discord's official permission pseudocode: owners
and administrators receive all permissions, otherwise `@everyone` permissions
combine with every member role:

```mbt check
///|
test "compute base permissions" {
  let permissions = @util.base_permissions(
    is_owner=false,
    everyone_permissions=@model.Permissions::view_channel(),
    role_permissions=[@model.Permissions::send_messages()],
  )
  assert_true(permissions.contains(@model.Permissions::view_channel()))
  assert_true(permissions.contains(@model.Permissions::send_messages()))
}
```

Chain it with `channel_permissions` (and `apply_communication_timeout`) to
compute effective channel permissions without a cache, supplying role and
overwrite data from events or REST. The opt-in cache wraps this computation
as `InMemoryCache::permissions_in` — see
[Events and intents](04-events-intents.mbt.md).
