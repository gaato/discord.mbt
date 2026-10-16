///|
priv enum ServerStartup {
  Ready
  Failed(Error)
}

///|
fn text_response(status : Int32, body : String) -> @app.InteractionHttpResponse {
  {
    status,
    content_type: Some("text/plain; charset=utf-8"),
    body: Bytes(@utf8.encode(body)),
  }
}

///|
/// Configuration rejected by `serve_interactions` before it starts listening.
pub(all) suberror ServerConfigError {
  InvalidMaxBodyBytes(value~ : Int32)
  InvalidBodyTimeoutMs(value~ : Int32)
} derive(@debug.Debug)

///|
priv enum BodyRead {
  Complete(Bytes)
  TooLarge
  TimedOut
}

///|
/// Read a request body of at most `max_bytes` within `timeout_ms`, so a client
/// can neither exhaust memory with a large body nor hold the connection by
/// sending slowly. With `keep=false` the body is counted and discarded.
async fn read_body(
  body_reader : &@io.Reader,
  max_bytes : Int32,
  timeout_ms : Int32,
  keep~ : Bool,
) -> BodyRead {
  let buffer = Buffer()
  let mut length = 0
  let read = @async.with_timeout_opt(timeout_ms, () => {
    for ;; {
      // Ask for one byte past the limit to tell a body of exactly
      // `max_bytes` from a larger one, in chunks of at most 64 KiB.
      let room = max_bytes - length
      let max_len = if room < 65536 { room + 1 } else { 65536 }
      guard body_reader.read_some(max_len~) is Some(chunk) else { break true }
      // Compare against the room left rather than summing first, which would
      // overflow when `max_bytes` is near `Int` maximum.
      if chunk.length() > room {
        break false
      }
      length += chunk.length()
      if keep {
        buffer.write_bytes(chunk)
      }
    }
  })
  match read {
    Some(true) => Complete(buffer.to_bytes())
    Some(false) => TooLarge
    None => TimedOut
  }
}

///|
/// The answer to a request its head already rules out: the wrong method, the
/// wrong path, or a missing signature header, checked in that order.
fn request_rejection(
  request : @ahttp.Request,
  path : String,
) -> @app.InteractionHttpResponse? {
  if request.meth != Post {
    Some(text_response(405, "method not allowed"))
  } else if request.path != path {
    Some(text_response(404, "not found"))
  } else if !(request.headers.contains("x-signature-ed25519") &&
    request.headers.contains("x-signature-timestamp")) {
    // A request without both signature headers cannot verify, so answer
    // without keeping a body that an unauthenticated client controls.
    Some(text_response(401, "missing signature"))
  } else {
    None
  }
}

///|
/// The body to hand the endpoint, or the response to send instead with
/// whether the connection must close because the body was not read to its
/// end.
fn settle_body(
  rejection : @app.InteractionHttpResponse?,
  body : BodyRead,
) -> Result[Bytes, (@app.InteractionHttpResponse, Bool)] {
  match (rejection, body) {
    // Drain a small rejected body to keep the connection; give up on a large
    // or slow one and close instead.
    (Some(response), Complete(_)) => Err((response, false))
    (Some(response), TooLarge | TimedOut) => Err((response, true))
    (None, Complete(bytes)) => Ok(bytes)
    (None, TooLarge) =>
      Err((text_response(413, "request body too large"), true))
    (None, TimedOut) =>
      Err((text_response(408, "request body timed out"), true))
  }
}

///|
/// Route one request. The flag is true when the connection must close after
/// the response because the body was not read to its end.
async fn route_request(
  request : @ahttp.Request,
  body_reader : &@io.Reader,
  endpoint : @app.InteractionEndpoint,
  verifier : @verify.InteractionVerifier,
  path : String,
  deadline_ms : Int32,
  max_body_bytes : Int32,
  body_timeout_ms : Int32,
) -> (@app.InteractionHttpResponse, Bool) {
  let rejection = request_rejection(request, path)
  let body = read_body(
    body_reader,
    max_body_bytes,
    body_timeout_ms,
    keep=rejection is None,
  )
  let body_bytes = match settle_body(rejection, body) {
    Ok(bytes) => bytes
    Err(answer) => return answer
  }
  let response = endpoint.handle_signed_http(
    {
      http_method: "POST",
      signature: request.headers.get("x-signature-ed25519"),
      timestamp: request.headers.get("x-signature-timestamp"),
      body: body_bytes,
    },
    verifier,
    deadline_ms~,
  )
  (response, false)
}

