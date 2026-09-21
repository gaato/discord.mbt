# Testing an App without Discord

Add `"gaato/discord/testkit"` to the `import { ... } for "test"` block of
your package's `moon.pkg`. The package supports native and JS and is not
re-exported by the root facade.

The harness runs real App validation, attachment, routing, argument decoding,
checks, middleware, error policies and response validation. It captures the
initial callback and uses a strict scripted transport for the Discord Client
given to handlers. There is no bot token, Gateway, or Discord server to start.

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
  let harness = @testkit.Harness(app)
  let result = harness.dispatch(@testkit.slash("hello"))
  assert_eq(result.routing, Matched)
  assert_true(result.errors().is_empty())
  json_inspect(result.initial_response().unwrap().response.to_json(), content={
    "type": 4,
    "data": { "content": "Hello!" },
  })
  harness.assert_rest_complete()
}
```

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
`FixtureError`. Harness and input application IDs must agree.

## Strict REST

Queue `HttpResponse`s with `expect_rest`. Any typed or custom Route is accepted.
Matching is FIFO by method and exact `Route.path()` including the query string,
not by rate-limit bucket. Inspect body, headers and files through
`result.requests()`; `path` there includes `/api/v10`. The transport runs below
validation and middleware and above wire encoding, so it does not manufacture
multipart boundaries or final content-type headers.

```mbt check
///|
async test "a command using REST" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="gateway",
      description="Read a scripted response",
      args=@interaction.Args::unit(),
      handler=Raw(ctx => ctx.respond(content=ctx.client.get_gateway())),
    ),
  )
  let harness = @testkit.Harness(app)
  harness.expect_rest(GetGateway, {
    status: 200,
    headers: Map([]),
    body: { "url": "wss://example.invalid" },
  })
  let result = harness.dispatch(@testkit.slash("gateway"))
  assert_true(result.errors().is_empty())
  assert_eq(result.requests()[0].route.path(), "/gateway")
  harness.assert_rest_complete()
}
```

Scripts can span sequential dispatches. Always call `assert_rest_complete()`
at the end to catch unused expectations. Unexpected or mismatched requests
raise `TestkitError` even if a handler or error policy catches the HTTP error;
a mismatch does not consume the expected response. `harness.last_requests()`
exposes REST attempts, including mismatches, even after dispatch raises.
Initial callbacks are captured, not REST requests; original-response edits and
followups use REST.
429 responses become `DiscordHttpError::RateLimited` without retry or waiting.
Expected API/status/decode errors remain application errors in the result.

Inputs to the script and captured payloads are snapshotted. Request/response
accessors return copies, so assertions cannot alter saved payloads. `errors()`
copies the array but retains the original Error values. Headers and payloads
are available explicitly for assertions, not printed automatically.

## Results and lifecycle

- `routing`: `Matched`, `NoRoute`, or `Rejected` (failure before dispatch can
  reach a handler).
- `initial_response()`: the typed response and optional files, independently
  of success. A reply followed by an exception retains both.
- `errors()`: original errors in order. `App(Handler(...))` precedes policy
  invocation; `App(ErrorPolicy(...))` records a failing policy;
  `App(Framework(...))` includes raw autocomplete failures;
  `Dispatch(...)` records errors escaping the Framework. Warnings are not
  captured and existing policy behavior is unchanged.
- `no_response()`: matched, with neither response nor recorded error.

Every dispatch owns a new Client and Framework, closes the Client after its
task tree finishes, and defaults to a 5000 ms timeout. Timeouts cancel and join
owned work before raising `DispatchTimeout`; outer cancellation propagates
after cleanup. Neither invokes the error policy. Cancellation is cooperative:
an infinite CPU loop or indefinitely protected task cannot be forcibly stopped.
Tasks spawned into unrelated groups are outside this ownership guarantee.

One Harness only supports sequential calls; reentry/concurrent use raises
`Busy`. Separate Harness instances isolate records and may run concurrently.
They still share the supplied App's intentional state, such as cooldowns.
Normal results, including application failures, permit reuse. Timeout,
cancellation, or script failure requires a new Harness.

The network guarantee covers only the Harness-created Discord Client. Inject
your own fakes for LLM/other HTTP clients. Multi-interaction Gateway waiters,
HTTP endpoint signature/deadline behavior, and a virtual Discord server are
not part of this handler-level testkit.
