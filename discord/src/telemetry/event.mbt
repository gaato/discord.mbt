///|
/// Structured, dependency-free operational events emitted by discord.mbt.
///
/// Callbacks receive these values synchronously and should return promptly.
#non_exhaustive
pub(all) enum TelemetryEvent {
  ShardConnecting(shard_id~ : Int32)
  ShardCompressionEnabled(shard_id~ : Int32)
  ShardConnected(shard_id~ : Int32)
  ShardDisconnected(shard_id~ : Int32, code~ : Int32?, will_resume~ : Bool)
  ShardHeartbeatLatency(shard_id~ : Int32, latency_ms~ : Int64)
  ShardResumed(shard_id~ : Int32)
  ShardIdentified(shard_id~ : Int32)
  HttpRequest(
    route_bucket~ : String,
    method_name~ : String,
    status~ : Int32,
    duration_ms~ : Int64,
    retries~ : Int32
  )
  HttpRateLimited(
    route_bucket~ : String,
    global~ : Bool,
    retry_after_ms~ : Int64
  )
  EventDispatched(kind~ : String, handler_count~ : Int32)
  /// A gateway event was not handed to event handlers because `backlog`
  /// events were already waiting (see `BotBuilder`'s `event_backlog`). Cache
  /// updates and interaction routing had already run for it.
  EventDropped(kind~ : String, backlog~ : Int32)
  /// A gateway event was not handed to event handlers because the bot's
  /// shutdown was requested first (see `GatewayCtx::shutdown`): it was still
  /// waiting in the backlog, arrived later, or left event middleware after
  /// the request. Cache updates and interaction routing had already run for
  /// it.
  EventDiscarded(kind~ : String)
  DecodeError(marker~ : String)
} derive(Debug)
