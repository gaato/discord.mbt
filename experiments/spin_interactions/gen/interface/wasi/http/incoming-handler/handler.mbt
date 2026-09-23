// The WIT binding generator owns the surrounding files; this is the adapter.

///|
fn header(headers : @types.Fields, name : String) -> String? {
  guard headers.get(name).get(0) is Some(value) else { return None }
  Some(@utf8.decode(Bytes::from_array(value[:])) catch { _ => return None })
}

///|
fn public_key() -> String? {
  match @variables.get("public_key") {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn read_body(request : @types.IncomingRequest) -> Bytes? {
  guard request.consume() is Ok(body) else { return None }
  guard body.stream() is Ok(stream) else {
    body.drop()
    return None
  }
  let bytes : Array[Byte] = []
  let mut valid = true
  for attempt = 0; ; attempt = attempt + 1 {
    match stream.blocking_read(65536UL) {
      Ok(chunk) => {
        if bytes.length() + chunk.length() > 1_048_576 {
          valid = false
          break
        }
        for byte in chunk {
          bytes.push(byte)
        }
      }
      Err(Closed) => break
      Err(_) => {
        valid = false
        break
      }
    }
  }
  stream.drop()
  body.drop()
  if valid {
    Some(Bytes::from_array(bytes[:]))
  } else {
    None
  }
}

///|
fn reply(
  response_out : @types.ResponseOutparam,
  status : Int,
  text : String,
  content_type : String,
) -> Unit {
  let headers = match
    @types.Fields::from_list([
      ("content-type", @utf8.encode(content_type).to_fixedarray()),
    ]) {
    Ok(headers) => headers
    Err(_) => @types.Fields::fields()
  }
  let response = @types.OutgoingResponse::outgoing_response(headers)
  response.set_status_code(status.reinterpret_as_uint()) |> ignore
  guard response.body() is Ok(body) else {
    @types.ResponseOutparam::set(response_out, Ok(response))
    return
  }
  @types.ResponseOutparam::set(response_out, Ok(response))
  if body.write() is Ok(stream) {
    stream.blocking_write_and_flush(@utf8.encode(text).to_fixedarray())
    |> ignore
    stream.drop()
  }
  @types.OutgoingBody::finish(body, None) |> ignore
}

///|
fn interaction_response(body : Bytes) -> (Int, String, String) {
  let text = @utf8.decode(body) catch {
    _ => return (400, "Invalid UTF-8", "text/plain; charset=utf-8")
  }
  let interaction : @model.Interaction = @json.from_json(@json.parse(text)) catch {
    _ =>
      return (400, "Invalid interaction payload", "text/plain; charset=utf-8")
  }
  match interaction.typ {
    Ping => (200, "{\"type\":1}", "application/json")
    ApplicationCommand => {
      guard interaction.data is Some(Command(command)) && command.name == "echo" else {
        return (404, "No interaction route", "text/plain; charset=utf-8")
      }
      guard command.options is Some(options) else {
        return (400, "Missing text", "text/plain; charset=utf-8")
      }
      for option in options {
        if option.name == "text" && option.value is Some(String(value)) {
          let content = Json::string(value).stringify()
          return (
            200,
            "{\"type\":4,\"data\":{\"content\":" + content + "}}",
            "application/json",
          )
        }
      }
      (400, "Missing text", "text/plain; charset=utf-8")
    }
    _ => (404, "No interaction route", "text/plain; charset=utf-8")
  }
}

///|
pub fn handle(
  request : @types.IncomingRequest,
  response_out : @types.ResponseOutparam,
) -> Unit {
  guard request.method_() is Post else {
    request.drop()
    reply(response_out, 405, "Method Not Allowed", "text/plain; charset=utf-8")
    return
  }
  let headers = request.headers()
  let signature = header(headers, "x-signature-ed25519")
  let timestamp = header(headers, "x-signature-timestamp")
  headers.drop()
  let body = read_body(request)
  request.drop()
  guard public_key() is Some(key) else {
    reply(response_out, 500, "Missing public key", "text/plain; charset=utf-8")
    return
  }
  guard signature is Some(signature) && timestamp is Some(timestamp) else {
    reply(response_out, 401, "Missing signature", "text/plain; charset=utf-8")
    return
  }
  guard body is Some(body) else {
    reply(response_out, 400, "Could not read body", "text/plain; charset=utf-8")
    return
  }
  if !@verify.verify_signature(
      public_key=key,
      signature~,
      timestamp~,
      body=body[:],
    ) {
    reply(
      response_out, 401, "Invalid request signature", "text/plain; charset=utf-8",
    )
    return
  }
  let (status, text, content_type) = interaction_response(body)
  reply(response_out, status, text, content_type)
}
