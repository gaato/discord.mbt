///|
/// Live-API wire shapes observed 2026-07-16 that plain derive(FromJson)
/// mishandled: Int64 millisecond fields arrive as JSON numbers.
test "session start limit decodes numeric reset_after" {
  let raw =
    #|{"total": 1000, "remaining": 999, "reset_after": 14400000, "max_concurrency": 1}
  let json = @json.parse(raw)
  let limit : SessionStartLimit = @json.from_json(json)
  inspect(limit.reset_after, content="14400000")
}

///|
test "typing start decodes numeric timestamp" {
  let raw =
    #|{"channel_id": "1", "user_id": "2", "timestamp": 1752600000}
  let json = @json.parse(raw)
  let event : TypingStartEvent = @json.from_json(json)
  inspect(event.timestamp, content="1752600000")
}
