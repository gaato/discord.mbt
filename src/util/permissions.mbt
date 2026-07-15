///|
/// All permission bits currently defined by Discord.
///
/// Bit 47 is intentionally excluded because Discord has not assigned it.
pub fn all_permissions() -> @model.Permissions {
  @model.Permissions::from_bits(0x1F7FFFFFFFFFFFUL)
}

///|
/// Compute a guild member's base permissions.
///
/// This follows Discord's official `compute_base_permissions` pseudocode:
/// guild owners and administrators receive all known permissions; otherwise
/// the `@everyone` permissions are combined with every member role.
///
/// ```mbt check
/// test "combine everyone and member-role permissions" {
///   let permissions = @util.base_permissions(
///     is_owner=false,
///     everyone_permissions=@model.Permissions::view_channel(),
///     role_permissions=[@model.Permissions::send_messages()],
///   )
///   assert_true(permissions.contains(@model.Permissions::view_channel()))
///   assert_true(permissions.contains(@model.Permissions::send_messages()))
/// }
/// ```
///
/// Chain it with `channel_permissions` to compute a member's effective
/// permissions in a channel without a cache; supply role and overwrite data
/// from the event, REST client, or your own cache:
///
/// ```mbt check
/// test "guard a handler with effective channel permissions" {
///   fn effective_channel_permissions(
///     guild_id : @model.GuildId,
///     owner_id : @model.UserId,
///     member_id : @model.UserId,
///     role_ids : Array[@model.RoleId],
///     everyone_permissions : @model.Permissions,
///     role_permissions : Array[@model.Permissions],
///     overwrites : Array[@model.Overwrite],
///   ) -> @model.Permissions {
///     let base = @util.base_permissions(
///       is_owner=member_id == owner_id,
///       everyone_permissions~,
///       role_permissions~,
///     )
///     @util.channel_permissions(
///       base~,
///       guild_id~,
///       member_id~,
///       role_ids~,
///       overwrites~,
///     )
///   }
///
///   let effective = effective_channel_permissions(
///     Id(1UL),
///     Id(2UL),
///     Id(3UL),
///     [],
///     @model.Permissions::view_channel(),
///     [@model.Permissions::send_messages()],
///     [],
///   )
///   assert_true(effective.contains(@model.Permissions::send_messages()))
/// }
/// ```
pub fn base_permissions(
  is_owner~ : Bool,
  everyone_permissions~ : @model.Permissions,
  role_permissions~ : Array[@model.Permissions],
) -> @model.Permissions {
  if is_owner {
    return all_permissions()
  }
  let mut permissions = everyone_permissions
  for role in role_permissions {
    permissions = permissions | role
  }
  if permissions.contains(@model.Permissions::administrator()) {
    all_permissions()
  } else {
    permissions
  }
}

///|
fn apply_overwrite(
  permissions : @model.Permissions,
  deny : @model.Permissions,
  allow : @model.Permissions,
) -> @model.Permissions {
  @model.Permissions::from_bits(permissions.bits() & deny.bits().lnot()) | allow
}

///|
fn has_role(role_ids : Array[@model.RoleId], target : UInt64) -> Bool {
  for role_id in role_ids {
    if role_id.value() == target {
      return true
    }
  }
  false
}

///|
/// Apply a channel's permission overwrites to already-computed base
/// permissions.
///
/// This follows Discord's official `compute_overwrites` order exactly:
/// `@everyone`, all member roles as one aggregated deny/allow pair, then the
/// member overwrite. Unknown overwrite types are ignored for forward
/// compatibility.
///
/// ```mbt check
/// test "a member overwrite wins after the everyone overwrite" {
///   let guild_id : @model.GuildId = Id(1UL)
///   let member_id : @model.UserId = Id(2UL)
///   let send = @model.Permissions::send_messages()
///   let overwrites : Array[@model.Overwrite] = [
///     {
///       id: guild_id.cast(),
///       typ: Role,
///       allow: @model.Permissions::none(),
///       deny: send,
///     },
///     {
///       id: member_id.cast(),
///       typ: Member,
///       allow: send,
///       deny: @model.Permissions::none(),
///     },
///   ]
///   let permissions = @util.channel_permissions(
///     base=send,
///     guild_id~,
///     member_id~,
///     role_ids=[],
///     overwrites~,
///   )
///   assert_true(permissions.contains(send))
/// }
/// ```
pub fn channel_permissions(
  base~ : @model.Permissions,
  guild_id~ : @model.GuildId,
  member_id~ : @model.UserId,
  role_ids~ : Array[@model.RoleId],
  overwrites~ : Array[@model.Overwrite],
) -> @model.Permissions {
  if base.contains(@model.Permissions::administrator()) {
    return all_permissions()
  }

  let guild_value = guild_id.value()
  let member_value = member_id.value()
  let mut everyone_allow = @model.Permissions::none()
  let mut everyone_deny = @model.Permissions::none()
  let mut roles_allow = @model.Permissions::none()
  let mut roles_deny = @model.Permissions::none()
  let mut member_allow = @model.Permissions::none()
  let mut member_deny = @model.Permissions::none()

  for overwrite in overwrites {
    let target = overwrite.id.value()
    match overwrite.typ {
      Role if target == guild_value => {
        everyone_allow = everyone_allow | overwrite.allow
        everyone_deny = everyone_deny | overwrite.deny
      }
      Role if target != guild_value && has_role(role_ids, target) => {
        roles_allow = roles_allow | overwrite.allow
        roles_deny = roles_deny | overwrite.deny
      }
      Member if target == member_value => {
        member_allow = member_allow | overwrite.allow
        member_deny = member_deny | overwrite.deny
      }
      _ => ()
    }
  }

  let permissions = apply_overwrite(base, everyone_deny, everyone_allow)
  let permissions = apply_overwrite(permissions, roles_deny, roles_allow)
  apply_overwrite(permissions, member_deny, member_allow)
}

///|
/// Apply Discord's communication-timeout permission restriction.
///
/// This is deliberately separate from `channel_permissions`: it is an
/// opt-in post-processing rule rather than part of Discord's published
/// `compute_overwrites` pseudocode. Call it only when
/// `communication_disabled_until` has a timestamp. Active timeouts retain
/// only `VIEW_CHANNEL` and `READ_MESSAGE_HISTORY`; administrators are exempt.
///
/// ```mbt check
/// test "an active timeout suppresses send permissions" {
///   let permissions = @model.Permissions::view_channel() |
///     @model.Permissions::send_messages()
///   let effective = @util.apply_communication_timeout(
///     permissions~,
///     communication_disabled_until=@model.Timestamp("2100-01-01T00:00:00Z"),
///     now_unix_ms=0L,
///   )
///   assert_true(effective.contains(@model.Permissions::view_channel()))
///   assert_false(effective.contains(@model.Permissions::send_messages()))
/// }
/// ```
pub fn apply_communication_timeout(
  permissions~ : @model.Permissions,
  communication_disabled_until~ : @model.Timestamp,
  now_unix_ms~ : Int64,
) -> @model.Permissions raise @model.TimestampError {
  if permissions.contains(@model.Permissions::administrator()) ||
    communication_disabled_until.unix_ms() <= now_unix_ms {
    return permissions
  }
  permissions &
  (
    @model.Permissions::view_channel() |
    @model.Permissions::read_message_history()
  )
}
