///|
priv enum ServerStartup {
  Ready
  Failed(Error)
}

///|
priv enum EndpointResponse {
  TextResponse(Int, String, String, String?)
  MultipartResponse(String, Array[@dhttp.MultipartChunk])
}

///|
fn text_response(
  status : Int,
  reason : String,
  body : String,
  content_type : String?,
) -> EndpointResponse {
  TextResponse(status, reason, body, content_type)
}

///|
fn multipart_response(
  response : @model.InteractionResponse,
  files : Array[@dhttp.FileUpload],
) -> EndpointResponse raise {
  let (content_type, chunks) = @dhttp.encode_multipart_body(
    response.to_json().stringify(),
    files,
  )
  MultipartResponse(content_type, chunks)
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
) -> EndpointResponse {
  if request.meth != Post {
    conn.skip_request_body()
    return text_response(
      405,
      "Method Not Allowed",
      "method not allowed",
      Some("text/plain; charset=utf-8"),
    )
  }
  if request.path != path {
    conn.skip_request_body()
    return text_response(
      404,
      "Not Found",
      "not found",
      Some("text/plain; charset=utf-8"),
    )
  }
  guard request.headers.get("x-signature-ed25519") is Some(signature) &&
    request.headers.get("x-signature-timestamp") is Some(timestamp) else {
    conn.skip_request_body()
    return text_response(
      401,
      "Unauthorized",
      "missing signature",
      Some("text/plain; charset=utf-8"),
    )
  }
  let body_bytes = body_reader.read_all().binary()
  if !verifier.verify(signature~, timestamp~, body=body_bytes) {
    return text_response(
      401,
      "Unauthorized",
      "invalid signature",
      Some("text/plain; charset=utf-8"),
    )
  }
  let body = @utf8.decode(body_bytes) catch {
    _ =>
      return text_response(
        400,
        "Bad Request",
        "invalid UTF-8 body",
        Some("text/plain; charset=utf-8"),
      )
  }
  let interaction : @model.Interaction? = Some(
    @json.from_json(@json.parse(body)),
  ) catch {
    _ => None
  }
  guard interaction is Some(interaction) else {
    return text_response(
      400,
      "Bad Request",
      "invalid interaction JSON",
      Some("text/plain; charset=utf-8"),
    )
  }
  match endpoint.handle_interaction(interaction, deadline_ms~) {
    Reply(response~, files=None) =>
      text_response(
        200,
        "OK",
        response.to_json().stringify(),
        Some("application/json"),
      )
    Reply(response~, files=Some(files)) => multipart_response(response, files)
    NoRoute =>
      text_response(
        404,
        "Not Found",
        "not found",
        Some("text/plain; charset=utf-8"),
      )
    NoResponse | TimedOut => text_response(202, "Accepted", "", None)
  }
}

///|
async fn send_response(
  conn : @ahttp.ServerConnection,
  response : EndpointResponse,
) -> Unit {
  match response {
    TextResponse(status, reason, body, content_type) => {
      let headers : @ahttp.Headers = Map([])
      if content_type is Some(value) {
        headers["Content-Type"] = value
      }
      conn.send_response(status, reason, extra_headers=headers)
      if !body.is_empty() {
        conn.write_string(body)
      }
      conn.end_response()
    }
    MultipartResponse(content_type, chunks) => {
      conn.send_response(200, "OK", extra_headers={
        "Content-Type": content_type,
      })
      for chunk in chunks {
        match chunk {
          Text(text) => conn.write_string(text)
          Blob(bytes) => @io.Writer::write(conn, bytes)
        }
      }
      conn.end_response()
    }
  }
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
      text_response(
        500,
        "Internal Server Error",
        "internal server error",
        Some("text/plain; charset=utf-8"),
      )
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
