# HTTP interactions

`App` can dispatch signed interaction requests without opening a Gateway
connection. The application still uses the same commands, components, modals,
and handlers as the native `Bot` executor.

## Create an endpoint

The caller owns the task group that keeps deferred handlers alive:

```mbt check
///|
async fn dispatch_interaction(
  app : @discord.App,
  group : @async.TaskGroup[Unit],
  token : String,
  body : Json,
) -> Json? {
  let endpoint = app.serve(group, token~)
  endpoint.handle(body)
}
```

`App::serve` accepts either `token` or an existing `client`. Supplying both
`client` and `application_id` avoids startup HTTP requests:

```mbt check
///|
async fn serve_with_existing_client(
  app : @discord.App,
  group : @async.TaskGroup[Unit],
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
) -> @discord.InteractionEndpoint {
  app.serve(group, client~, application_id~)
}
```

For an HTTP host, pass the exact request bytes and the two signature headers
to `handle_signed_http`. The method verifies the signature before decoding
JSON, then returns a status, optional content type, and bytes or multipart
chunks. The host adapter translates only its request and response conventions:

```mbt check
///|
async fn dispatch_signed_http(
  endpoint : @discord.InteractionEndpoint,
  verifier : @discord.InteractionVerifier,
  raw_body : Bytes,
  signature : String?,
  timestamp : String?,
) -> @discord.InteractionHttpResponse {
  endpoint.handle_signed_http(
    { http_method: "POST", signature, timestamp, body: raw_body, },
    verifier,
  )
}
```

The public request requires no absolute URL, environment binding, or host
execution context. Keep the `App::serve` task group alive after the initial
response to finish deferred handlers. Hosts with `waitUntil` can attach that
group's completion promise; other hosts choose their own lifetime policy.

Command registration is a separate deploy-time step. Run a one-shot program
that builds the same App and calls `app.sync_commands(client, application_id,
scope~)` before starting or updating the HTTP deployment. The call returns an
`@app.SyncReport`; print it to see each scope's changes and `overwritten` flag:

```mbt check
///|
async fn register_commands(
  app : @app.App,
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  scope : @app.CommandScope,
) -> Unit {
  let report = app.sync_commands(client, application_id, scope~)
  println("\{Repr(report)}")
}
```

The default `unowned=Delete` removes undeclared commands, while `unowned=Keep`
retains them. The Entry Point command is always preserved. A matching catalog
sends no overwrite PUT (the GET still runs). Do not synchronize per request.

```mbt check
///|
async test "registration reports an unchanged catalog with an entry point" {
  let spec = @interaction.CommandSpec::slash("echo", "Echo")
  let (payload, report) = @framework.plan_command_sync(
    [spec],
    [spec.to_json(), { "id": "11", "type": 4, "name": "Launch" }],
    unowned=Delete,
  )
  assert_true(payload is None)
  assert_false(report.overwritten)
  assert_eq(report.unchanged, ["echo"])
  assert_eq(report.preserved, ["4:Launch"])
  ignore(register_commands)
}
```

## Configure the Discord endpoint

Set the public interactions URL on the current application, then fetch the
`verify_key` used to validate signed requests. Discord verifies the URL with a
PING while setting it; interactions are no longer delivered over the Gateway
while the endpoint remains configured.

```mbt check
///|
async fn configure_interactions_endpoint(client : @dhttp.Client) -> String? {
  ignore(
    client.edit_current_application(
      interactions_endpoint_url="https://bot.example.com/interactions",
    ),
  )
  client.get_current_application().verify_key
}

///|
async fn restore_gateway_interactions(client : @dhttp.Client) -> Unit {
  ignore(client.edit_current_application(clear_interactions_endpoint_url=true))
}
```

Clearing `interactions_endpoint_url` removes the HTTP endpoint and restores
interaction delivery over the Gateway.

## Dispatch outcomes

`endpoint.handle(body)` decodes JSON and returns callback JSON only for a
normal reply. Adapters that need explicit routing outcomes or multipart files
should decode `Interaction` and call:

```mbt check
///|
async fn route_outcome(
  endpoint : @discord.InteractionEndpoint,
  interaction : @model.Interaction,
  send_callback : (@model.InteractionResponse, Array[@dhttp.FileUpload]?) -> Unit,
  send_status : (Int) -> Unit,
) -> Unit {
  let outcome = endpoint.handle_interaction(interaction, deadline_ms=2500)
  match outcome {
    Reply(response~, files~) => send_callback(response, files)
    NoRoute => send_status(404)
    NoResponse => send_status(202)
    TimedOut => send_status(504)
  }
}
```

