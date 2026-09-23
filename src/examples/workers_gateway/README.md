# Gateway bot in a Durable Object

This example runs one Discord Gateway shard in one Cloudflare Durable Object.
It handles `/ping` and keeps a `BotSession` snapshot so a restarted object can
resume event handling, including interactions replayed before RESUMED. Voice
connections are native-only and are not included.

## Build and deploy

From the repository root:

```fish
moon build --target js --release --deny-warn src/examples/workers_gateway
cd src/examples/workers_gateway
npm ci
npx wrangler secret put DISCORD_TOKEN
npx wrangler secret put CONTROL_TOKEN
npx wrangler deploy
```

Set `CONTROL_TOKEN` to an independent random value, never the Discord token.
The public `/start`, `/status`, and `/stop` routes require
`Authorization: Bearer <CONTROL_TOKEN>`; without that secret the Worker rejects
all controls. `/status` exposes only the enabled and running flags. For example:

```fish
set -x CONTROL_TOKEN 'your-separate-control-token'
set -x WORKER_URL 'https://your-worker.example'
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
describes the outbound client API. JavaScript does not support this library's
zlib-stream Gateway compression, so the example leaves it off.

## Verified deployment

This example was deployed to Cloudflare on 2026-09-23 with wrangler 4.136.3
and run against Discord for 20 minutes. Observed:

- `/start` opened the Gateway connection: Discord's `session_start_limit`
  dropped by one IDENTIFY, and the global `/ping` command appeared after READY.
- `/ping` from a Discord client returned `pong` twice, at 2 and 20 minutes
  after start. Both arrived as `INTERACTION_CREATE` over the WebSocket and
  were answered with a `204` interaction callback; the application had no
  interactions endpoint URL configured.
- The 30-second alarm fired 38 times with heartbeat latency logged at
  165–169 ms. The five-minute cron reconciled four times. No disconnect,
  resume, or exception was logged, and no second IDENTIFY was consumed, so the
  outbound connection outlived the 15-minute eviction protection window.

The object was then left running without log capture. Seventeen minutes
later `/status` reported `running: false, enabled: true`, and twelve seconds
after that `running: true`: the object had been evicted and the alarm had
restarted it. A new `wrangler tail` attached at that moment recorded the
restarting alarm invocation with `ShardConnecting`, `ShardResumed`, and
`ShardConnected` for shard 0 and no IDENTIFY, so the stored `BotSession`
resumed the Discord session.

The tail then ran for six more hours. The resumed session lasted 5 hours 17
minutes; at 21:56 Discord closed it, the RESUME attempt on the new connection
was rejected, and the shard identified again (`ShardDisconnected` with
`will_resume=true`, then `false`, then `ShardIdentified`, READY, and a second
command sync). `GET /gateway/bot` afterwards showed two IDENTIFYs consumed for
the day: the initial `/start` and this fallback. Heartbeat latency stayed at
162–173 ms across 679 alarms and 71 cron reconciles, with no exception.
Deploying a new Worker version moved the object to the new code within two
minutes; heartbeats continued without a further IDENTIFY, which only a
successful RESUME from the stored snapshot explains, although no telemetry
line for that restart appeared in the tail within 40 minutes.

Reading the tail needs two cautions. Every alarm invocation reports about 30
seconds of wall time because the bot's log lines are attributed to the most
recent invocation until the next event arrives, and an alarm that lands in
the same second as the cron reconcile ends with outcome `canceled`; neither
reflects work or failure. The records that carry connection events
(`ShardConnecting`, `ShardResumed`, `ShardIdentified`) arrived 20–40 minutes
after their timestamps, and the `/start` request that first started the bot
logged no READY line at all. Enable Workers Logs in `wrangler.toml` when you
need startup telemetry reliably.

## Test locally

The local tests run inside workerd with fake WebSocket and REST endpoints. They
use no real credentials or Discord requests. They cover saved-session
restoration after a bot stops and starts again. Live object eviction is
covered only by the deployment above; the local `evictDurableObject` helper
stalled subsequent requests even for an empty object in this test setup.

```fish
cd src/examples/workers_gateway
npm ci
env WRANGLER_SEND_METRICS=false npm test
npm run bundle:check -- --outdir /tmp/discord-mbt-workers-gateway
```

For a manual local run, add `DISCORD_TOKEN=...` and `CONTROL_TOKEN=...` to
`.dev.vars`, then run `npx wrangler dev --test-scheduled`. The scheduled
trigger is available at `/__scheduled` in that mode.
