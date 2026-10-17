///|
/// RFC 8032 test vector 1, signing at a fixed timestamp.
fn http_signed_request(body : Bytes) -> InteractionHttpRequest raise {
  let seed = @hex.decode(
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
  )
  {
    http_method: "POST",
    signature: Some(
      @hex.encode(@ed25519.sign(seed, @utf8.encode("1720951200") + body)),
    ),
    timestamp: Some("1720951200"),
    body,
  }
}

///|
fn http_text(response : InteractionHttpResponse) -> (Int32, String?, String) {
  let text = match response.body {
    Bytes(bytes) => @utf8.decode_lossy(bytes)
    Empty => "<empty>"
    Chunks(_) => "<chunks>"
  }
  (response.status, response.content_type, text)
}

///|
test "signed requests are refused before decoding unless verified and valid" {
  let verifier = @verify.InteractionVerifier::new(
    "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
  )
  let ping = http_signed_request(
    @utf8.encode(
      (
        #|{"id":"500000000000000100","application_id":"400000000000000001","type":1,"token":"interaction-token","version":1}
      ),
    ),
  )
  let text = Some("text/plain; charset=utf-8")
  for
    row in [
      (
        { ..ping, http_method: "GET", signature: None, },
        405,
        "method not allowed",
      ),
      ({ ..ping, signature: None, }, 401, "missing signature"),
      ({ ..ping, timestamp: None, }, 401, "missing signature"),
      ({ ..ping, body: ping.body + b" ", }, 401, "invalid signature"),
      (http_signed_request(b"\xff"), 400, "invalid UTF-8 body"),
      (http_signed_request(b"null"), 400, "invalid interaction JSON"),
    ] {
    let (request, status, message) = row
    guard decode_signed_request(request, verifier) is Err(refusal) else {
      fail("expected \{status} \{message}")
    }
    assert_eq(http_text(refusal), (status, text, message))
  }
  guard decode_signed_request(ping, verifier) is Ok(interaction) else {
    fail("expected the signed PING to decode")
  }
  assert_true(interaction.typ is Ping)
}

///|
test "dispatch outcomes map to HTTP responses" {
  let pong : @model.InteractionResponse = { typ: Pong, data: None, }
  let text = Some("text/plain; charset=utf-8")
  for
    row in [
      (
        InteractionOutcome::Reply(response=pong, files=None),
        (200, Some("application/json"), "{\"type\":1}"),
      ),
      (NoRoute, (404, text, "not found")),
      (NoResponse, (202, None, "<empty>")),
      (TimedOut, (504, text, "initial response timed out")),
    ] {
    let (outcome, expected) = row
    assert_eq(http_text(outcome_http_response(outcome)), expected)
  }
  let upload = outcome_http_response(
    Reply(response=pong, files=Some([@dhttp.FileUpload("a.txt", b"hi")])),
  )
  assert_eq(upload.status, 200)
  assert_true(
    upload.content_type is Some(content_type) &&
    content_type.has_prefix("multipart/form-data; boundary="),
  )
  assert_true(upload.body is Chunks(_))
}
