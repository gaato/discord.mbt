///|
fn identify_os() -> String {
  "javascript"
}

///|
/// The close code for an oversized message. The WebSocket API can send only
/// 1000 and 3000-4999, so JavaScript uses the shard's resumable close.
const OVERSIZED_CLOSE_CODE : Int32 = RESUMABLE_CLOSE_CODE
