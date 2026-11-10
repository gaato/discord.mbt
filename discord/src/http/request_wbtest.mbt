///|
fn headers_of(pairs : Array[(String, String)]) -> @ghttp.Headers {
  @ghttp.Headers::of(pairs)
}

///|
test "rate_limit_from_json prefers the body, then the headers, then one second" {
  let cases : Array[(Array[(String, String)], Json, (Int64, Bool))] = [
    ([("retry-after", "2")], { "retry_after": 1.5 }, (1500L, false)),
    ([("retry-after", "0.02")], {}, (20L, false)),
    ([("retry-after-ms", "250")], {}, (250L, false)),
    ([("retry-after-ms", "250"), ("retry-after", "3")], {}, (250L, false)),
    ([], {}, (1000L, false)),
    ([], Json::string("<html>"), (1000L, false)),
    ([("retry-after", "3")], { "retry_after": "x" }, (3000L, false)),
    ([("x-ratelimit-global", "true")], { "retry_after": 1 }, (1000L, true)),
    // only the header marks a global limit
    ([], { "retry_after": 1, "global": true }, (1000L, false)),
  ]
  for case in cases {
    let (pairs, body, expected) = case
    assert_eq(rate_limit_from_json(headers_of(pairs), body), expected)
  }
}

///|
test "rate_limit_details reads a body that is not JSON as no body" {
  assert_eq(
    rate_limit_details(
      headers_of([("retry-after", "1")]),
      @utf8.encode("<html>"),
    ),
    (1000L, false),
  )
  assert_eq(
    rate_limit_details(headers_of([]), @utf8.encode("{\"retry_after\":0.25}")),
    (250L, false),
  )
}

///|
/// The message `validate_request` rejects a request with, or `None`.
fn validation_failure(
  route : Route,
  files : Array[FileUpload]?,
  body : Json?,
  audit_reason? : String,
) -> String? raise {
  let request = HttpRequest::{
    route,
    body,
    audit_reason,
    files,
    headers: Map([]),
  }
  try validate_request(request) catch {
    Validation(message~) => Some(message)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => None
  }
}

///|
test "validate_request enforces the fixed upload shapes" {
  let file = FileUpload("a.png", b"x")
  let sticker_fields : Json = { "name": "n", "description": "d", "tags": "t" }
  let sticker = CreateGuildSticker(guild_id=Id(1UL))
  let target_users = UpdateInviteTargetUsers(code="abc")
  let invite = CreateChannelInvite(channel_id=Id(2UL))
  let sticker_shape = "create guild sticker requires exactly one file and form fields"
  let target_users_shape = "update invite target users requires exactly one file and no JSON body"
  let invite_shape = "create channel invite accepts exactly one target-users file next to its JSON params"
  let cases : Array[(Route, Array[FileUpload]?, Json?, String?)] = [
    (sticker, None, Some(sticker_fields), Some(sticker_shape)),
    (sticker, Some([file, file]), Some(sticker_fields), Some(sticker_shape)),
    (sticker, Some([file]), None, Some(sticker_shape)),
    (
      sticker,
      Some([file]),
      Some({ "name": 1 }),
      Some("sticker form field name must be a string"),
    ),
    (sticker, Some([file]), Some(sticker_fields), None),
    (target_users, Some([file]), Some({}), Some(target_users_shape)),
    (target_users, None, None, Some(target_users_shape)),
    (target_users, Some([file]), None, None),
    (invite, Some([]), Some({}), Some(invite_shape)),
    (invite, Some([file, file]), Some({}), Some(invite_shape)),
    (invite, Some([file]), None, Some(invite_shape)),
    (invite, None, Some({}), None),
    (invite, None, None, None),
    (invite, Some([file]), Some({}), None),
    (GetGateway, Some([file, file]), None, None),
  ]
  for case in cases {
    let (route, files, body, expected) = case
    assert_eq(validation_failure(route, files, body), expected)
  }
}

///|
test "validate_request checks file names, then the audit reason, then the shape" {
  let length = Some("audit_reason must be between 1 and 512 characters")
  assert_eq(validation_failure(GetGateway, None, None, audit_reason=""), length)
  assert_eq(
    validation_failure(GetGateway, None, None, audit_reason="x".repeat(513)),
    length,
  )
  assert_eq(
    validation_failure(GetGateway, None, None, audit_reason="x".repeat(512)),
    None,
  )
  assert_eq(
    validation_failure(
      CreateGuildSticker(guild_id=Id(1UL)),
      Some([FileUpload("a\nb.png", b"x")]),
      None,
      audit_reason="",
    ),
    Some("filename must not contain CR, LF, or double quotes"),
  )
  assert_eq(
    validation_failure(
      CreateGuildSticker(guild_id=Id(1UL)),
      None,
      None,
      audit_reason="",
    ),
    length,
  )
}

///|
test "api_error_of decodes Discord errors and keeps any other body verbatim" {
  let error_of = (status : Int32, body : Json) => {
    api_error_of({ status, headers: Map([]), body, })
  }
  let decoded = error_of(404, { "code": 10003, "message": "Unknown" })
  assert_eq(decoded.code, 10003)
  assert_eq(decoded.message, "Unknown")
  assert_true(decoded.errors is None)
  let cases : Array[(Int32, Json, String)] = [
    (502, Json::string("<html>"), "HTTP 502: <html>"),
    (400, Json::null(), "HTTP 400: null"),
    // without a code the body is not an ApiError
    (400, { "message": "x" }, "HTTP 400: {\"message\":\"x\"}"),
  ]
  for case in cases {
    let (status, body, message) = case
    let error = error_of(status, body)
    assert_eq(error.code, 0)
    assert_eq(error.message, message)
    assert_true(error.errors is None)
  }
}

///|
test "the closed gate's refusal is reported as the client's closure" {
  let closed = @ghttp.TransportError(
    kind=Closed,
    phase=Pool,
    detail=CLOSED_MESSAGE,
  )
  assert_eq(
    Repr(transport_failure(closed)).to_string(),
    "Transport(phase=Pool, message=\"client is closed\")",
  )
  let refused = @ghttp.TransportError(
    kind=Connect,
    phase=Dial,
    detail="refused",
  )
  assert_eq(
    Repr(transport_failure(refused)).to_string(),
    "Transport(phase=Dial, message=\"could not connect: refused\")",
  )
}

///|
test "settle_response_failure turns a status into a response and raises decoding and rate limits" {
  let cases : Array[(@runtime.ResponseFailure, String)] = [
    (
      @runtime.UnexpectedStatus(
        { status: 404, headers: @ghttp.Headers::empty(), },
        body=b"{\"code\":10003}",
      ),
      "status 404 {\"code\":10003}",
    ),
    (
      @runtime.UnexpectedStatus(
        {
          status: 429,
          headers: @ghttp.Headers::of([
            ("retry-after", "2"),
            ("x-ratelimit-global", "true"),
          ]),
        },
        body=b"",
      ),
      "raise RateLimited(retry_after_ms=2000, global=true)",
    ),
    (
      @runtime.Deserialization(
        { status: 200, headers: @ghttp.Headers::empty(), },
        message="bad json",
        body=b"{",
      ),
      "raise Deserialize(message=\"bad json\")",
    ),
  ]
  for (error, expected) in cases {
    let actual = try settle_response_failure(error) catch {
      error => "raise \{Repr(error)}"
    } noraise {
      response => "status \{response.status} \{response.body.stringify()}"
    }
    assert_eq(actual, expected)
  }
}
