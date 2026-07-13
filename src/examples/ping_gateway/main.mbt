///|
/// P0 spike: exercise the whole network stack against the real Discord API
/// before building the library proper.
///
/// Validates, in order:
///   1. HTTPS + JSON against discord.com REST (unauthenticated GET /gateway)
///   2. wss:// WebSocket handshake + Hello frame from the gateway
///   3. heartbeat send / ACK receive
///   4. (with DISCORD_TOKEN) Identify -> READY, dispatch stream
///   5. (with DISCORD_TOKEN + DISCORD_CHANNEL_ID) authenticated REST POST
///
/// Run: DISCORD_TOKEN=... DISCORD_CHANNEL_ID=... moon run src/examples/ping_gateway
/// Both env vars are optional; without them only steps 1-3 run.
const RUN_SECONDS : Int = 30

///|
async fn main {
  // --- 1. REST over TLS, no auth ---
  let (resp, body) = @http.get("https://discord.com/api/v10/gateway")
  println("[rest] GET /gateway -> \{resp.code} \{resp.reason}")
  let gateway_url = match body.json() {
    { "url": String(url), .. } => url
    other => {
      println("[rest] unexpected body: \{other.stringify()}")
      panic()
    }
  }
  println("[rest] gateway url: \{gateway_url}")

  // --- 2. WebSocket handshake + Hello ---
  let conn = @websocket.connect("\{gateway_url}/?v=10&encoding=json")
  println("[ws] connected")
  let hello = conn.recv().read_all().json()
  let heartbeat_interval = match hello {
    {
      "op": Number(10, ..),
      "d": { "heartbeat_interval": Number(iv, ..), .. },
      ..
    } => iv.to_int()
    other => {
      println("[ws] expected Hello, got: \{other.stringify()}")
      panic()
    }
  }
  println("[ws] Hello: heartbeat_interval=\{heartbeat_interval}ms")
  let token = @env.get_env_var("DISCORD_TOKEN")
  let sequence : Ref[Json] = Ref(Json::null())
  @async.with_timeout_opt(RUN_SECONDS * 1000, () => {
    @async.with_task_group((group : @async.TaskGroup[Unit]) => {
      // --- 3. heartbeat task: first beat immediately so we observe an ACK fast ---
      group.spawn_bg(no_wait=true, () => {
        for ;; {
          conn.send_text(
            Json::object({ "op": Json::number(1), "d": sequence.val }).stringify(),
          )
          println("[ws] -> heartbeat")
          @async.sleep(heartbeat_interval)
        }
      })
      // --- 4. identify if we have a token ---
      match token {
        Some(token) => {
          let identify : Json = {
            "op": 2,
            "d": {
              "token": Json::string(token),
              "intents": 513, // GUILDS | GUILD_MESSAGES
              "properties": {
                "os": "linux",
                "browser": "discord.mbt",
                "device": "discord.mbt",
              },
            },
          }
          conn.send_text(identify.stringify())
          println("[ws] -> identify")
        }
        None => println("[ws] DISCORD_TOKEN not set; staying unauthenticated")
      }
      // --- read loop ---
      for ;; {
        let frame = conn.recv().read_all().json()
        match frame {
          { "op": Number(11, ..), .. } => println("[ws] <- heartbeat ACK")
          { "op": Number(0, ..), "t": String(t), "s": s, "d": d, .. } => {
            sequence.val = s
            match t {
              "READY" =>
                if d
                  is {
                    "session_id": String(sid),
                    "resume_gateway_url": String(resume_url),
                    ..
                  } {
                  println("[ws] <- READY session=\{sid} resume=\{resume_url}")
                  match (token, @env.get_env_var("DISCORD_CHANNEL_ID")) {
                    (Some(token), Some(channel)) =>
                      group.spawn_bg(no_wait=true, () => {
                        post_message(token, channel)
                      })
                    _ =>
                      println(
                        "[rest] DISCORD_CHANNEL_ID not set; skipping POST",
                      )
                  }
                }
              _ => println("[ws] <- dispatch \{t}")
            }
          }
          { "op": Number(op, ..), .. } =>
            println("[ws] <- op \{op.to_int()}: \{frame.stringify()}")
          other => println("[ws] <- unexpected: \{other.stringify()}")
        }
      }
    })
  })
  |> ignore
  // --- 5. clean close after the timeout cancels the group ---
  conn.send_close(code=@websocket.CloseCode::Normal) catch {
    _ => println("[ws] close after timeout failed (connection already gone)")
  }
  println("[done] ran \{RUN_SECONDS}s and closed cleanly")
}

///|
async fn post_message(token : String, channel_id : String) -> Unit {
  let payload : Json = { "content": "hello from discord.mbt P0 spike" }
  let (resp, body) = @http.post(
    "https://discord.com/api/v10/channels/\{channel_id}/messages",
    payload,
    headers={
      "Authorization": "Bot \{token}",
      "Content-Type": "application/json",
    },
  )
  println("[rest] POST /channels/\{channel_id}/messages -> \{resp.code}")
  if resp.code >= 400 {
    let text = body.text() catch { _ => "<unreadable>" }
    println("[rest] error body: \{text}")
  }
}
