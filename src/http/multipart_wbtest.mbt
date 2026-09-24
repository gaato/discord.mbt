///|
/// Render a multipart body with CR/LF and non-printable bytes made visible,
/// so the snapshot stays faithful (`#|` strings cannot hold raw `\r`).
fn render_body(body : Bytes) -> String {
  let out = StringBuilder()
  for byte in body {
    let code = byte.to_int()
    if code == 13 {
      out.write_string("<CR>")
    } else if code == 10 {
      out.write_string("<LF>\n")
    } else if code < 0x20 || code > 0x7e {
      out.write_string("<\{code}>")
    } else {
      out.write_char(code.unsafe_to_char())
    }
  }
  out.to_string()
}

///|
/// Encode parts under the fixed boundary `B` for snapshots.
fn render_parts(parts : Array[@multipart.Part]) -> String raise {
  let (content_type, body) = @multipart.encode(parts, "B")
  assert_eq(content_type, "multipart/form-data; boundary=B")
  render_body(body)
}

///|
test "multipart body layout: payload_json first, files[n], closing delimiter" {
  let files = [
    FileUpload("hello.txt", b"hi there", content_type="text/plain"),
    FileUpload("data.bin", b"\x00\x01\x02"),
  ]
  inspect(
    render_parts(upload_parts("{\"content\":\"see files\"}", files)),
    content=(
      #|--B<CR><LF>
      #|Content-Disposition: form-data; name="payload_json"<CR><LF>
      #|Content-Type: application/json<CR><LF>
      #|<CR><LF>
      #|{"content":"see files"}<CR><LF>
      #|--B<CR><LF>
      #|Content-Disposition: form-data; name="files[0]"; filename="hello.txt"<CR><LF>
      #|Content-Type: text/plain<CR><LF>
      #|<CR><LF>
      #|hi there<CR><LF>
      #|--B<CR><LF>
      #|Content-Disposition: form-data; name="files[1]"; filename="data.bin"<CR><LF>
      #|Content-Type: application/octet-stream<CR><LF>
      #|<CR><LF>
      #|<0><1><2><CR><LF>
      #|--B--<CR><LF>
      #|
    ),
  )
}

///|
test "encode_parts draws another boundary when a part contains the first" {
  let calls = Ref(0)
  // The first candidate is all zeros, the next all `z`s.
  let random = () => {
    calls.val += 1
    if calls.val <= 32 {
      0.0
    } else {
      0.999
    }
  }
  let first = "mbt-sdk-" + "0".repeat(32)
  let file = FileUpload("evil.txt", @utf8.encode("x\r\n--\{first}\r\n"))
  let (content_type, _) = encode_parts(upload_parts("{}", [file]), random~)
  inspect(
    content_type,
    content="multipart/form-data; boundary=mbt-sdk-zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",
  )
  // A source that never escapes the collision gives up instead of looping.
  try encode_parts(upload_parts("{}", [file]), random=() => 0.0) catch {
    Transport(message~) =>
      inspect(message, content="could not choose a multipart boundary")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the boundary search to give up")
  }
}

///|
test "attachments_json carries ids, filenames, and descriptions" {
  json_inspect(
    attachments_json([
      FileUpload("a.png", b"", description="a cat"),
      FileUpload("b.txt", b""),
    ]),
    content=[
      { "id": 0, "filename": "a.png", "description": "a cat" },
      { "id": 1, "filename": "b.txt" },
    ],
  )
}

///|
test "validate_files rejects header-breaking filenames" {
  for bad in ["evil\r\n.txt", "quote\".txt", ""] {
    try validate_files([FileUpload(bad, b"x")]) catch {
      Validation(_) => ()
      e => fail("unexpected error: \{Repr(e)}")
    } noraise {
      _ => fail("expected Validation for \{Repr(bad)}")
    }
  }
  // a normal filename passes
  validate_files([FileUpload("ok.png", b"x")])
}

///|
test "validate_files rejects header-breaking content types" {
  for bad in ["text/plain\r\nx-injected: true", "text/plain\n"] {
    try validate_files([FileUpload("ok.txt", b"x", content_type=bad)]) catch {
      Validation(_) => ()
      e => fail("unexpected error: \{Repr(e)}")
    } noraise {
      _ => fail("expected Validation for \{Repr(bad)}")
    }
  }
  validate_files([FileUpload("ok.txt", b"x", content_type="text/plain")])
}
