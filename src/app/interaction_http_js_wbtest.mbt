///|
extern "js" fn InteractionHttpJsResponse::status(self : Self) -> Int =
  #| (response) => response.status

///|
extern "js" fn InteractionHttpJsResponse::content_type(self : Self) -> String =
  #| (response) => response.contentType ?? ""

///|
extern "js" fn InteractionHttpJsResponse::body_is_null(self : Self) -> Bool =
  #| (response) => response.body === null

///|
extern "js" fn InteractionHttpJsResponse::read_body(
  self : Self,
) -> @js_async.Promise[Bytes] =
  #| (response) => {
  #|   const body = response.body;
  #|   if (body === null) return Promise.resolve(new Uint8Array(0));
  #|   if (body instanceof Uint8Array) return Promise.resolve(body);
  #|   return new Response(body)
  #|     .arrayBuffer()
  #|     .then((buffer) => new Uint8Array(buffer));
  #| }

///|
/// RFC 8032 test vector 1.
const JS_SEED_1 : String = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"

///|
const JS_KEY_1 : String = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"

///|
/// RFC 8032 test vector 2.
const JS_SEED_2 : String = "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb"

///|
const JS_KEY_2 : String = "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"

///|
const JS_TIMESTAMP : String = "1720951200"

///|
fn js_fixture_app() -> App {
  let app = App()
  app.command(
    slash(
      name="echo",
      description="Echo text from MoonBit",
      args=@interaction.Args::of(
        @interaction.arg_string(name="text", description="What to echo"),
      ),
      handler=Immediate((_, text) => CommandReply::message(content=text)),
    ),
  )
  app.command(
    slash(
      name="file",
      description="Return a small attachment",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => {
        CommandReply::message(content="Attached from MoonBit.", files=[
          @dhttp.FileUpload(
            "hello.txt",
            b"hello from MoonBit\n",
            content_type="text/plain",
          ),
        ])
      }),
    ),
  )
  app.command(
    slash(
      name="silent",
      description="No initial response",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  app
}

///|
fn js_signed_request(
  seed_hex : String,
  body_text : String,
) -> InteractionHttpRequest raise {
  let body = @utf8.encode(body_text)
  let signature = @hex.encode(
    @ed25519.sign(@hex.decode(seed_hex), @utf8.encode(JS_TIMESTAMP) + body),
  )
  {
    http_method: "POST",
    signature: Some(signature),
    timestamp: Some(JS_TIMESTAMP),
    body,
  }
}

///|
fn js_ping_body() -> String {
  (
    #|{"id":"500000000000000100","application_id":"400000000000000001","type":1,"token":"interaction-token","version":1}
  )
}

///|
fn js_command_body(id : String, name : String, options : String) -> String {
  (
    #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"data":{"id":"600000000000000100","name":"COMMAND_NAME","type":1OPTIONS}}
  )
  .replace(old="INTERACTION_ID", new=id)
  .replace(old="COMMAND_NAME", new=name)
  .replace(old="OPTIONS", new=options)
}

///|
async fn js_await_response(
  dispatch : InteractionHttpDispatch,
) -> InteractionHttpJsResponse {
  match @async.with_timeout_opt(5000, () => dispatch.response().wait()) {
    Some(response) => response
    None => fail("the dispatch response promise timed out")
  }
}

///|
async fn js_await_background(dispatch : InteractionHttpDispatch) -> Unit {
  match @async.with_timeout_opt(5000, () => dispatch.background().wait()) {
    Some(_) => ()
    None => fail("the dispatch background promise timed out")
  }
}

///|
async fn js_read_text(response : InteractionHttpJsResponse) -> String {
  match @async.with_timeout_opt(5000, () => response.read_body().wait()) {
    Some(bytes) => @utf8.decode(bytes)
    None => fail("the response body never drained")
  }
}

///|
fn js_start(
  app : App,
  request : InteractionHttpRequest,
  public_key~ : String,
  abort_signal? : @js_async.AbortSignal,
) -> InteractionHttpDispatch raise {
  app.start_signed_http(
    request,
    token="test-token",
    application_id=@model.Id::parse("400000000000000001"),
    public_key~,
    api_base_url="http://127.0.0.1:1",
    abort_signal?,
  )
}

///|
async test "js dispatch returns the echo callback then completes" {
  let app = js_fixture_app()
  let request = js_signed_request(
    JS_SEED_1,
    js_command_body(
      "500000000000000200",
      "echo",
      (
        #|,"options":[{"name":"text","type":3,"value":"hello from js"}]
      ),
    ),
  )
  let dispatch = js_start(app, request, public_key=JS_KEY_1)
  let response = js_await_response(dispatch)
  assert_eq(response.status(), 200)
  assert_eq(response.content_type(), "application/json")
  assert_false(response.body_is_null())
  assert_eq(
    js_read_text(response),
    (
      #|{"type":4,"data":{"content":"hello from js"}}
    ),
  )
  js_await_background(dispatch)
}

///|
async test "js dispatch maps invalid JSON to 400" {
  let app = js_fixture_app()
  let request = js_signed_request(JS_SEED_1, "{")
  let dispatch = js_start(app, request, public_key=JS_KEY_1)
  let response = js_await_response(dispatch)
  assert_eq(response.status(), 400)
  assert_eq(js_read_text(response), "invalid interaction JSON")
  js_await_background(dispatch)
}

///|
async test "js dispatch streams a multipart reply" {
  let app = js_fixture_app()
  let request = js_signed_request(
    JS_SEED_1,
    js_command_body("500000000000000201", "file", ""),
  )
  let dispatch = js_start(app, request, public_key=JS_KEY_1)
  let response = js_await_response(dispatch)
  assert_eq(response.status(), 200)
  let content_type = response.content_type()
  let prefix = "multipart/form-data; boundary="
  assert_true(content_type.has_prefix(prefix))
  let boundary = content_type[prefix.length():].to_owned()
  assert_false(response.body_is_null())
  let text = js_read_text(response)
  let payload = text.find("payload_json")
  let filename = text.find("filename=\"hello.txt\"")
  let contents = text.find("hello from MoonBit\n")
  guard payload is Some(payload) &&
    filename is Some(filename) &&
    contents is Some(contents) else {
    fail("the multipart body is missing a part: \{text}")
  }
  assert_true(payload < filename)
  assert_true(filename < contents)
  assert_true(text.has_suffix("--\{boundary}--\r\n"))
  js_await_background(dispatch)
}

///|
async test "js dispatch rejects a pre-aborted response and still finishes" {
  let app = js_fixture_app()
  let request = js_signed_request(
    JS_SEED_1,
    js_command_body(
      "500000000000000202",
      "echo",
      (
        #|,"options":[{"name":"text","type":3,"value":"aborted"}]
      ),
    ),
  )
  let controller = @js_async.AbortController::new()
  controller.abort()
  let dispatch = js_start(
    app,
    request,
    public_key=JS_KEY_1,
    abort_signal=controller.signal(),
  )
  try dispatch.response().wait() |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("a pre-aborted dispatch must reject its response promise")
  }
  js_await_background(dispatch)
}

