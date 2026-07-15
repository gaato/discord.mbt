///|
/// Verify Discord HTTP interaction signatures with libcrypto Ed25519.
pub using @verify {verify_signature}

///|
/// Native Discord Gateway transport primitives.
pub using @gateway {type Shard, type ShardEvent}

///|
/// Native cross-process Identify and REST rate-limit coordination.
pub using @coordinator {
  type Coordinator,
  type CoordinatorError,
  type RemoteIdentifyQueue,
  type RemoteRateLimiter,
}

///|
/// Native gateway executor and typed event descriptors.
pub using @bot {
  type Bot,
  type GatewayCtx,
  type EventType,
  type Events,
  type BotError,
  type ShardConfig,
}
