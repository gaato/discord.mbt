# Guard a handler with effective permissions

The `util` package implements Discord's permission order without depending on
a cache. Supply role and overwrite data from the event, REST client, or your own
cache.

```moonbit
///|
fn effective_channel_permissions(
  guild_id : @model.GuildId,
  owner_id : @model.UserId,
  member_id : @model.UserId,
  role_ids : Array[@model.RoleId],
  everyone_permissions : @model.Permissions,
  role_permissions : Array[@model.Permissions],
  overwrites : Array[@model.Overwrite],
) -> @model.Permissions {
  let base = @util.base_permissions(
    is_owner=member_id == owner_id,
    everyone_permissions~,
    role_permissions~,
  )
  @util.channel_permissions(
    base~,
    guild_id~,
    member_id~,
    role_ids~,
    overwrites~,
  )
}

///|
fn require_send_messages(permissions : @model.Permissions) -> Unit raise {
  let required = @model.Permissions::send_messages()
  if !permissions.contains(required) {
    raise @discord.HandlerError::MissingPermission(required)
  }
}
```

`base_permissions` handles the guild owner, `@everyone`, member roles, and
`ADMINISTRATOR`. `channel_permissions` then applies the `@everyone` overwrite,
the aggregated member-role overwrites, and the member overwrite.

Communication timeout is an explicit post-processing step:

```moonbit
///|
let effective = @util.apply_communication_timeout(
  permissions=effective,
  communication_disabled_until=until,
  now_unix_ms~,
)
```

Call it only when `communication_disabled_until` has a timestamp. Active
timeouts retain `VIEW_CHANNEL` and `READ_MESSAGE_HISTORY`; administrators are
exempt.