`TimedOut` means the initial response was not available before the deadline;
the handler remains attached to the task group. `NoResponse` is for a handler
that already sent the callback through Discord REST. Slow handlers should
instead use a deferred handler mode so the endpoint returns an initial ACK.

## Verify before decoding

Discord signs the exact raw request body. Verify it before JSON parsing or
dispatch. This adapter returns `None` for an unauthorized request:

```mbt check
///|
fn parse_verified(
  verifier : @discord.InteractionVerifier,
  signature : String,
  timestamp : String,
  raw_body : BytesView,
) -> Json? raise {
  let verified = verifier.verify(signature~, timestamp~, body=raw_body)
  if !verified {
    return None
  }
  Some(@json.parse(@utf8.decode(raw_body)))
}
```

Construct `InteractionVerifier` once from the application's hexadecimal public
key and reuse it across requests. Verification is synchronous and implemented
entirely in MoonBit on both JavaScript and native. Invalid public-key
configuration raises `InteractionVerifierError`; malformed request signatures
and verification failures return `false`. The one-shot `verify_signature`
helper is available when retaining a verifier is impractical.

## Native HTTP server

The native facade includes a complete signed-interactions server:

```mbt check
///|
async fn run_server(
  app : @discord.App,
  public_key : String,
  token : String,
) -> Unit {
  @async.with_task_group(group => {
    let server = @discord.serve_interactions(
      group,
      app,
      addr="127.0.0.1:8080",
      public_key~,
      token~,
    )
    println("listening on \{server.addr()}")
  })
}

///|
test "http interaction declarations compile" {
  ignore(dispatch_interaction)
  ignore(serve_with_existing_client)
  ignore(configure_interactions_endpoint)
  ignore(restore_gateway_interactions)
  ignore(route_outcome)
  ignore(parse_verified)
  ignore(run_server)
}
```

The server validates and expands the public key before binding its socket, then
reuses that verifier for every request. It verifies signatures against the raw
body, handles Discord PINGs, dispatches through `App::serve`, returns 404 for
`NoRoute`, and returns 202 for `NoResponse` or `TimedOut`. Use a reverse proxy
for public HTTPS termination.

## Cloudflare Workers

On per-request runtimes such as Workers, constructing `App()` for every request
also rebuilds its in-memory cooldown store. Those cooldowns are therefore inert
across requests. Implement `gaato/discord/cooldown.CooldownStore` over KV or a
Durable Object and inject it with `App(cooldown_store=...)` to enforce real
cooldowns. The implementation must own its clock and atomically acquire each
key's window; account for the storage service's consistency and atomicity
guarantees. The TCP `RemoteCooldownStore` is native-only.

The `src/examples/workers_echo` adapter exports two promises:

1. A response promise resolves when the initial Discord callback is known.
2. A background promise resolves after the task group and deferred handlers
   finish; pass it to `ctx.waitUntil`.

The adapter should preserve the raw body for verification, answer Discord
PING requests through the endpoint, return a JSON callback with HTTP 200, and
map `NoRoute`, `NoResponse`, and `TimedOut` according to its deployment policy.
The example maps malformed interaction payloads to 400, `NoRoute` to 404,
`NoResponse` to 202, internal dispatch failures to 500, and `TimedOut` to 504.

Replies containing `FileUpload` values become a multipart callback body. The
adapter exposes a Web `ReadableStream` that emits the existing multipart text
and `Bytes` chunks in order, without concatenating them. Cancelling that stream
drops unsent chunks and does not leave a MoonBit producer task behind.

Run its signed endpoint tests in Cloudflare's local runtime with:

```fish
cd src/examples/workers_echo
npm ci
env WRANGLER_SEND_METRICS=false npm test
```

Voice remains native-only. Gateway bots also run on JavaScript (including
Durable Objects) and moonrun Wasm; the JavaScript backend also serves REST,
signature verification, and gateway-free HTTP interactions.
With `moonbitlang/async@0.22.1`, the JS Fetch transport also completes
null-body 204 responses. The `workers_echo` suite covers this with a deferred
interaction-response deletion that runs to completion under `waitUntil`.
