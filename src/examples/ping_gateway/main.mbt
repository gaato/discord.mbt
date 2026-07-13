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
  let token = @env.get_env_var("DISCORD_TOKEN")
  let client = @dhttp.Client::new(token.unwrap_or(""))
  // --- 1. REST over TLS through the library client (rate limited, pooled) ---
  let gateway_url = client.get_gateway()
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
                  match @env.get_env_var("DISCORD_CHANNEL_ID") {
                    Some(channel) =>
                      group.spawn_bg(no_wait=true, () => {
                        post_message(client, channel)
                      })
                    None =>
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
async fn post_message(client : @dhttp.Client, channel_id : String) -> Unit {
  let channel_id : @model.ChannelId = @model.Id::parse(channel_id) catch {
    _ => {
      println("[rest] DISCORD_CHANNEL_ID is not a snowflake")
      return
    }
  }
  let message = client.create_message(
    channel_id,
    content="hello from discord.mbt (typed client)",
  ) catch {
    e => {
      println("[rest] create_message failed: \{to_repr(e)}")
      return
    }
  }
  println("[rest] created message id=\{message.id} in #\{message.channel_id}")
}
