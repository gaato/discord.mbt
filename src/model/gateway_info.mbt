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
} derive(ToJson, FromJson, Debug)
