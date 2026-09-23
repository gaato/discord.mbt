///|
priv enum ServerStartup {
  Ready
  Failed(Error)
}

///|
fn text_response(status : Int, body : String) -> @app.InteractionHttpResponse {
  {
    status,
    content_type: Some("text/plain; charset=utf-8"),
    body: Bytes(@utf8.encode(body)),
  }
}

///|
async fn route_request(
  request : @ahttp.Request,
  body_reader : &@io.Reader,
  conn : @ahttp.ServerConnection,
  endpoint : @app.InteractionEndpoint,
  verifier : @verify.InteractionVerifier,
  path : String,
  deadline_ms : Int,
) -> @app.InteractionHttpResponse {
  if request.meth != Post {
    conn.skip_request_body()
    return text_response(405, "method not allowed")
  }
  if request.path != path {
    conn.skip_request_body()
    return text_response(404, "not found")
  }
  let body_bytes = body_reader.read_all().binary()
  endpoint.handle_signed_http(
    {
      http_method: "POST",
      signature: request.headers.get("x-signature-ed25519"),
      timestamp: request.headers.get("x-signature-timestamp"),
      body: body_bytes,
    },
    verifier,
    deadline_ms~,
  )
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
    504 => "Gateway Timeout"
    _ => "Internal Server Error"
  }
  conn.send_response(response.status, reason, extra_headers=headers)
  match response.body {
    Empty => ()
    Bytes(bytes) => @io.Writer::write(conn, bytes)
    Chunks(chunks) =>
      for chunk in chunks {
        match chunk {
          Text(text) => conn.write_string(text)
          Blob(bytes) => @io.Writer::write(conn, bytes)
        }
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
  deadline_ms : Int,
  warn : (String) -> Unit,
) -> Unit {
  let response = try
    route_request(
      request, body_reader, conn, endpoint, verifier, path, deadline_ms,
    )
  catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      warn("interaction HTTP request failed: \{Repr(error)}")
      text_response(500, "internal server error")
    }
  } noraise {
    response => response
  }
  send_response(conn, response) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      warn("interaction HTTP response failed: \{Repr(error)}")
      conn.close()
    }
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
pub async fn[X] serve_interactions(
  group : @async.TaskGroup[X],
  app : @app.App,
  addr~ : String,
  public_key~ : String,
  client? : @dhttp.Client,
  token? : String,
  application_id? : @model.ApplicationId,
  path? : String = "/",
  deadline_ms? : Int = 2500,
) -> InteractionsServer {
  let verifier = @verify.InteractionVerifier::new(public_key)
  let server = @ahttp.Server(@socket.Addr::parse(addr))
  let address = server.addr.to_string()
  let runner : Ref[@async.TaskGroup[Unit]?] = Ref(None)
  let startup : @aqueue.Queue[ServerStartup] = Queue(kind=Unbounded)
  let warn : (String) -> Unit = message => app.warn(message)
  group.spawn_bg(allow_failure=true, () => {
    let mut ready = false
    @async.with_task_group(inner => {
      runner.val = Some(inner)
      let endpoint = app.serve(inner, client?, token?, application_id?)
      inner.spawn_bg(() => {
        server.run_forever(allow_failure=true, (request, body_reader, conn) => {
          handle_request(
            request, body_reader, conn, endpoint, verifier, path, deadline_ms, warn,
          )
        })
      })
      startup.put(Ready)
      ready = true
    }) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        if ready {
          warn("interaction HTTP server stopped: \{Repr(error)}")
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
