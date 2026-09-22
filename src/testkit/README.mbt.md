# Testing an App without Discord

Add `"gaato/discord/testkit"` to the `import { ... } for "test"` block of
your package's `moon.pkg`. The package depends only on `@model`, supports
native and JS, and is not re-exported by the root facade.

The testkit provides fixtures: deterministic interactions and models to feed
into your handlers. Everything else is the production API with the network
removed: `@http.Client::offline` answers REST calls from a function you
write, `@framework.ResponseGate::capture` collects the initial callback, and
`Framework::process_with` runs the same validation, routing, decoding,
checks, middleware, and error policy as a live executor.

```mbt check
///|
async test "an immediate command" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="hello",
      description="Say hello",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => @app.CommandReply::message(content="Hello!")),
    ),
  )
  app.validate()
  let client = @http.Client::offline(_ => fail("no REST call expected"))
  let application_id = @testkit.default_application_id()
  let framework = @framework.Framework(client, application_id)
  app.attach(framework, client~, application_id~) |> ignore
  let interaction = @testkit.slash("hello")
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  json_inspect(capture.get().response.to_json(), content={
    "type": 4,
    "data": { "content": "Hello!" },
  })
}
```

`process_with` returns whether a handler matched. The captured value is the
initial callback only: original-response edits and followups go through
REST, so they arrive at the offline handler like any other call.

## Fixtures

`user`, `guild_member`, `role`, and `message` provide minimal typed models.
`slash`, `user_command`, `message_command`, `autocomplete`, `component`, and
`modal` provide interactions. Defaults have fixed IDs, a fixed timestamp,
synthetic tokens, and fresh collections; no global counter or wall clock is
used. Override common context with `interaction(...)` and pass it as `base`.
Use ordinary model struct updates for fields outside these small constructors,
including deliberately malformed inputs.

```mbt check
///|
test "a guild component interaction" {
  let actor = @testkit.user(username="tester")
  let membership = @testkit.guild_member(user=actor, roles=[@testkit.role().id])
  let base = @testkit.interaction(guild=(@model.Id(42UL), membership))
  let input = @testkit.component("ticket:close:42", base~)
  assert_eq(input.guild_member.unwrap().user.unwrap().username, "tester")
}
```

Guild fixtures derive the actor from the member, and context commands populate
their resolved targets. Component fixtures derive the channel from the source
message when no base is supplied. Contradictory actors/channels raise
`FixtureError`. Interactions carry `default_application_id()` unless a base
says otherwise; give the same id to `Framework` and `App::attach`.

## REST

The offline handler receives each logical call as an `@http.HttpRequest`
after validation and your own HTTP middleware: the typed `Route`, the JSON
body, files, and extra headers. Match on the route to answer, and push the
request into an array to assert on it afterwards. A response with status 400
or above becomes `DiscordHttpError::Api` in the handler, 429 becomes
`RateLimited` without waiting, and a decode failure becomes `Deserialize`,
exactly as online.

```mbt check
///|
async test "a command using REST" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="gateway",
      description="Read the gateway URL",
      args=@interaction.Args::unit(),
      handler=Raw(ctx => ctx.respond(content=ctx.client.get_gateway())),
    ),
  )
  let requests : Array[@http.HttpRequest] = []
  let client = @http.Client::offline(request => {
    requests.push(request)
    match request.route {
      GetGateway =>
        { status: 200, headers: {}, body: { "url": "wss://example.invalid" }, }
      route => fail("unexpected REST call: \{route.path()}")
    }
  })
  let application_id = @testkit.default_application_id()
  let framework = @framework.Framework(client, application_id)
  app.attach(framework, client~, application_id~) |> ignore
  let interaction = @testkit.slash("gateway")
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  assert_true(requests is [{ route: GetGateway, .. }])
  json_inspect(capture.get().response.to_json(), content={
    "type": 4,
    "data": { "content": "wss://example.invalid" },
  })
}
```

Because the handler is ordinary code, a test can answer the same route
differently on successive calls, return an error body to exercise a failure
path, or raise a `DiscordHttpError` directly. `FileUpload` exposes
`filename()`, `content()`, and `content_type()` for assertions on uploads.

## Failures

Handler errors go to the App's error policy, as in production. A test of
the policy itself reads what it produced: the captured error reply for a
known `HandlerError`, or the warning through `App::on_warn` that the default
policy emits for anything else. A test of the handler alone replaces the
policy with one that records the original error:

```mbt check
///|
async test "a failing handler" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="boom",
      description="Fail",
      args=@interaction.Args::unit(),
      handler=Raw(_ => fail("handler failed")),
    ),
  )
  let failures : Array[Error] = []
  app.error_policy((_, error) => failures.push(error))
  let client = @http.Client::offline(_ => fail("no REST call expected"))
  let application_id = @testkit.default_application_id()
  let framework = @framework.Framework(client, application_id)
  app.attach(framework, client~, application_id~) |> ignore
  let interaction = @testkit.slash("boom")
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  assert_true(failures is [Failure(_)])
  assert_true(capture.try_get() is None)
}
```

A handler that neither responds nor fails also leaves `capture.try_get()`
empty. Wrap `process_with` in `@async.with_timeout` when a test must bound a
handler that may wait forever.
