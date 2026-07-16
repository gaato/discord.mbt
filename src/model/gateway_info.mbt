///|
/// Response of `GET /gateway/bot`.
pub(all) struct GatewayBotInfo {
  url : String
  shards : Int
  session_start_limit : SessionStartLimit
} derive(ToJson, FromJson, Debug)

///|
/// Identify session allowance: how many session starts remain in the current
/// window and how many shards may identify concurrently.
pub(all) struct SessionStartLimit {
  total : Int
  remaining : Int
  reset_after : Int64
  max_concurrency : Int
} derive(ToJson, Debug)

///|
struct SessionStartLimitWire {
  total : Int
  remaining : Int
  reset_after : Double
  max_concurrency : Int
} derive(FromJson)

///|
pub impl @json.FromJson for SessionStartLimit with fn from_json(json, path) {
  let wire : SessionStartLimitWire = @json.from_json(json, path~)
  {
    total: wire.total,
    remaining: wire.remaining,
    reset_after: wire.reset_after.to_int64(),
    max_concurrency: wire.max_concurrency,
  }
}
