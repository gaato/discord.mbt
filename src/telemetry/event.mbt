///|
/// Structured, dependency-free operational events emitted by discord.mbt.
///
/// Callbacks receive these values synchronously and should return promptly.
pub(all) enum TelemetryEvent {
  ShardConnecting(shard_id~ : Int)
  ShardCompressionEnabled(shard_id~ : Int)
  ShardConnected(shard_id~ : Int)
  ShardDisconnected(shard_id~ : Int, code~ : Int?, will_resume~ : Bool)
  ShardHeartbeatLatency(shard_id~ : Int, latency_ms~ : Int64)
  ShardResumed(shard_id~ : Int)
  ShardIdentified(shard_id~ : Int)
  HttpRequest(
    route_bucket~ : String,
    method_name~ : String,
    status~ : Int,
    duration_ms~ : Int64,
    retries~ : Int
  )
  HttpRateLimited(
    route_bucket~ : String,
    global~ : Bool,
    retry_after_ms~ : Int64
  )
  EventDispatched(kind~ : String, handler_count~ : Int)
  DecodeError(marker~ : String)
} derive(Debug)
