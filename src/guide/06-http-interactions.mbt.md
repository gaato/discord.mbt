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
  let endpoint = app.serve(group, token~, sync=false)
  endpoint.handle(body)
}
```

`App::serve` accepts either `token` or an existing `client`. Supplying both
`client` and `application_id` avoids startup HTTP requests when synchronization
is disabled:

```mbt check
///|
async fn serve_with_existing_client(
  app : @discord.App,
  group : @async.TaskGroup[Unit],
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
) -> @discord.InteractionEndpoint {
  app.serve(group, client~, application_id~, sync=false)
}
```

Set `sync=true` only when this process should perform the configured
`CommandSync`. Synchronization uses bulk overwrite and can remove commands not
declared by this `App`.

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
    NoResponse => send_status(500)
    TimedOut => send_status(202)
  }
}
```

`TimedOut` means the initial response was not available before the deadline;
the handler remains attached to the task group. Returning HTTP 202 by itself
does not acknowledge an interaction, so slow handlers should use a deferred
handler mode.

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
      sync=true,
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

Gateway and Voice transports remain native-only. The JavaScript backend is for
the REST client, signature verification, and gateway-free HTTP interactions.
With `moonbitlang/async@0.21.2`, the JS Fetch transport also completes
null-body 204 responses. The `workers_echo` suite covers this with a deferred
interaction-response deletion that runs to completion under `waitUntil`.
