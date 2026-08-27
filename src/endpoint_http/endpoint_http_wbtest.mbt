///|
fn hex_nibble(code : UInt16) -> Byte? {
  if code >= '0' && code <= '9' {
    Some((code - '0').to_byte())
  } else if code >= 'a' && code <= 'f' {
    Some((code - 'a' + 10).to_byte())
  } else {
    None
  }
}

///|
fn decode_hex(input : String) -> Bytes? {
  guard input.length() % 2 == 0 else { return None }
  let decoded = Array::make(input.length() / 2, b'\x00')
  for i in 0..<decoded.length() {
    guard hex_nibble(input[i * 2]) is Some(high) else { return None }
    guard hex_nibble(input[i * 2 + 1]) is Some(low) else { return None }
    decoded[i] = (high << 4) | low
  }
  Some(Bytes::from_array(decoded))
}

///|
fn encode_hex(bytes : Bytes) -> String {
  let out = StringBuilder()
  for byte in bytes {
    out.write_string(byte.to_hex())
  }
  out.to_string()
}

///|
fn sign_body(
  private_seed : Bytes,
  timestamp : String,
  body : String,
) -> String raise {
  encode_hex(@ed25519.sign(private_seed, @utf8.encode(timestamp + body)))
}

///|
fn signed_headers(
  private_seed : Bytes,
  timestamp : String,
  body : String,
) -> Map[String, String] raise {
  {
    "X-Signature-Ed25519": sign_body(private_seed, timestamp, body),
    "X-Signature-Timestamp": timestamp,
  }
}

///|
fn signed_headers_bytes(
  private_seed : Bytes,
  timestamp : String,
  body : Bytes,
) -> Map[String, String] raise {
  {
    "X-Signature-Ed25519": encode_hex(
      @ed25519.sign(private_seed, @utf8.encode(timestamp) + body),
    ),
    "X-Signature-Timestamp": timestamp,
  }
}

///|
fn to_async_headers(headers : Map[String, String]) -> @ahttp.Headers {
  let converted : @ahttp.Headers = Map([])
  for name, value in headers {
    converted[name] = value
  }
  converted
}

///|
async fn http_request(
  addr : String,
  meth : @ahttp.RequestMethod,
  path : String,
  body : String,
  headers : Map[String, String],
) -> (@ahttp.Response, String) {
  let client = @ahttp.Client("http://\{addr}")
  defer client.close()
  client.request(meth, path, extra_headers=to_async_headers(headers))
  if meth is Post {
    @io.Writer::write(client, body)
  }
  let response = client.end_request()
  (response, client.read_all().text())
}

///|
async fn http_request_bytes(
  addr : String,
  path : String,
  body : Bytes,
  headers : Map[String, String],
) -> (@ahttp.Response, String) {
  let client = @ahttp.Client("http://\{addr}")
  defer client.close()
  client.request(Post, path, extra_headers=to_async_headers(headers))
  @io.Writer::write(client, body)
  let response = client.end_request()
  (response, client.read_all().text())
}

///|
fn ping_body() -> String {
  (
    #|{"id":"500000000000000100","application_id":"400000000000000001","type":1,"token":"interaction-token","version":1}
  )
}

///|
fn command_body(name : String, text : String, id : String) -> String {
  (
    #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"data":{"id":"600000000000000100","name":"COMMAND_NAME","type":1,"options":[{"name":"text","type":3,"value":"COMMAND_TEXT"}]}}
  )
  .replace(old="INTERACTION_ID", new=id)
  .replace(old="COMMAND_NAME", new=name)
  .replace(old="COMMAND_TEXT", new=text)
}

