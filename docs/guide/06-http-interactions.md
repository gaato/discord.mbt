# HTTP interactions

`App` can dispatch signed interaction requests without opening a Gateway
connection. The application still uses the same commands, components, modals,
and handlers as the native `Bot` executor.

## Create an endpoint

The caller owns the task group that keeps deferred handlers alive:

```moonbit
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

```moonbit
let endpoint = app.serve(
  group,
  client~,
  application_id~,
  sync=false,
)
```

Set `sync=true` only when this process should perform the configured
`CommandSync`. Synchronization uses bulk overwrite and can remove commands not
declared by this `App`.

## Dispatch outcomes

`endpoint.handle(body)` decodes JSON and returns callback JSON only for a
normal reply. Adapters that need explicit routing outcomes or multipart files
should decode `Interaction` and call:

```moonbit
///|
let outcome = endpoint.handle_interaction(interaction, deadline_ms=2500)
match outcome {
  Reply(response~, files~) => send_callback(response, files)
  NoRoute => send_status(404)
  NoResponse => send_status(500)
  TimedOut => send_status(202)
}
```

`TimedOut` means the initial response was not available before the deadline;
the handler remains attached to the task group. Returning HTTP 202 by itself
does not acknowledge an interaction, so slow handlers should use a deferred
handler mode.

## Verify before decoding

Discord signs the exact raw request body. On JavaScript, verify it before JSON
parsing or dispatch:

```moonbit
///|
let verified = @discord.verify_signature(
  public_key~,
  signature~,
  timestamp~,
  body=raw_body,
)
if !verified {
  return unauthorized_response()
}
let json = @json.parse(raw_body)
```

`verify_signature` uses WebCrypto Ed25519 and returns `false` for malformed
hex input or verification failures. It is available through the JavaScript
facade and the `gaato/discord/verify` package. Native HTTP adapters must provide
their own Ed25519 verification implementation.

## Cloudflare Workers

The `src/examples/workers_echo` adapter exports two promises:

1. A response promise resolves when the initial Discord callback is known.
2. A background promise resolves after the task group and deferred handlers
   finish; pass it to `ctx.waitUntil`.

The adapter should preserve the raw body for verification, answer Discord
PING requests through the endpoint, return a JSON callback with HTTP 200, and
map `NoRoute`, `NoResponse`, and `TimedOut` according to its deployment policy.
