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

## CDN URLs

CDN helpers build image URLs from an entity id and its `ImageHash`. Animated
hashes (an `a_` prefix) default to GIF, other hashes to PNG; pass `format` to
override and `size` for a power-of-two size:

```mbt check
///|
test "build CDN URLs" {
  let user_id : @model.UserId = @model.Id::parse("80351110224678912")
  inspect(
    @util.user_avatar_url(user_id, @model.ImageHash("deadbeef"), size=128),
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
