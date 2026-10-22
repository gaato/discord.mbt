///|
/// Response of `GET /gateway/bot`.
pub(all) struct GatewayBotInfo {
  url : String
  shards : Int32
  session_start_limit : SessionStartLimit
} derive(ToJson, FromJson, Debug)

///|
/// Identify session allowance: how many session starts remain in the current
/// window and how many shards may identify concurrently.
pub(all) struct SessionStartLimit {
  total : Int32
  remaining : Int32
  reset_after : Int64
  max_concurrency : Int32
} derive(ToJson, Debug)

///|
struct SessionStartLimitWire {
  total : Int32
  remaining : Int32
  reset_after : Double
  max_concurrency : Int32
} derive(FromJson)

///|
/// Decodes the session start limit from its Discord JSON representation.
pub impl @json.FromJson for SessionStartLimit with fn from_json(json, path) {
  let wire : SessionStartLimitWire = @json.from_json(json, path~)
  {
    total: wire.total,
    remaining: wire.remaining,
    reset_after: wire.reset_after.to_int64(),
    max_concurrency: wire.max_concurrency,
  }
}
