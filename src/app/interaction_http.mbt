///|
/// The exact bytes received from an HTTP host. Never parse or reserialize
/// `body` before verifying the Discord signature.
pub(all) struct InteractionHttpRequest {
  http_method : String
  signature : String?
  timestamp : String?
  body : Bytes
}

///|
/// A callback body. Multipart chunks retain file bytes without a second copy.
pub(all) enum InteractionHttpBody {
  Empty
  Bytes(Bytes)
  Chunks(Array[@dhttp.MultipartChunk])
}

///|
/// A host-independent HTTP response for a Discord interaction.
pub(all) struct InteractionHttpResponse {
  status : Int
  content_type : String?
  body : InteractionHttpBody
}

///|
fn interaction_text_response(
  status : Int,
  body : String,
) -> InteractionHttpResponse {
  {
    status,
    content_type: Some("text/plain; charset=utf-8"),
    body: Bytes(@utf8.encode(body)),
  }
}

///|
/// Verify the raw HTTP body, decode one interaction, and dispatch it.
///
/// The caller owns the task group supplied to `App::serve`. Keep that group
/// alive after this method returns so deferred handlers can finish.
pub async fn InteractionEndpoint::handle_signed_http(
  self : InteractionEndpoint,
  request : InteractionHttpRequest,
  verifier : @verify.InteractionVerifier,
  deadline_ms? : Int = 2500,
) -> InteractionHttpResponse {
  if request.http_method != "POST" {
    return interaction_text_response(405, "method not allowed")
  }
  guard request.signature is Some(signature) &&
    request.timestamp is Some(timestamp) else {
    return interaction_text_response(401, "missing signature")
  }
  if !verifier.verify(signature~, timestamp~, body=request.body) {
    return interaction_text_response(401, "invalid signature")
  }
  let body = @utf8.decode(request.body) catch {
    _ => return interaction_text_response(400, "invalid UTF-8 body")
  }
  let interaction : @model.Interaction? = Some(
    @json.from_json(@json.parse(body)),
  ) catch {
    _ => None
  }
  guard interaction is Some(interaction) else {
    return interaction_text_response(400, "invalid interaction JSON")
  }
  match self.handle_interaction(interaction, deadline_ms~) {
    Reply(response~, files=None) =>
      {
        status: 200,
        content_type: Some("application/json"),
        body: Bytes(@utf8.encode(response.to_json().stringify())),
      }
    Reply(response~, files=Some(files)) => {
      let (content_type, chunks) = @dhttp.encode_multipart_body(
        response.to_json().stringify(),
        files,
      )
      { status: 200, content_type: Some(content_type), body: Chunks(chunks), }
    }
    NoRoute => interaction_text_response(404, "not found")
    NoResponse => { status: 202, content_type: None, body: Empty, }
    TimedOut => interaction_text_response(504, "initial response timed out")
  }
}
