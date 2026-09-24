///|
/// The contracts the send loop keeps now that `gaato/sdk-runtime` runs it:
/// Discord's retry rule, where a 429's delay and scope come from, how limiter
/// and deadline failures surface, and the wire shape of uploads.

///|
async test "a 429 that outlives its retries raises RateLimited with the body delay" {
  let attempts = Ref(0)
  let client = wire_test_client(
    (_path, _headers, _body) => {
      attempts.val += 1
      {
        status: 429,
        headers: { "x-ratelimit-global": "true", "retry-after": "2" },
        body: { "retry_after": 1.5, "global": true },
      }
    },
    max_retries=0,
  )
  defer client.close()
  try client.request(GetGateway) catch {
    RateLimited(retry_after_ms~, global~) => {
      // The body's fractional seconds win over the header's whole seconds.
      inspect(retry_after_ms, content="1500")
      assert_true(global)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected RateLimited")
  }
  inspect(attempts.val, content="1")
}

///|
async test "a 429 without a body delay waits for the Retry-After header" {
  let attempts = Ref(0)
  let client = wire_test_client(
    (_path, _headers, _body) => {
      attempts.val += 1
      if attempts.val == 1 {
        { status: 429, headers: { "retry-after": "0.02" }, body: {}, }
      } else {
        { status: 200, headers: Map([]), body: { "ok": true }, }
      }
    },
    max_retries=1,
  )
  defer client.close()
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  json_inspect(client.request(GetGateway), content={ "ok": true })
  inspect(attempts.val, content="2")
  guard events
    is [
      HttpRequest(status=429, retries=0, method_name="Get", ..),
      HttpRateLimited(global=false, retry_after_ms=20L, ..),
      HttpRequest(status=200, retries=1, ..),
    ] else {
    fail("unexpected telemetry: \{Repr(events)}")
  }
}

///|
async test "a 429 with neither a body delay nor a header waits one second" {
  let client = wire_test_client(
    (_path, _headers, _body) => {
      status: 429,
      headers: Map([]),
      body: "slow down",
    },
    max_retries=0,
  )
  defer client.close()
  try client.request(GetGateway) catch {
    RateLimited(retry_after_ms~, global~) => {
      inspect(retry_after_ms, content="1000")
      assert_false(global)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected RateLimited")
  }
}

///|
async test "an offline 429 without a delay reports one second at once" {
  let client = Client::offline(_ => {
    status: 429,
    headers: Map([]),
    body: Json::null(),
  })
  try client.request(GetGateway) catch {
    RateLimited(retry_after_ms~, global~) => {
      inspect(retry_after_ms, content="1000")
      assert_false(global)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected RateLimited")
  }
}

///|
priv suberror ReleaseRejected derive(Debug)

///|
/// A limiter whose release fails, as a coordinator does for an unknown lease.
priv struct RejectingLimiter {
  mut released : Int
}

///|
impl @runtime.RateLimiter for RejectingLimiter with fn acquire(
  _self,
  _bucket,
  global_exempt~,
) {
  ignore(global_exempt)
}

///|
impl @runtime.RateLimiter for RejectingLimiter with fn release(
  self,
  _bucket,
  status~,
  headers~,
) {
  ignore(status)
  ignore(headers)
  self.released += 1
  raise ReleaseRejected
}

///|
async test "a rate limiter whose release fails surfaces as a transport error" {
  let limiter = RejectingLimiter::{ released: 0, }
  let client = wire_test_client(
    (_path, _headers, _body) => {
      status: 200,
      headers: Map([]),
      body: { "ok": true },
    },
    limiter~,
  )
  defer client.close()
  try client.request(GetGateway) catch {
    Transport(message~) => {
      assert_true(message.contains("rate limiter release failed"))
      assert_true(message.contains("ReleaseRejected"))
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the release failure")
  }
  inspect(limiter.released, content="1")
}

///|
async test "files upload as payload_json then files[n] on the wire" {
  let captured_type = Ref("")
  let captured_body = Ref("")
  let client = wire_test_client((path, headers, body) => {
    assert_eq(path, "/api/v10/channels/7/messages")
    captured_type.val = headers.get_or_default("content-type", "")
    guard body is Some(String(text)) else { fail("expected a multipart body") }
    captured_body.val = text
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  defer client.close()
  let channel_id : @model.ChannelId = Id(7UL)
  try
    client.create_message(channel_id, content="see file", files=[
      FileUpload("note.txt", b"hello", content_type="text/plain"),
    ])
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  assert_true(
    captured_type.val.has_prefix("multipart/form-data; boundary=mbt-sdk-"),
  )
  let body = captured_body.val
  let payload = body.find("name=\"payload_json\"").unwrap_or(-1)
  let file = body.find("name=\"files[0]\"; filename=\"note.txt\"").unwrap_or(-1)
  assert_true(payload >= 0 && file > payload)
  assert_true(
    body.contains("\"attachments\":[{\"id\":0,\"filename\":\"note.txt\"}]"),
  )
  assert_true(body.contains("Content-Type: text/plain\r\n\r\nhello\r\n"))
}

///|
/// A transport that fails or stalls in a chosen way on both methods.
priv struct ScriptedFailure {
  fail_with : @ghttp.HttpError?
}

///|
impl @ghttp.Transport for ScriptedFailure with fn send(self, _request) {
  match self.fail_with {
    Some(error) => raise error
    None => {
      @async.sleep(60000)
      { status: 200, headers: @ghttp.Headers::new(), body: b"", }
    }
  }
}

///|
impl @ghttp.Transport for ScriptedFailure with fn send_stream(self, request) {
  ignore(@ghttp.Transport::send(self, request))
  raise @ghttp.HttpError::Protocol("unreachable")
}

///|
async test "a supplied transport keeps its errors and gets the attempt deadline" {
  let request = @ghttp.Request::get("https://discord.com/api/v10/gateway")
  for
    error in [
      @ghttp.HttpError::Connect("refused"),
      @ghttp.HttpError::Protocol("garbled"),
    ] {
    let transport = TimeoutTransport::{
      inner: ScriptedFailure::{ fail_with: Some(error), },
      timeout_ms: 1000,
    }
    for streaming in [false, true] {
      let raised = try {
        if streaming {
          ignore(@ghttp.Transport::send_stream(transport, request))
        } else {
          ignore(@ghttp.Transport::send(transport, request))
        }
        "no error"
      } catch {
        raised => @debug.to_string(raised)
      }
      assert_eq(raised, @debug.to_string(error))
    }
  }
  let stalled = TimeoutTransport::{
    inner: ScriptedFailure::{ fail_with: None, },
    timeout_ms: 10,
  }
  for streaming in [false, true] {
    try {
      if streaming {
        ignore(@ghttp.Transport::send_stream(stalled, request))
      } else {
        ignore(@ghttp.Transport::send(stalled, request))
      }
    } catch {
      @ghttp.HttpError::Timeout(ms) => inspect(ms, content="10")
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected the deadline")
    }
  }
}

///|
test "wire methods and their telemetry names" {
  let methods : Array[@ahttp.RequestMethod] = [
    Get,
    Head,
    Post,
    Put,
    Delete,
    Connect,
    Options,
    Trace,
    Patch,
  ]
  inspect(
    methods.map(wire_method).join(" "),
    content="GET HEAD POST PUT DELETE CONNECT OPTIONS TRACE PATCH",
  )
  // Online telemetry names a method the way the offline path always has.
  for verb in methods {
    assert_eq(method_name(wire_method(verb)), @debug.to_string(verb))
  }
  inspect(method_name(""), content="")
}

///|
async test "an upload's multipart body is joined only once the limiter admits it" {
  let client = wire_test_client((_path, _headers, _body) => {
    status: 200,
    headers: Map([]),
    body: {},
  })
  defer client.close()
  let channel_id : @model.ChannelId = Id(100UL)
  let wire = client.wire_request({
    route: CreateMessage(channel_id~),
    body: Some({ "content": "hi" }),
    audit_reason: None,
    files: Some([FileUpload("a.txt", b"hello")]),
    headers: Map([]),
  })
  // The head goes to the limiter queue without the encoded body.
  assert_true(wire.head.body.is_empty())
  guard wire.head.headers.get("content-type") is Some(content_type) &&
    content_type.has_prefix("multipart/form-data; boundary=") else {
    fail("expected a multipart content-type")
  }
  guard wire.body is Some(build) else { fail("expected a deferred body") }
  let body = @utf8.decode_lossy(build())
  assert_true(body.contains("name=\"payload_json\""))
  assert_true(body.contains("hello"))
}
