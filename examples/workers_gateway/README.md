# Gateway bot in a Durable Object

This example runs one Discord Gateway shard in one Cloudflare Durable Object.
It handles `/ping` and keeps a `BotSession` snapshot so a restarted object can
resume event handling, including interactions replayed before RESUMED. Voice
connections are native-only and are not included.

## Build and deploy

From the repository root:

```sh
moon build --target js --release --deny-warn examples/workers_gateway
cd examples/workers_gateway
npm ci
npx wrangler secret put DISCORD_TOKEN
npx wrangler secret put CONTROL_TOKEN
npx wrangler deploy
```

Set `CONTROL_TOKEN` to an independent random value, never the Discord token.
The public `/start`, `/status`, and `/stop` routes require
`Authorization: Bearer <CONTROL_TOKEN>`; without that secret the Worker rejects
all controls. `/status` exposes only the enabled and running flags. For example:

```sh
export CONTROL_TOKEN='your-separate-control-token'
export WORKER_URL='https://your-worker.example'
curl -H "Authorization: Bearer $CONTROL_TOKEN" "$WORKER_URL/start"
curl -H "Authorization: Bearer $CONTROL_TOKEN" "$WORKER_URL/status"
curl -X POST -H "Authorization: Bearer $CONTROL_TOKEN" "$WORKER_URL/stop"
```

The bot uses no Gateway intents because slash commands do not need them. It
syncs `/ping` after an actual READY, using `sync_unowned=Keep` so commands
registered by other owners remain. RESUME does not repeat command sync. A
separate registration step, as in `workers_echo/register`, is another option.

## Lifecycle and limits

An alarm every 30 seconds stores the latest BotSession and restarts a failed
bot. The five-minute cron asks the object to reconcile its stored `enabled`
flag after eviction or deployment; it cannot re-enable an explicitly stopped
bot. `/stop` disables alarms and removes the saved session because its graceful
close code 1000 invalidates the Discord session. Restarted objects use the
saved Gateway sequence and READY identity to process replayed events. This
periodic snapshot does not guarantee exactly-once event handling or restore
application-owned state or optional cache contents. Each IDENTIFY first reads
Discord's session start limit, so a restart loop stops with
`SessionStartLimitExceeded` instead of exhausting the daily allowance.

[Cloudflare's lifecycle documentation](https://developers.cloudflare.com/durable-objects/concepts/durable-object-lifecycle/)
explains that outbound WebSockets prevent eviction for at most 15 minutes per
connection; the connection may continue operating afterward, but normal
eviction rules resume. Alarms and requests restart an evicted object. A live
connection incurs Durable Object duration charges. [Platform limits](https://developers.cloudflare.com/durable-objects/platform/limits/)
include a default 30-second CPU limit per event and a 32 MiB inbound WebSocket
message limit. [Workers WebSocket documentation](https://developers.cloudflare.com/workers/runtime-apis/websockets/)
describes the outbound client API. The example leaves zlib-stream Gateway
compression off.

## On Cloudflare

Deployed against Discord, the object kept its Gateway connection past the
15-minute eviction protection. After an eviction, the restarting alarm
resumed the stored session without a new IDENTIFY, and deploying a new Worker
version carried the session across in the same way. When Discord rejected a
RESUME, the shard identified again after reading the session start limit.

`wrangler tail` is misleading for a long-lived bot: alarm invocations report
about 30 seconds of wall time because log lines are attributed to the latest
invocation, an alarm in the same second as the cron reconcile ends as
`canceled`, and connection events arrive minutes late. The example enables
Workers Logs in `wrangler.toml`; read startup and reconnect telemetry there.

## Test locally

The local tests run inside workerd with fake WebSocket and REST endpoints. They
use no real credentials or Discord requests. They cover saved-session
restoration after a bot stops and starts again; object eviction is not
tested locally.

```sh
cd examples/workers_gateway
npm ci
env WRANGLER_SEND_METRICS=false npm test
npm run bundle:check -- --outdir /tmp/discord-mbt-workers-gateway
```

For a manual local run, add `DISCORD_TOKEN=...` and `CONTROL_TOKEN=...` to
`.dev.vars`, then run `npx wrangler dev --test-scheduled`. The scheduled
trigger is available at `/__scheduled` in that mode.
