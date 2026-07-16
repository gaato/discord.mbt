///|
async test "guild command ref edit permissions delegates bearer authorization" {
  let client = Client("test-token")
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_headers : Ref[Map[String, String]?] = Ref(None)
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((route, path, headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_headers.val = Some(headers)
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let application_id : @model.ApplicationId = Id(500UL)
  let guild_id : @model.GuildId = Id(510UL)
  let command_id : @model.CommandId = Id(520UL)
  let target_id : @model.GenericId = Id(530UL)
  let permissions : Array[@model.ApplicationCommandPermission] = [
    {
      id: target_id,
      typ: @model.ApplicationCommandPermissionType::User,
      permission: true,
    },
  ]
  try
    client
    .guild_command_ref(application_id, guild_id, command_id)
    .edit_permissions(permissions, bearer_token="oauth-token")
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail permissions decoding")
  }
  inspect(captured_method.val, content="Put")
  inspect(
    captured_path.val,
    content="/api/v10/applications/500/guilds/510/commands/520/permissions",
  )
  guard captured_headers.val is Some(headers) else {
    fail("expected request headers")
  }
  inspect(
    headers.get_or_default("authorization", ""),
    content="Bearer oauth-token",
  )
  json_inspect(captured_body.val, content={
    "permissions": [{ "id": "530", "type": 2, "permission": true }],
  })
}

///|
async test "application ref create test entitlement delegates owner body" {
  let client = Client("test-token")
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((route, path, _headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let application_id : @model.ApplicationId = Id(540UL)
  let sku_id : @model.SkuId = Id(550UL)
  let owner_id : @model.GenericId = Id(560UL)
  try
    client
    .application_ref(application_id)
    .create_test_entitlement(
      sku_id,
      owner_id,
      @model.EntitlementOwnerType::User,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail entitlement decoding")
  }
  inspect(captured_method.val, content="Post")
  inspect(captured_path.val, content="/api/v10/applications/540/entitlements")
  json_inspect(captured_body.val, content={
    "sku_id": "550",
    "owner_id": "560",
    "owner_type": 2,
  })
}

///|
async test "sku ref subscriptions delegates the bound sku path" {
  let client = Client("test-token")
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  client.perform_override_.val = Some((route, path, _headers, _body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let sku_id : @model.SkuId = Id(570UL)
  try client.sku_ref(sku_id).subscriptions() catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail subscriptions decoding")
  }
  inspect(captured_method.val, content="Get")
  inspect(captured_path.val, content="/api/v10/skus/570/subscriptions")
}
