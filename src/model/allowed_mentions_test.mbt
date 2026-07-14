///|
test "allowed mentions encode official wire fields" {
  let mentions = @model.AllowedMentions::new(
    parse=[@model.AllowedMentionType::Everyone],
    roles=[@model.Id::parse("100")],
    users=[@model.Id::parse("200")],
    replied_user=true,
  )
  json_inspect(mentions, content={
    "parse": ["everyone"],
    "roles": ["100"],
    "users": ["200"],
    "replied_user": true,
  })
}

///|
test "allowed mentions none suppresses all parsed categories" {
  json_inspect(@model.AllowedMentions::none(), content={ "parse": [] })
}

///|
test "allowed mentions reject parse and explicit list conflicts" {
  try
    @model.AllowedMentions::new(parse=[@model.AllowedMentionType::Users], users=[
      @model.Id::parse("200"),
    ])
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|ParseAndExplicit(typ=Users)
        ),
      )
  } noraise {
    _ => fail("expected users conflict")
  }
  try
    @model.AllowedMentions::new(parse=[@model.AllowedMentionType::Roles], roles=[
      @model.Id::parse("100"),
    ])
  catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|ParseAndExplicit(typ=Roles)
        ),
      )
  } noraise {
    _ => fail("expected roles conflict")
  }
}

///|
test "allowed mentions reject more than 100 explicit ids" {
  let roles : Array[@model.RoleId] = Array::make(101, @model.Id::parse("100"))
  try @model.AllowedMentions::new(roles~) catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|TooManyRoles(count=101)
        ),
      )
  } noraise {
    _ => fail("expected role count validation")
  }
  let users : Array[@model.UserId] = Array::make(101, @model.Id::parse("200"))
  try @model.AllowedMentions::new(users~) catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|TooManyUsers(count=101)
        ),
      )
  } noraise {
    _ => fail("expected user count validation")
  }
}
