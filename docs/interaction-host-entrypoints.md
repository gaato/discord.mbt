# Interaction HTTP host entry points

This is the evidence used to decide where a `discord.mbt` Interaction HTTP API
should end and a host adapter should begin. The rows describe *delivery and
lifetime conventions*, not just JavaScript engine compatibility. The links are
the host's own documentation, checked on 2026-09-23.

| Host | Entry and response | Work after response | Repository check |
| --- | --- | --- | --- |
| [Cloudflare Workers](https://developers.cloudflare.com/workers/runtime-apis/handlers/fetch/) | `fetch(request, env, ctx) → Response` | `ctx.waitUntil` | `workers_echo` in local workerd |
| [Deno Deploy](https://docs.deno.com/deploy/reference/runtime/) | server startup, then `Request → Response` | Process lifecycle | `deno_echo` under Deno; Deploy not tested |
| [Fastly Compute JS](https://www.fastly.com/documentation/guides/compute/developer-guides/javascript/) | `FetchEvent.request`, `event.respondWith` | [`event.waitUntil`](https://www.fastly.com/documentation/reference/compute/sdks/javascript/js-compute/globals/interface.FetchEvent/) | Fake event boundary test; Fastly runtime not tested |
| [Spin HTTP](https://spinframework.dev/v4/http-trigger) | WIT `wasi:http/handler`, P3 async | Component invocation lifetime | WASIp2 signed PING/echo experiment in local Spin 4.1 |
| [Lambda Function URL](https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html) | payload v2 JSON event and response envelope | No `waitUntil` in the Function URL event model | Local event conversion test; Lambda not invoked |
| [Vercel Node Functions](https://vercel.com/docs/functions/runtimes/node-js) | module `fetch(request) → Response` | [`waitUntil`](https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package) | `vercel_echo` with injected lifetime collector |
| [Netlify Functions](https://docs.netlify.com/build/functions/api/) and [Edge Functions](https://docs.netlify.com/build/edge-functions/api/) | `(request, context) → Response` | `context.waitUntil` | Documentation only |
| [Supabase Edge](https://supabase.com/docs/guides/functions/quickstart) | `Deno.serve(handler)` | [`EdgeRuntime.waitUntil`](https://supabase.com/docs/guides/functions/background-tasks) | Deno adapter tested; Supabase Edge Runtime not tested |

The first five rows are the distinct entry-point fixtures. The following
rows check whether the resulting boundary stays convenient on related hosts.
Additional boundary samples: [Val Town](https://docs.val.town/vals/http) is
the small `Request → Response` case; [Wasmer WCGI](https://docs.wasmer.io/edge/learn/deployment-modes/)
uses a fresh instance per request with environment and stdin for input and
stdout for output. Neither of those two has a repository adapter yet.

The Lambda fixture is specifically a Function URL payload v2 event. API
Gateway HTTP API can use a related payload shape, but its mapping and path
semantics have not been checked here. The Discord handler currently does not
need an absolute URL or even a path: the adapter can route before passing
method, signature headers, and raw body bytes to the shared handler.

## What the current code establishes

`src/examples/interactions_js/handler.js` reads the request body as bytes and
verifies its Ed25519 signature before UTF-8 decoding or JSON parsing. The
native `endpoint_http` implementation follows the same order. The two are
separate implementations today. The JavaScript example now has
`handleRawInteraction`, which accepts exact bytes and the two signature header
values. The Lambda adapter can call it directly without synthesizing a Web
`Request`. This is an example-level seam, not yet a public MoonBit type. A
common library entry point should preserve the raw body and should not require
a host `Request` object.

The minimal *incoming Discord data* is method, the two signature headers, and
raw body bytes. Routing can stay with the host adapter. Host environment and
bindings should be resolved before constructing the Discord handler: the
Cloudflare `env` includes service capabilities, while the other hosts expose
configuration differently.

An immediate response cannot be restricted to one byte array without changing
existing behavior. `src/examples/interactions_js/worker.mbt` exposes a
`ReadableStream` for multipart attachments, and native `endpoint_http` writes
multipart chunks. A future common result needs to retain this body shape, or
explicitly document a buffering limit.

Background execution needs a result separate from the initial callback.
`start_interaction` currently exposes `response` and `background` promises.
An optional `wait_until(task)` method alone does not cover Fastly: its first
`event.waitUntil` call **must occur synchronously** in the fetch event callback.
The `fastly_echo` adapter therefore registers a lifetime promise before it
awaits request body reading, and attaches the eventual MoonBit background
promise to it. Lambda has no corresponding capability; its experiment waits
for background work before returning the envelope, so deferred commands can
miss Discord's initial-response deadline.

## API decision to make after host runs

Keep the transport input as raw bytes plus signature metadata. Keep the
initial response and background completion as separate results. Specify how
multipart output is represented. Let each adapter attach completion to its
host lifetime mechanism, including hosts that require synchronous
registration. Do not add generic environment lookup or Web `Request` to the
Discord core API. The exact public MoonBit types remain open until the Fastly
and WASI boundaries run with the shared `App`, rather than only their current
entry-point experiments.

Gateway hosting needs a separate fixture set. A WebSocket session has a
connection lifetime, Resume state, and ownership of background tasks; the
Interaction HTTP request shape does not model those. Compare Durable Objects,
Deno Deploy, bounded Functions, and a Linux process before choosing its public
adapter API.
