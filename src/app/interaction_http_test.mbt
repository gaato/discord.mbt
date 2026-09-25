///|
async test "signed HTTP API verifies exact bytes before dispatch" {
  let key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let seed = @hex.decode(
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
  )
  let body_text =
    #|{"id":"500000000000000100","application_id":"400000000000000001","type":1,"token":"interaction-token","version":1}
  let body = @utf8.encode(body_text)
  let signature = @hex.encode(
    @ed25519.sign(seed, @utf8.encode("1720951200") + body),
  )
  let verifier = @verify.InteractionVerifier::new(key)
  @async.with_task_group(group => {
    let endpoint = @app.App().serve(
      group,
      token="test-token",
      application_id=@model.Id::parse("400000000000000001"),
    )
    let request : @app.InteractionHttpRequest = {
      http_method: "POST",
      signature: Some(signature),
      timestamp: Some("1720951200"),
      body,
    }
    let reply = endpoint.handle_signed_http(request, verifier)
    assert_eq(reply.status, 200)
    assert_eq(reply.content_type, Some("application/json"))
    match reply.body {
      Bytes(bytes) => assert_eq(@utf8.decode(bytes), "{\"type\":1}")
      _ => fail("PING must be JSON bytes")
    }
    assert_eq(
      endpoint.handle_signed_http({ ..request, body: body + b" ", }, verifier).status,
      401,
    )
    assert_eq(
      endpoint.handle_signed_http({ ..request, signature: None, }, verifier).status,
      401,
    )
    assert_eq(
      endpoint.handle_signed_http({ ..request, http_method: "GET", }, verifier).status,
      405,
    )
  })
}

///|
async test "signed HTTP API answers 202 without a reply and 504 past the deadline" {
  let key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let seed = @hex.decode(
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
  )
  let verifier = @verify.InteractionVerifier::new(key)
  let signed = (name : String) => {
    let body = @utf8.encode(
      (
        #|{"id":"500000000000000101","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":null,"avatar":null},"data":{"id":"600000000000000100","name":"NAME","type":1}}
      ).replace(old="NAME", new=name),
    )
    let request : @app.InteractionHttpRequest = {
      http_method: "POST",
      signature: Some(
        @hex.encode(@ed25519.sign(seed, @utf8.encode("1720951200") + body)),
      ),
      timestamp: Some("1720951200"),
      body,
    }
    request
  }
  let app = @app.App()
  app.command(
    @app.slash(
      name="silent",
      description="No initial response",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  app.command(
    @app.slash(
      name="slow",
      description="Slow initial response",
      args=@interaction.Args::unit(),
      handler=Raw(_ => @async.sleep(50)),
    ),
  )
  @async.with_task_group(group => {
    let endpoint = app.serve(
      group,
      token="test-token",
      application_id=@model.Id::parse("400000000000000001"),
    )
    let silent = endpoint.handle_signed_http(signed("silent"), verifier)
    assert_eq(silent.status, 202)
    assert_true(silent.content_type is None)
    assert_true(silent.body is Empty)
    let slow = endpoint.handle_signed_http(
      signed("slow"),
      verifier,
      deadline_ms=5,
    )
    assert_eq(slow.status, 504)
    match slow.body {
      Bytes(bytes) =>
        assert_eq(@utf8.decode(bytes), "initial response timed out")
      _ => fail("a timeout must be a text body")
    }
  })
}
