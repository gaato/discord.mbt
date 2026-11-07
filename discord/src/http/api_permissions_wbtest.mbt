///|
async test "computed permission endpoints request their paths and decode the bitfield" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let paths : Array[String] = []
  let buckets : Array[String] = []
  perform.val = Some((route, path, _headers, body, _files) => {
    assert_true(body is None)
    paths.push(path)
    buckets.push(route.bucket())
    {
      status: 200,
      headers: Map([]),
      // Above 2^53, so the string form must be kept exactly.
      body: { "permissions": "9007199254740993" },
    }
  })
  let guild_id : @model.GuildId = Id(10UL)
  let channel_id : @model.ChannelId = Id(20UL)
  let user_id : @model.UserId = Id(30UL)
  let role_id : @model.RoleId = Id(40UL)
  let results = [
    client.get_guild_member_permissions(guild_id, user_id),
    client.get_guild_role_permissions(guild_id, role_id),
    client.get_channel_member_permissions(channel_id, user_id),
    client.get_channel_member_permissions(channel_id, user_id, implicit=false),
    client.get_channel_role_permissions(channel_id, role_id, implicit=true),
    client.member_ref(guild_id, user_id).permissions(),
    client.role_ref(guild_id, role_id).permissions(),
    client.channel_ref(channel_id).member_permissions(user_id, implicit=false),
    client.channel_ref(channel_id).role_permissions(role_id),
  ]
  for permissions in results {
    assert_eq(permissions.bits(), 9007199254740993UL)
  }
  assert_eq(paths, [
    "/api/v10/guilds/10/permissions/member/30", "/api/v10/guilds/10/permissions/role/40",
    "/api/v10/channels/20/permissions/member/30", "/api/v10/channels/20/permissions/member/30?implicit=false",
    "/api/v10/channels/20/permissions/role/40?implicit=true", "/api/v10/guilds/10/permissions/member/30",
    "/api/v10/guilds/10/permissions/role/40", "/api/v10/channels/20/permissions/member/30?implicit=false",
    "/api/v10/channels/20/permissions/role/40",
  ])
  // Member and role ids are minor parameters, squashed in the bucket.
  assert_eq(buckets[0], "GET:/guilds/10/permissions/member/{}")
  assert_eq(buckets[1], "GET:/guilds/10/permissions/role/{}")
  assert_eq(buckets[3], "GET:/channels/20/permissions/member/{}")
  assert_eq(buckets[4], "GET:/channels/20/permissions/role/{}")
}

///|
test "computed permission routes are GETs without an audit log reason" {
  let routes : Array[Route] = [
    GetGuildMemberPermissions(guild_id=Id(1UL), user_id=Id(2UL)),
    GetGuildRolePermissions(guild_id=Id(1UL), role_id=Id(3UL)),
    GetChannelMemberPermissions(channel_id=Id(4UL), user_id=Id(2UL), query=""),
    GetChannelRolePermissions(channel_id=Id(4UL), role_id=Id(3UL), query=""),
  ]
  for route in routes {
    assert_true(route.method_() is Get)
    assert_true(route.needs_auth())
    assert_false(route.is_interaction())
    assert_false(route.supports_reason())
  }
}
