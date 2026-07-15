# Scaling across processes

The native `gaato/discord/coordinator` package provides a small TCP service for
deployments that split Gateway shards between processes. It centralizes the
existing `InMemoryQueue` Identify buckets and `InMemoryRateLimiter` REST state;
no Redis or external database is required.

## Run the coordinator

Run exactly one coordinator for a logical bot deployment. Its task remains
owned by the supplied task group:

```moonbit
async fn main {
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

```moonbit
let identify = @coordinator.RemoteIdentifyQueue::connect("127.0.0.1:7600")
let limiter = @coordinator.RemoteRateLimiter::connect("127.0.0.1:7600")
defer identify.close()
defer limiter.close()

let client = @dhttp.Client(
  token,
  limiter=(limiter : &@ratelimit.RateLimiter),
)
defer client.close()

let bot = @discord.Bot(
  app,
  token~,
  client~,
  shards=Range(ids=[0, 1], count=8),
  identify_queue=(identify : &@queue.IdentifyQueue),
)
bot.run()
```

Give every process a non-overlapping shard range while keeping the same total
count. All workers that use the same bot token should also use the same
coordinator-backed REST limiter.

Connections are persistent and requests on one connection are ordered. A
disconnect raises `CoordinatorError`; version 1 does not reconnect
automatically, so recreate the remote client according to the application's
restart policy. If a process disconnects after acquiring a REST bucket, the
server releases that bucket during connection cleanup.

## Wire protocol

The TCP protocol is UTF-8 JSON Lines: one JSON object and one response per
line. A client sends only one in-flight request per connection.

| Request | Response behavior |
|---|---|
| `{"op":"ping"}` | Immediately returns `{"ok":true}`. |
| `{"op":"identify_acquire","shard_id":N}` | Returns success after the shard's Identify bucket and spacing permit it. |
| `{"op":"http_acquire","bucket":"...","global_exempt":false}` | Returns success when the REST request may start. |
| `{"op":"http_release","bucket":"...","status":N,"headers":{...}}` | Applies lowercase Discord rate-limit headers, releases the bucket, then returns success. |

Unknown or malformed operations return `{"ok":false,"error":"..."}`. The
server keeps the connection open after these protocol-level errors. Transport
failure closes the connection and is reported by the remote client.