///|
async test "js dispatch answers a silent handler with 202 and no body" {
  let app = js_fixture_app()
  let request = js_signed_request(
    JS_SEED_1,
    js_command_body("500000000000000203", "silent", ""),
  )
  let dispatch = js_start(app, request, public_key=JS_KEY_1)
  let response = js_await_response(dispatch)
  assert_eq(response.status(), 202)
  assert_eq(response.content_type(), "")
  assert_true(response.body_is_null())
  js_await_background(dispatch)
}

///|
async test "js dispatch rebuilds the verifier when the public key rotates" {
  let app = js_fixture_app()
  let first = js_start(
    app,
    js_signed_request(JS_SEED_1, js_ping_body()),
    public_key=JS_KEY_1,
  )
  assert_eq(js_await_response(first).status(), 200)
  js_await_background(first)
  let second = js_start(
    app,
    js_signed_request(JS_SEED_2, js_ping_body()),
    public_key=JS_KEY_2,
  )
  assert_eq(js_await_response(second).status(), 200)
  js_await_background(second)
}

///|
async test "js dispatch rejects an unusable public key without caching it" {
  let app = js_fixture_app()
  let unusable = "z".repeat(64)
  let broken = js_start(
    app,
    js_signed_request(JS_SEED_1, js_ping_body()),
    public_key=unusable,
  )
  let response = js_await_response(broken)
  assert_eq(response.status(), 401)
  assert_eq(js_read_text(response), "invalid signature")
  js_await_background(broken)
  let usable = js_start(
    app,
    js_signed_request(JS_SEED_1, js_ping_body()),
    public_key=JS_KEY_1,
  )
  assert_eq(js_await_response(usable).status(), 200)
  js_await_background(usable)
}