///|
async test "native interactions server authenticates and dispatches HTTP requests" {
  guard decode_hex(
      "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
    )
    is Some(private_seed) else {
    fail("invalid RFC 8032 private key fixture")
  }
  let public_key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let timestamp = "1720951200"
  let app = @app.App(sync=Disabled)
  app.command(
    @app.slash(
      name="echo",
      description="Echo text",
      args=@interaction.Args::of(
        @interaction.arg_string(name="text", description="What to echo"),
      ),
      handler=Immediate((_, text) => @app.CommandReply::message(content=text)),
    ),
  )
  app.command(
    @app.slash(
      name="attach",
      description="Reply with a file",
      args=@interaction.Args::of(
        @interaction.arg_string(name="text", description="Ignored"),
      ),
      handler=Immediate((_, _text) => {
        @app.CommandReply::message(content="here is your file", files=[
          FileUpload(
            "hello.txt",
            b"hello file contents",
            content_type="text/plain",
          ),
        ])
      }),
    ),
  )
  let discord_client = @dhttp.Client("test-token")
  defer discord_client.close()
  @async.with_task_group(group => {
    let server = serve_interactions(
      group,
      app,
      addr="127.0.0.1:0",
      public_key~,
      client=discord_client,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
      path="/interactions",
    )
    defer server.close()

    let ping = ping_body()
    let (ping_response, ping_result) = http_request(
      server.addr(),
      Post,
      "/interactions",
      ping,
      signed_headers(private_seed, timestamp, ping),
    )
    assert_eq(ping_response.code, 200)
    assert_eq(ping_result, "{\"type\":1}")

    let command = command_body("echo", "hello", "500000000000000101")
    let (command_response, command_result) = http_request(
      server.addr(),
      Post,
      "/interactions",
      command,
      signed_headers(private_seed, timestamp, command),
    )
    assert_eq(command_response.code, 200)
    assert_eq(command_result, "{\"type\":4,\"data\":{\"content\":\"hello\"}}")

    let bad_headers = signed_headers(private_seed, timestamp, ping)
    let valid_signature = bad_headers["X-Signature-Ed25519"]
    let flipped_nibble = if valid_signature[0] == '0' { "1" } else { "0" }
    bad_headers["X-Signature-Ed25519"] = flipped_nibble +
      valid_signature[1:].to_owned()
    let (bad_signature, _) = http_request(
      server.addr(),
      Post,
      "/interactions",
      ping,
      bad_headers,
    )
    assert_eq(bad_signature.code, 401)

    let (missing_signature, _) = http_request(
      server.addr(),
      Post,
      "/interactions",
      ping,
      Map([]),
    )
    assert_eq(missing_signature.code, 401)

    let (wrong_path, _) = http_request(
      server.addr(),
      Post,
      "/wrong",
      ping,
      signed_headers(private_seed, timestamp, ping),
    )
    assert_eq(wrong_path.code, 404)

    let (wrong_method, _) = http_request(
      server.addr(),
      Get,
      "/interactions",
      "",
      Map([]),
    )
    assert_eq(wrong_method.code, 405)

    let malformed = "{"
    let (malformed_response, _) = http_request(
      server.addr(),
      Post,
      "/interactions",
      malformed,
      signed_headers(private_seed, timestamp, malformed),
    )
    assert_eq(malformed_response.code, 400)

    let invalid_utf8 = b"\xFF{}"
    let (invalid_utf8_response, _) = http_request_bytes(
      server.addr(),
      "/interactions",
      invalid_utf8,
      signed_headers_bytes(private_seed, timestamp, invalid_utf8),
    )
    assert_eq(invalid_utf8_response.code, 400)

    let unknown = command_body("missing", "hello", "500000000000000102")
    let (unknown_response, _) = http_request(
      server.addr(),
      Post,
      "/interactions",
      unknown,
      signed_headers(private_seed, timestamp, unknown),
    )
    assert_eq(unknown_response.code, 404)

    let attach = command_body("attach", "x", "500000000000000103")
    let (attach_response, attach_result) = http_request(
      server.addr(),
      Post,
      "/interactions",
      attach,
      signed_headers(private_seed, timestamp, attach),
    )
    assert_eq(attach_response.code, 200)
    guard attach_response.headers.get("content-type") is Some(content_type) else {
      fail("multipart reply is missing a content-type header")
    }
    assert_true(content_type.has_prefix("multipart/form-data; boundary="))
    assert_true(attach_result.contains("name=\"payload_json\""))
    assert_true(attach_result.contains("here is your file"))
    assert_true(
      attach_result.contains("name=\"files[0]\"; filename=\"hello.txt\""),
    )
    assert_true(attach_result.contains("hello file contents"))
  })
}

///|
async test "native interactions server rejects invalid keys before startup" {
  let app = @app.App(sync=Disabled)
  @async.with_task_group(group => {
    try
      serve_interactions(
        group,
        app,
        addr="127.0.0.1:0",
        public_key="00",
        token="",
        sync=false,
      )
      |> ignore
    catch {
      @verify.InvalidPublicKeyLength(got~) => assert_eq(got, 2)
      error => fail("unexpected startup error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid public key was accepted")
    }
  })
}
