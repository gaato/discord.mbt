///|
priv struct RecordedExchange {
  meth : String
  path : String
  authorization : String?
  content_type : String?
  body : String
}

///|
/// Serves canned JSON per path on a loopback socket and records every
/// exchange, so tests can pin what `Client::perform` actually put on the wire.
async fn with_recording_server(
  respond : (String) -> (Int, String),
  run : async (Client, Array[RecordedExchange]) -> Unit,
) -> Unit {
  let exchanges : Array[RecordedExchange] = []
  let server = @ahttp.Server(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      server.run_forever(allow_failure=true, (request, body_reader, conn) => {
        exchanges.push({
          meth: @debug.to_string(request.meth),
          path: request.path,
          authorization: request.headers.get("authorization"),
          content_type: request.headers.get("content-type"),
          body: body_reader.read_all().text(),
        })
        let (status, body) = respond(request.path)
        if status == 204 {
          conn.send_response(204, "No Content")
        } else {
          conn.send_response(status, reason_of(status), extra_headers={
            "Content-Type": "application/json",
          })
          conn.write_string(body)
        }
        conn.end_response()
      })
    })
    let client = Client("test-token", base_url="http://\{server.addr}")
    defer client.close()
    run(client, exchanges)
  })
}

///|
fn reason_of(status : Int) -> String {
  match status {
    200 => "OK"
    502 => "Bad Gateway"
    _ => "Status \{status}"
  }
}

///|
async test "mixed-case authorization override wins on the wire" {
  with_recording_server(_ => (200, "{}"), (client, exchanges) => {
    ignore(
      client.request(GetGateway, headers={
        "Authorization": "Bearer oauth-token",
      }),
    )
    guard exchanges is [exchange] else { fail("expected exactly one exchange") }
    guard exchange.authorization is Some(authorization) else {
      fail("expected authorization header")
    }
    inspect(authorization, content="Bearer oauth-token")
  })
}

///|
async test "create guild sticker sends one multipart form with named file" {
  with_recording_server(
    _ => {
      (
        200,
        (
          #|{"id":"900","name":"boing","description":null,"tags":"tag","type":2,"format_type":1}
        ),
      )
    },
    (client, exchanges) => {
      let sticker = client.create_guild_sticker(
        @model.Id::parse("100"),
        FileUpload("boing.png", b"PNGDATA", content_type="image/png"),
        "boing",
        "a description",
        "tag",
      )
      inspect(sticker.name, content="boing")
      guard exchanges is [exchange] else {
        fail("expected exactly one exchange")
      }
      inspect(exchange.meth, content="Post")
      inspect(exchange.path, content="/api/v10/guilds/100/stickers")
      guard exchange.content_type is Some(content_type) else {
        fail("expected a content type")
      }
      assert_true(content_type.has_prefix("multipart/form-data; boundary="))
      assert_true(exchange.body.contains("name=\"name\""))
      assert_true(exchange.body.contains("boing"))
      assert_true(exchange.body.contains("name=\"description\""))
      assert_true(exchange.body.contains("name=\"tags\""))
      assert_true(
        exchange.body.contains("name=\"file\"; filename=\"boing.png\""),
      )
      assert_true(exchange.body.contains("PNGDATA"))
      assert_false(exchange.body.contains("payload_json"))
    },
  )
}

///|
async test "create channel invite ships target users next to payload json" {
  with_recording_server(
    _ => {
      (
        200,
        (
          #|{"code":"moon"}
        ),
      )
    },
    (client, exchanges) => {
      let invite = client.create_channel_invite(
        @model.Id::parse("400"),
        max_age=60,
        target_users_file=FileUpload(
          "targets.csv",
          b"123456789012345678",
          content_type="text/csv",
        ),
      )
      inspect(invite.code, content="moon")
      guard exchanges is [exchange] else {
        fail("expected exactly one exchange")
      }
      inspect(exchange.meth, content="Post")
      inspect(exchange.path, content="/api/v10/channels/400/invites")
      guard exchange.content_type is Some(content_type) else {
        fail("expected a content type")
      }
      assert_true(content_type.has_prefix("multipart/form-data; boundary="))
      assert_true(exchange.body.contains("name=\"payload_json\""))
      assert_true(exchange.body.contains("\"max_age\":60"))
      assert_true(
        exchange.body.contains(
          "name=\"target_users_file\"; filename=\"targets.csv\"",
        ),
      )
    },
  )
}

///|
async test "update invite target users sends only the named file part" {
  with_recording_server(_ => (204, ""), (client, exchanges) => {
    client.update_invite_target_users(
      "moon",
      FileUpload("targets.csv", b"123456789012345678", content_type="text/csv"),
    )
    guard exchanges is [exchange] else { fail("expected exactly one exchange") }
    inspect(exchange.path, content="/api/v10/invites/moon/target-users")
    assert_true(
      exchange.body.contains(
        "name=\"target_users_file\"; filename=\"targets.csv\"",
      ),
    )
    assert_false(exchange.body.contains("payload_json"))
  })
}

///|
async test "plain json requests round-trip and non-json error bodies surface" {
  with_recording_server(
    path => {
      if path.contains("/channels/400/messages") {
        (
          200,
          (
            #|{"id":"500","channel_id":"400","author":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"content":"hi","timestamp":"2024-01-02T03:04:05.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
          ),
        )
      } else {
        (502, "<html>bad gateway</html>")
      }
    },
    (client, exchanges) => {
      // JSON-body arm.
      let message = client.create_message(@model.Id::parse("400"), content="hi")
      inspect(message.content, content="hi")
      guard exchanges is [posted] else { fail("expected one exchange so far") }
      inspect(posted.content_type, content="Some(application/json)")
      assert_true(posted.body.contains("\"content\":\"hi\""))

      // Body-less arm plus the non-JSON error body fallback: the HTML page
      // must survive into the Api error message instead of collapsing to null.
      try client.get_channel(@model.Id::parse("400")) catch {
        Api(status=502, error~) =>
          inspect(error.message, content="HTTP 502: <html>bad gateway</html>")
        other => fail("unexpected error \{other}")
      } noraise {
        _ => fail("expected a 502 Api error")
      }
      guard exchanges is [_, fetched] else {
        fail("expected a second exchange")
      }
      inspect(fetched.meth, content="Get")
      inspect(fetched.path, content="/api/v10/channels/400")
    },
  )
}
