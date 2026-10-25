///|
async test "interaction endpoint preserves rejection order and bounds signed raw bodies" {
  let key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let verifier = @verify.InteractionVerifier::new(key)
  @async.with_task_group(group => {
    let endpoint = @app.AppBuilder()
      .build()
      .serve(
        group,
        access=Token("test-token"),
        application_id=@model.Id::parse("400000000000000001"),
      )
    let handler = interaction_handler(endpoint, verifier, max_body_bytes=2)
    for
      (request, status) in [
        (@hmodel.Request::get("http://localhost/"), 405),
        (@hmodel.Request::get("http://localhost/other"), 405),
        (@hmodel.Request::post("http://localhost/other"), 404),
        (@hmodel.Request::post("http://localhost/"), 401),
        (
          @hmodel.Request::post("http://localhost/").header(
            "x-signature-ed25519", "aa",
          ),
          401,
        ),
        (
          @hmodel.Request::post("http://localhost/")
          .header("x-signature-ed25519", "aa")
          .header("x-signature-timestamp", "1")
          .body_bytes(b"{}"),
          401,
        ),
        (
          @hmodel.Request::post("http://localhost/")
          .header("x-signature-ed25519", "aa")
          .header("x-signature-timestamp", "1")
          .body_bytes(b"too large"),
          413,
        ),
      ] {
      let response = handler(request)
      defer response.close()
      assert_eq(response.status, status)
      if status == 413 {
        assert_true(response.closes_connection())
      }
    }
  })
}

///|
async test "multipart response streams skip empty chunks and close without copying the payload" {
  let body = response_body(Chunks([b"", b"first", b"", b"second", b""]))
  assert_eq(body.length(), Some(11L))
  guard body is Stream(owner) else { fail("expected multipart stream") }
  let stream = owner.take()
  assert_eq(stream.read_some(), Some(b"first"))
  assert_eq(stream.read_some(), Some(b"second"))
  assert_eq(stream.read_some(), None)
  assert_eq(stream.read_some(), None)
  stream.close()
  let early = response_body(Chunks([b"one", b"two"]))
  guard early is Stream(owner) else { fail("expected multipart stream") }
  let stream = owner.take()
  assert_eq(stream.read_some(), Some(b"one"))
  stream.close()
  assert_eq(stream.read_some(), None)
}

///|
async test "interaction endpoint reports reply encoding failures as 500" {
  let key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let seed = @hex.decode(
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
  )
  let verifier = @verify.InteractionVerifier::new(key)
  let app = @app.AppBuilder()
  app.command(
    @app.slash(
      name="broken",
      description="Invalid attachment",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => {
        @app.CommandReply::message(files=[@dhttp.FileUpload("", b"payload")])
      }),
    ),
  )
  let text =
    #|{"id":"500000000000000201","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":null,"avatar":null},"data":{"id":"600000000000000201","name":"broken","type":1}}
  let body = @utf8.encode(text)
  let signature = @hex.encode(@ed25519.sign(seed, b"1" + body))
  @async.with_task_group(group => {
    let endpoint = app
      .build()
      .serve(
        group,
        access=Token("test-token"),
        application_id=@model.Id::parse("400000000000000001"),
      )
    let warnings = []
    let handler = interaction_handler(endpoint, verifier, warn=warning => {
      warnings.push(warning.to_string())
    })
    let response = handler(
      @hmodel.Request::post("http://localhost/")
      .header("x-signature-ed25519", signature)
      .header("x-signature-timestamp", "1")
      .body_bytes(body),
    )
    defer response.close()
    assert_eq(response.status, 500)
    assert_eq(warnings.length(), 1)
    assert_true(warnings[0].contains("interaction HTTP request failed"))
  })
}
