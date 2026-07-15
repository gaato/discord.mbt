///|
/// One logical REST call before transport encoding. Middleware may pass a
/// rebuilt value to `next`. `headers` are extra headers merged into the wire
/// request after the client's base headers (content-type negotiation for
/// bodied requests still wins).
pub(all) struct HttpRequest {
  route : Route
  body : Json?
  audit_reason : String?
  files : Array[FileUpload]?
  headers : Map[String, String]
}

///|
/// Final wire response for one logical call (after internal 429 retries),
/// before status-code-to-error mapping.
pub(all) struct HttpResponse {
  status : Int
  headers : Map[String, String]
  body : Json
}

///|
/// Middleware around each HTTP request: receives the outgoing request and a
/// `next` continuation. Call `next` (with the request, possibly modified) to
/// proceed, and return the response, possibly modified. First installed is
/// outermost.
pub type HttpMiddleware = async (
  HttpRequest,
  async (HttpRequest) -> HttpResponse,
) -> HttpResponse

///|
async fn Client::run_middleware(
  self : Client,
  index : Int,
  request : HttpRequest,
) -> HttpResponse {
  if index < self.middleware_.length() {
    self.middleware_[index](request, next_request => {
      self.run_middleware(index + 1, next_request)
    })
  } else {
    self.execute(request)
  }
}
