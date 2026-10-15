///|
fn audit_header(reason : String) -> String? {
  let route = DeleteChannel(channel_id=Id(1UL))
  base_headers("tok", route, Some(reason)).get("x-audit-log-reason")
}

///|
test "audit log reasons are percent-encoded UTF-8" {
  debug_inspect(
    audit_header("運用理由: テスト A&B%"),
    content=(
      #|Some("%E9%81%8B%E7%94%A8%E7%90%86%E7%94%B1%3A%20%E3%83%86%E3%82%B9%E3%83%88%20A%26B%25")
    ),
  )
  // already-encoded text is encoded again: the reason is plain text
  debug_inspect(
    audit_header("a%20b"),
    content=(
      #|Some("a%2520b")
    ),
  )
  // line breaks cannot reach the wire as header syntax
  debug_inspect(
    audit_header("one\r\ntwo"),
    content=(
      #|Some("one%0D%0Atwo")
    ),
  )
}

///|
async test "audit log reasons must be 1-512 characters after middleware" {
  let sent : Array[String?] = []
  let client = Client::offline(request => {
    sent.push(request.audit_reason)
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(1UL)
  let role_id : @model.RoleId = Id(2UL)
  client.delete_guild_role(guild_id, role_id, audit_reason="x".repeat(512))
  assert_eq(sent, [Some("x".repeat(512))])
  for reason in ["", "x".repeat(513)] {
    try client.delete_guild_role(guild_id, role_id, audit_reason=reason) catch {
      Validation(message~) =>
        inspect(
          message,
          content="audit_reason must be between 1 and 512 characters",
        )
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected a validation error for length \{reason.length()}")
    }
  }
  // the check sees the reason middleware hands on, not the caller's
  client.middleware((request, next) => {
    next({ ..request, audit_reason: Some(""), })
  })
  try client.delete_guild_role(guild_id, role_id, audit_reason="fine") catch {
    Validation(..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the rewritten reason to be validated")
  }
  assert_eq(sent.length(), 1)
}