///|
async fn send_response(
  conn : @ahttp.ServerConnection,
  response : @app.InteractionHttpResponse,
) -> Unit {
  let headers : @ahttp.Headers = Map([])
  if response.content_type is Some(value) {
    headers["Content-Type"] = value
  }
  let reason = match response.status {
    200 => "OK"
    202 => "Accepted"
    400 => "Bad Request"
    401 => "Unauthorized"
    404 => "Not Found"
    405 => "Method Not Allowed"
    408 => "Request Timeout"
    413 => "Content Too Large"
    504 => "Gateway Timeout"
    _ => "Internal Server Error"
  }
  conn.send_response(response.status, reason, extra_headers=headers)
  match response.body {
    Empty => ()
    Bytes(bytes) => @io.Writer::write(conn, bytes)
    Chunks(chunks) =>
      for chunk in chunks {
        @io.Writer::write(conn, chunk)
      }
  }
  conn.end_response()
}

///|
async fn handle_request(
  request : @ahttp.Request,
  body_reader : &@io.Reader,
  conn : @ahttp.ServerConnection,
  endpoint : @app.InteractionEndpoint,
  verifier : @verify.InteractionVerifier,
  path : String,
  deadline_ms : Int32,
  max_body_bytes : Int32,
  body_timeout_ms : Int32,
  warn : (@app.AppWarning) -> Unit,
) -> Unit {
  let (response, close) = try
    route_request(
      request, body_reader, endpoint, verifier, path, deadline_ms, max_body_bytes,
      body_timeout_ms,
    )
  catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      warn(
        @app.Executor(
          source="http",
          message="interaction HTTP request failed: \{Repr(error)}",
        ),
      )
      (text_response(500, "internal server error"), false)
    }
  } noraise {
    routed => routed
  }
  send_response(conn, response) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      warn(
        @app.Executor(
          source="http",
          message="interaction HTTP response failed: \{Repr(error)}",
        ),
      )
      conn.close()
    }
  }
  if close {
    conn.close()
  }
}

///|
/// An HTTP server dispatching Discord interactions on native or moonrun Wasm.
pub struct InteractionsServer {
  priv address : String
  priv runner : Ref[@async.TaskGroup[Unit]?]
}

///|
/// Return the actual listening address, including an OS-assigned port.
pub fn InteractionsServer::addr(self : InteractionsServer) -> String {
  self.address
}

///|
/// Stop accepting requests and cancel active connection handlers.
pub async fn InteractionsServer::close(
  self : InteractionsServer,
) -> Unit noraise {
  if self.runner.val is Some(inner) {
    inner.return_immediately(())
  }
}

///|
/// Start a Discord HTTP-interactions server in `group` on native or moonrun Wasm.
///
/// Use port zero in `addr` to let the OS choose a free port, then read the
/// resolved address from `InteractionsServer::addr`.
///
/// A request body larger than `max_body_bytes` gets 413, and one not received
/// within `body_timeout_ms` gets 408; both close the connection. Discord's
/// interaction payloads are far below the 1 MiB default. Non-positive limits
/// raise `ServerConfigError` before the server listens.
pub async fn[X] serve_interactions(
  group : @async.TaskGroup[X],
  app : @app.App,
  addr~ : String,
  public_key~ : String,
  access~ : @app.RestAccess,
  application_id? : @model.ApplicationId,
  path~ : String = "/",
  deadline_ms~ : Int32 = 2500,
  max_body_bytes~ : Int32 = 1048576,
  body_timeout_ms~ : Int32 = 5000,
) -> InteractionsServer {
  guard max_body_bytes > 0 else {
    raise InvalidMaxBodyBytes(value=max_body_bytes)
  }
  guard body_timeout_ms > 0 else {
    raise InvalidBodyTimeoutMs(value=body_timeout_ms)
  }
  let verifier = @verify.InteractionVerifier::new(public_key)
  let server = @ahttp.Server(@socket.Addr::parse(addr))
  let address = server.addr.to_string()
  let runner : Ref[@async.TaskGroup[Unit]?] = Ref(None)
  let startup : @aqueue.Queue[ServerStartup] = Queue(kind=Unbounded)
  let warn : (@app.AppWarning) -> Unit = warning => app.warn(warning)
  group.spawn_bg(allow_failure=true, () => {
    let mut ready = false
    @async.with_task_group(inner => {
      runner.val = Some(inner)
      let endpoint = app.serve(inner, access~, application_id?)
      inner.spawn_bg(() => {
        server.run_forever(allow_failure=true, (request, body_reader, conn) => {
          handle_request(
            request, body_reader, conn, endpoint, verifier, path, deadline_ms, max_body_bytes,
            body_timeout_ms, warn,
          )
        })
      })
      startup.put(Ready)
      ready = true
    }) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        if ready {
          warn(
            @app.Executor(
              source="http",
              message="interaction HTTP server stopped: \{Repr(error)}",
            ),
          )
        } else {
          startup.put(Failed(error))
        }
    }
  })
  match startup.get() {
    Ready => { address, runner, }
    Failed(error) => raise error
  }
}
