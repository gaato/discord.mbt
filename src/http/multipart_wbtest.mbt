///|
/// Render body chunks with CR/LF and non-printable bytes made visible, so
/// the snapshot stays faithful (`#|` strings cannot hold raw `\r`).
fn render_parts(parts : Array[MultipartChunk]) -> String {
  let out = StringBuilder()
  fn put(code : Int) {
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

  for part in parts {
    match part {
      Text(text) =>
        for ch in text {
          put(ch.to_int())
        }
      Blob(bytes) =>
        for byte in bytes {
          put(byte.to_int())
        }
    }
  }
  out.to_string()
}

///|
test "multipart body layout: payload_json first, files[n], closing delimiter" {
  let files = [
    FileUpload("hello.txt", b"hi there", content_type="text/plain"),
    FileUpload("data.bin", b"\x00\x01\x02"),
  ]
  let parts = multipart_parts("B", "{\"content\":\"see files\"}", files)
  inspect(
    render_parts(parts),
    content=(
      #|--B<CR><LF>
      #|content-disposition: form-data; name="payload_json"<CR><LF>
      #|content-type: application/json<CR><LF>
      #|<CR><LF>
      #|{"content":"see files"}<CR><LF>
      #|--B<CR><LF>
      #|content-disposition: form-data; name="files[0]"; filename="hello.txt"<CR><LF>
      #|content-type: text/plain<CR><LF>
      #|<CR><LF>
      #|hi there<CR><LF>
      #|--B<CR><LF>
      #|content-disposition: form-data; name="files[1]"; filename="data.bin"<CR><LF>
      #|content-type: application/octet-stream<CR><LF>
      #|<CR><LF>
      #|<0><1><2><CR><LF>
      #|--B--<CR><LF>
      #|
    ),
  )
}

///|
test "fresh_boundary skips candidates that appear in a part" {
  // no collision: first candidate wins
  inspect(fresh_boundary("seed", "{}", []), content="discordmbt-seed-0")
  // the payload embeds candidate 0, a file embeds candidate 1
  let files = [FileUpload("evil.txt", b"...discordmbt-seed-1...")]
  inspect(
    fresh_boundary("seed", "{\"content\":\"discordmbt-seed-0\"}", files),
    content="discordmbt-seed-2",
  )
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
