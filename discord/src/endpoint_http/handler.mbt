///|
priv suberror SignatureRejected {
  SignatureRejected
}

///|
priv struct ResponseChunks {
  chunks : Array[Bytes]
  mut cursor : Int32
}

///|
impl @hmodel.BodyStream for ResponseChunks with fn read_some(self) {
  while self.cursor < self.chunks.length() {
    let chunk = self.chunks[self.cursor]
    self.cursor += 1
    if !chunk.is_empty() {
      return Some(chunk)
    }
  }
  None
}

///|
impl @hmodel.BodyStream for ResponseChunks with fn close(self) {
  self.cursor = self.chunks.length()
}

///|
fn response_body(body : @app.InteractionHttpBody) -> @hmodel.Body {
  match body {
    Empty => Empty
    Bytes(bytes) => Bytes(bytes)
    Chunks(chunks) => {
      let length = chunks.fold(init=0L, (sum, chunk) => {
        sum + chunk.length().to_int64()
      })
      Stream(
        @hmodel.StreamBody::new(
          ResponseChunks::{ chunks: chunks.copy(), cursor: 0, },
          length~,
        ),
      )
    }
  }
}

///|
fn text_response(status : Int32, text : String) -> @hmodel.Response {
  @hmodel.Response::new(
    status,
    headers=@hmodel.Headers::of([("content-type", "text/plain; charset=utf-8")]),
    body=Bytes(@utf8.encode(text)),
  )
}

///|
/// Build the signed interaction endpoint for a native server or a Fetch host.
/// The caller keeps the task group owning `endpoint` alive for deferred work.
/// Signature verification consumes the exact bounded bytes, before dispatch.
pub fn interaction_handler(
  endpoint : @app.InteractionEndpoint,
  verifier : @verify.InteractionVerifier,
  path~ : String = "/",
  deadline_ms~ : Int32 = 2500,
  max_body_bytes~ : Int32 = 1048576,
  warn~ : (@app.AppWarning) -> Unit = _ => (),
) -> @hmodel.Handler raise @endpoint.DefinitionError {
  let security = @endpoint.Input::map3(
    @endpoint.signature_header("x-signature-ed25519"),
    @endpoint.signature_header("x-signature-timestamp"),
    @endpoint.raw_body(),
    (signature, timestamp, body) => (signature, timestamp, body),
    value => value,
  )
  let route = @endpoint.endpoint
    .post(path)
    .security(security)
    .max_body_bytes(max_body_bytes)
    .output(@endpoint.stream_body_out().and_status())
    .serve(
      credentials => {
        let (signature, timestamp, body) = credentials
        if !verifier.verify(signature~, timestamp~, body~) {
          raise SignatureRejected
        }
        credentials
      },
      (credentials, _) => {
        let (signature, timestamp, body) = credentials
        let response = endpoint.handle_signed_http(
          {
            http_method: "POST",
            signature: Some(signature),
            timestamp: Some(timestamp),
            body,
          },
          verifier,
          deadline_ms~,
        )
        ((response.content_type, response_body(response.body)), response.status)
      },
    )
  let router = @router.Router::new([route], options={
    ..@router.ServerOptions::default(),
    max_body_bytes,
    reject: (request, _) => {
      if request.meth != Post {
        text_response(405, "method not allowed")
      } else {
        text_response(404, "not found")
      }
    },
    decode_failure: context => {
      if context.failures.any(f => {
          f.failure is @schema.DecodeFailure(kind=TooLarge(..), ..)
        }) {
        Some(text_response(413, "request body too large"))
      } else if context.failures.any(f => f.atom.location is RawBody) {
        warn(
          @app.Executor(
            source="http",
            message="interaction HTTP request failed: invalid request body",
          ),
        )
        Some(text_response(400, "invalid request body"))
      } else {
        Some(text_response(401, "missing signature"))
      }
    },
    on_unhandled: (_, error) => {
      match error {
        SignatureRejected => Some(text_response(401, "invalid signature"))
        _ => {
          warn(
            @app.Executor(
              source="http",
              message="interaction HTTP request failed: \{Repr(error)}",
            ),
          )
          Some(text_response(500, "internal server error"))
        }
      }
    },
  })
  router.handler()
}
