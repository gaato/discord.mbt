///|
fn overwrite(
  id : UInt64,
  typ : @model.OverwriteType,
  allow : @model.Permissions,
  deny : @model.Permissions,
) -> @model.Overwrite {
  { id: Id(id), typ, allow, deny }
}

///|
test "base permissions follow owner, role, and administrator rules" {
  assert_eq(@util.all_permissions().bits(), 0x1F7FFFFFFFFFFFUL)
  let everyone = @model.Permissions::view_channel()
  let combined = @util.base_permissions(
    is_owner=false,
    everyone_permissions=everyone,
    role_permissions=[
      @model.Permissions::send_messages(),
      @model.Permissions::read_message_history(),
    ],
  )
  assert_true(combined.contains(@model.Permissions::view_channel()))
  assert_true(combined.contains(@model.Permissions::send_messages()))
  assert_true(combined.contains(@model.Permissions::read_message_history()))

  let owner = @util.base_permissions(
    is_owner=true,
    everyone_permissions=@model.Permissions::none(),
    role_permissions=[],
  )
  assert_eq(owner.bits(), @util.all_permissions().bits())

  let administrator = @util.base_permissions(
    is_owner=false,
    everyone_permissions=@model.Permissions::none(),
    role_permissions=[@model.Permissions::administrator()],
  )
  assert_eq(administrator.bits(), @util.all_permissions().bits())
}

///|
test "channel overwrites use official precedence and aggregate roles" {
  let base = @model.Permissions::view_channel() |
    @model.Permissions::send_messages() |
    @model.Permissions::embed_links() |
    @model.Permissions::attach_files()
  let permissions = @util.channel_permissions(
    base~,
    guild_id=Id(1UL),
    member_id=Id(2UL),
    role_ids=[Id(10UL), Id(11UL)],
    overwrites=[
      // @everyone applies first.
      overwrite(
        1UL,
        Role,
        @model.Permissions::read_message_history(),
        @model.Permissions::send_messages(),
      ),
      // All role denies and allows must be aggregated before either is
      // applied. Thus role 11's SEND_MESSAGES allow wins over role 10's
      // unrelated deny stage.
      overwrite(
        10UL,
        Role,
        @model.Permissions::attach_files(),
        @model.Permissions::embed_links(),
      ),
      overwrite(
        11UL,
        Role,
        @model.Permissions::send_messages(),
        @model.Permissions::attach_files(),
      ),
      // The member overwrite applies last.
      overwrite(
        2UL,
        Member,
        @model.Permissions::embed_links(),
        @model.Permissions::attach_files(),
      ),
      // Unrelated and future overwrite categories do not affect the result.
      overwrite(
        99UL,
        Member,
        @model.Permissions::administrator(),
        @model.Permissions::none(),
      ),
      overwrite(
        2UL,
        Unknown(7),
        @model.Permissions::administrator(),
        @model.Permissions::none(),
      ),
    ],
  )
  assert_true(permissions.contains(@model.Permissions::view_channel()))
  assert_true(permissions.contains(@model.Permissions::read_message_history()))
  assert_true(permissions.contains(@model.Permissions::send_messages()))
  assert_true(permissions.contains(@model.Permissions::embed_links()))
  assert_false(permissions.contains(@model.Permissions::attach_files()))
  assert_false(permissions.contains(@model.Permissions::administrator()))
}

///|
test "administrator bypasses channel overwrites" {
  let base = @model.Permissions::administrator() |
    @model.Permissions::view_channel()
  let permissions = @util.channel_permissions(
    base~,
    guild_id=Id(1UL),
    member_id=Id(2UL),
    role_ids=[],
    overwrites=[
      overwrite(1UL, Role, @model.Permissions::none(), @util.all_permissions()),
    ],
  )
  assert_eq(permissions.bits(), @util.all_permissions().bits())
}

///|
test "communication timeout is opt-in and administrator exempt" {
  let permissions = @model.Permissions::view_channel() |
    @model.Permissions::read_message_history() |
    @model.Permissions::send_messages()
  let active = @util.apply_communication_timeout(
    permissions~,
    communication_disabled_until=Timestamp("2100-01-01T00:00:00Z"),
    now_unix_ms=0L,
  )
  assert_true(active.contains(@model.Permissions::view_channel()))
  assert_true(active.contains(@model.Permissions::read_message_history()))
  assert_false(active.contains(@model.Permissions::send_messages()))

  let expired = @util.apply_communication_timeout(
    permissions~,
    communication_disabled_until=Timestamp("1970-01-01T00:00:00Z"),
    now_unix_ms=1L,
  )
  assert_eq(expired.bits(), permissions.bits())

  let administrator = @model.Permissions::administrator() |
    @model.Permissions::send_messages()
  let exempt = @util.apply_communication_timeout(
    permissions=administrator,
    communication_disabled_until=Timestamp("2100-01-01T00:00:00Z"),
    now_unix_ms=0L,
  )
  assert_eq(exempt.bits(), administrator.bits())
}
