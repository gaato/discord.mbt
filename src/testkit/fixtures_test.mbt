///|
test "fixture overrides preserve permissions resolved data and modal origin" {
  let permissions = @model.Permissions(8UL)
  let actor = @testkit.user(bot=true)
  let membership = @testkit.guild_member(user=actor, permissions~)
  assert_eq(membership.permissions, Some(permissions))
  assert_eq(@testkit.role(permissions~).permissions, permissions)
  assert_eq(@testkit.interaction(actor~).user.unwrap().id, actor.id)
  let guild = (@model.Id(1UL), membership)
  assert_eq(
    @testkit.interaction(actor~, guild~).guild_member.unwrap().user.unwrap().id,
    actor.id,
  )
  let partial = { ..membership, user: None, }
  assert_true(
    @testkit.interaction(guild=(@model.Id(1UL), partial)).guild_member.unwrap().user
    is Some(_),
  )
  let resolved : @model.ResolvedData = @json.from_json({
    "users": { "200000000000000001": actor.to_json() },
  })
  assert_true(
    @testkit.slash("run", resolved~).data
    is Some(Command({ resolved: Some(_), .. })),
  )
  assert_true(
    @testkit.component("pick", typ=5, values=[actor.id.to_string()], resolved~).data
    is Some(Component({ resolved: Some(_), .. })),
  )
  let source = @testkit.message(components=[], channel_id=@model.Id(12UL))
  let modal = @testkit.modal("form", resolved~, message=source)
  assert_eq(modal.channel_id, Some(source.channel_id))
  assert_true(modal.data is Some(Modal({ resolved: Some(_), .. })))
  assert_true(modal.message is Some(_))
  try
    @testkit.modal("form", message=source, base=@testkit.interaction())
  catch {
    @testkit.FixtureError::InconsistentContext(_) => ()
  } noraise {
    _ => fail("expected channel mismatch")
  }
}

///|
test "fixture defaults are deterministic and collections are independent" {
  assert_eq(@testkit.user().to_json(), @testkit.user().to_json())
  assert_eq(@testkit.message().to_json(), @testkit.message().to_json())
  let first = @testkit.guild_member()
  first.roles.push(@testkit.role().id)
  assert_true(@testkit.guild_member().roles.is_empty())
  assert_eq(
    @testkit.interaction().application_id,
    @testkit.default_application_id(),
  )
}

///|
test "fixtures derive guild actors and reject contradictory context" {
  let actor = @testkit.user(id=@model.Id(42UL))
  let guild = (@model.Id(99UL), @testkit.guild_member(user=actor))
  assert_eq(
    @testkit.interaction(guild~).guild_member.unwrap().user.unwrap().id,
    actor.id,
  )
  try @testkit.interaction(guild~, actor=@testkit.user()) catch {
    @testkit.FixtureError::InconsistentContext(_) => ()
  } noraise {
    _ => fail("expected actor mismatch")
  }
  let message = @testkit.message(channel_id=@model.Id(123UL))
  assert_eq(
    @testkit.component("button", message~).channel_id,
    Some(message.channel_id),
  )
  try
    @testkit.component("button", message~, base=@testkit.interaction())
  catch {
    @testkit.FixtureError::InconsistentContext(_) => ()
  } noraise {
    _ => fail("expected channel mismatch")
  }
}

///|
async test "context command fixtures resolve targets and component/modal fixtures dispatch" {
  let app = @app.App()
  app.command(
    @app.user_command(
      name="User",
      handler=Immediate((_, target) => {
        @app.CommandReply::message(content=target.user.username)
      }),
    ),
  )
  app.command(
    @app.message_command(
      name="Message",
      handler=Immediate((_, target) => {
        @app.CommandReply::message(content=target.content)
      }),
    ),
  )
  app.on_component_raw(prefix="button", ctx => {
    ctx.respond(content=ctx.message().content)
  })
  app.on_modal_raw(prefix="form", ctx => ctx.respond(content="modal"))
  let harness = @testkit.Harness(app)
  for
    input in [
      @testkit.user_command("User", @testkit.user()),
      @testkit.message_command("Message", @testkit.message()),
      @testkit.component("button"),
      @testkit.modal("form"),
    ] {
    let result = harness.dispatch(input)
    assert_eq(result.routing, Matched)
    assert_true(result.errors().is_empty())
    assert_true(result.initial_response() is Some(_))
  }
}
