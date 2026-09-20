# Scaling across processes

The native `gaato/discord/coordinator` package provides a small TCP service for
deployments that split Gateway shards between processes. It centralizes the
existing `InMemoryQueue` Identify buckets, `InMemoryRateLimiter` REST state,
and `InMemoryCooldownStore` command windows;
no Redis or external database is required.

## Run the coordinator

Run exactly one coordinator for a logical bot deployment. Its task remains
owned by the supplied task group. In the coordinator executable this body is
`async fn main`:

```mbt check
///|
async fn run_coordinator() -> Unit {
  @async.with_task_group(group => {
    let coordinator = @coordinator.Coordinator::serve(
      group,
      addr="127.0.0.1:7600",
      max_concurrency=2,
    )
    println("coordinator listening on \{coordinator.addr()}")
  })
}
```

Set `max_concurrency` to the value returned by Discord's `GET /gateway/bot`.
The default Identify spacing is 5250 ms. The default global REST limit is 50
requests per second.

The protocol has no authentication or encryption. Bind to loopback when all
workers share a host; otherwise place it on a trusted private network or behind
an authenticated tunnel.

## Connect workers

Each worker creates remote implementations and injects them into the existing
Bot and HTTP Client seams:

```mbt check
///|
async fn run_worker(app : @discord.App, token : String) -> Unit {
  let identify = @coordinator.RemoteIdentifyQueue::connect("127.0.0.1:7600")
  let limiter = @coordinator.RemoteRateLimiter::connect("127.0.0.1:7600")
  defer identify.close()
  defer limiter.close()
  let client = @dhttp.Client(token, limiter=(limiter : &@ratelimit.RateLimiter))
  defer client.close()
  let bot = @discord.Bot(
    app,
    token~,
    client~,
    shards=Range(ids=[0, 1], count=8),
    identify_queue=(identify : &@queue.IdentifyQueue),
  )
  bot.run()
}

///|
test "coordinator declarations compile" {
  ignore(run_coordinator)
  ignore(run_worker)
}
```

Give every process a non-overlapping shard range while keeping the same total
count. All workers that use the same bot token should also use the same
coordinator-backed REST limiter.

Connections are persistent and requests on one connection are ordered. After
a transport failure, Identify and REST requests reconnect with bounded exponential
backoff. Protocol errors from the server remain fatal and are not retried. If
a process disconnects after acquiring a REST bucket, the server releases that
bucket during connection cleanup.

## Shared cooldowns

`App()` creates a fresh `InMemoryCooldownStore`. To enforce the same command
cooldown across processes, inject a shared store into **every process that
serves interactions**, including HTTP interaction workers:

```mbt check
///|
async test "shared cooldown store wiring" {
  @async.with_task_group(group => {
    let coordinator = @coordinator.Coordinator::serve(group, addr="127.0.0.1:0")
    defer coordinator.close()
    let cooldown = @coordinator.RemoteCooldownStore::connect(
      coordinator.addr(),
      timeout_ms=1000,
      on_error=error => println("cooldown coordinator: \{error}"),
    )
    defer cooldown.close()
    let app = @app.App(cooldown_store=(cooldown : &@cooldown.CooldownStore))
    app.command(
      @app.slash(
        name="limited",
        description="Shared cooldown",
        args=@interaction.Args::unit(),
        handler=Raw(_ => ()),
      ).cooldown(seconds=10, bucket=User),
    )
    app.validate()
    cooldown.ping()
  })
}
```

Use the coordinator's configured address in each worker and keep the remote
store alive for the lifetime of its App. Keys include command type, command
name, and bucket identity, so commands sharing a store have independent
windows. The coordinator owns the clock and keeps windows in memory; restarting
it clears those windows.

The `gaato/discord/cooldown` trait is portable to JS and native, while
`RemoteCooldownStore` is native-only. Other deployments can implement
`CooldownStore` over shared storage and pass it through the same App parameter.

The remote store defaults to `when_unreachable=FailOpen`. A timeout or disconnect
calls `on_error` and admits the command: cooldowns damp abuse, and an outage
should not take every command offline. Use `when_unreachable=FailClosed` to deny the
attempt with `retry_after_ms` equal to the requested window instead. The
default error hook does nothing, so install it to observe outages. Initial
connection outages also call the hook and return a store that can reconnect.
Cancellation always propagates, as do protocol errors. `ping()` reports errors
directly instead of applying the admission policy.

Each cooldown store has its own connection, independent of blocking
`http_acquire` requests. Acquisition makes one attempt with no retries;
`timeout_ms` (default 1000) bounds the entire operation, including connection
queueing and reconnect time. This work runs before the handler can defer and
spends Discord's three-second initial-response budget. Identify and REST retain
their existing retry policy; `RemoteRateLimiter` remains fail-closed because
avoiding Discord's 429 bans is a correctness concern.

## Wire protocol

The TCP protocol is UTF-8 JSON Lines: one JSON object and one response per
line. A client sends only one in-flight request per connection.

| Request | Response behavior |
|---|---|
| `{"op":"ping"}` | Immediately returns `{"ok":true}`. |
| `{"op":"identify_acquire","shard_id":N}` | Returns success after the shard's Identify bucket and spacing permit it. |
| `{"op":"http_acquire","bucket":"...","global_exempt":false}` | Returns success when the REST request may start. |
| `{"op":"http_release","bucket":"...","status":N,"headers":{...}}` | Applies lowercase Discord rate-limit headers, releases the bucket, then returns success. |
| `{"op":"cooldown_acquire","key":"...","window_ms":"10000"}` | Immediately returns `{"ok":true,"retry_after_ms":"0"}` when acquired, or the remaining window in milliseconds. |

Cooldown `window_ms` and `retry_after_ms` are decimal strings, preserving Int64
precision through JSON. `"0"` means acquired. Other operations retain their
existing numeric fields.

Unknown or malformed operations return `{"ok":false,"error":"..."}`. The
server keeps the connection open after these protocol-level errors. Transport
failures close the connection. Identify and REST use bounded retries; cooldown
acquisition applies its unreachable policy and tries to reconnect on the next call.
