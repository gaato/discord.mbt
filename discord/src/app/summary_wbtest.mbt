///|
test "error response summaries name every payload combination" {
  inspect(
    error_response_summary(Some("boom"), None, None, None),
    content="boom",
  )
  inspect(
    error_response_summary(None, None, None, None),
    content="empty error response",
  )
  inspect(
    error_response_summary(None, Some([]), None, None),
    content="embeds-only error response",
  )
  inspect(
    error_response_summary(None, None, Some([]), None),
    content="components-only error response",
  )
  inspect(
    error_response_summary(None, None, None, Some([])),
    content="files-only error response",
  )
  inspect(
    error_response_summary(None, Some([]), Some([]), Some([])),
    content="embeds+components+files error response",
  )
}
