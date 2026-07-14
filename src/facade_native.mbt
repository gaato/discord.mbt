///|
/// Native Discord Gateway transport primitives.
pub using @gateway {type Shard, type ShardEvent}

///|
/// Native gateway executor and typed event descriptors.
pub using @bot {
  type Bot,
  type GatewayCtx,
  type EventType,
  type Events,
  type BotError,
}
