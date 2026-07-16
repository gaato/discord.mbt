///|
/// Gateway: connect a shard, presence update, voice-state join (which unlocks
/// the REST voice-state endpoints and soundboard send), request guild
/// members. The member request runs last: without the privileged
/// GUILD_MEMBERS intent Discord may close the connection.
async fn sec_gateway(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  let gateway_url = c.get_gateway() catch {
    err => {
      p.push("gateway section", Fail, describe(err))
      return
    }
  }
  try
    @async.with_timeout_opt(120_000, () => {
      @async.with_task_group((group : @async.TaskGroup[Unit]) => {
        let shard = @gateway.Shard::start(
          group,
          token~,
          intents=intents_union([
            @model.Intents::guilds(),
            @model.Intents::guild_members(),
            @model.Intents::guild_voice_states(),
            @model.Intents::guild_messages(),
          ]),
          gateway_url~,
        )
        // Wait for READY.
        let mut ready = false
        while !ready {
          match shard.next() {
            Dispatch(Ready(r)) => {
              p.push("gateway connect + READY", Pass, "user=\{r.user.username}")
              ready = true
            }
            FatallyClosed(code~) => {
              p.push(
                "gateway connect + READY",
                Fail,
                "fatally closed code=\{code}",
              )
              return
            }
            _ => ()
          }
        }
        p.probe("gateway latency (heartbeat ack)", () => {
          // Latency appears after the first heartbeat ack; wait briefly.
          for _ in 0..<20 {
            if shard.latency_ms() is Some(ms) {
              return "latency=\{ms}ms"
            }
            @async.sleep(500)
          }
          "no ack yet (still fine)"
        })
        p.probe("gateway presence update (op 3)", () => {
          shard.send({
            "op": 3,
            "d": {
              "since": Json::null(),
              "activities": [{ "name": "live probe", "type": 0 }],
              "status": "online",
              "afk": false,
            },
          })
          "sent"
        })
        // Voice join via op 4, then REST voice-state endpoints.
        let vc = p.s.voice
        p.probe("gateway voice state update (join voice)", () => {
          let vc = need(vc, "voice channel")
          shard.send({
            "op": 4,
            "d": {
              "guild_id": "\{g}",
              "channel_id": "\{vc}",
              "self_mute": false,
              "self_deaf": false,
            },
          })
          // Confirm via the dispatch stream (time-bounded).
          let confirmed = @async.with_timeout_opt(10_000, () => {
            for ;; {
              match shard.next() {
                Dispatch(VoiceStateUpdate(state)) =>
                  if state.user_id == p.bot_id && state.channel_id is Value(_) {
                    break
                  }
                _ => ()
              }
            }
            "joined \{vc}"
          })
          match confirmed {
            Some(note) => note
            None => raise ProbeError("no VoiceStateUpdate within 10s")
          }
        })
        p.probe("get_current_user_voice_state + GuildRef::my_voice_state", () => {
          let state = c.get_current_user_voice_state(g)
          ignore(c.guild_ref(g).my_voice_state())
          "channel=\{state.channel_id |> nul}"
        })
        p.probe("get_user_voice_state (bot via user route)", () => {
          let state = c.get_user_voice_state(g, p.bot_id)
          ignore(c.member_ref(g, p.bot_id).voice_state())
          "channel=\{state.channel_id |> nul}"
        })
        p.probe("send_soundboard_sound (bot now in voice)", () => {
          let sound = need(p.s.sound, "sound")
          let vc = need(vc, "voice channel")
          c.send_soundboard_sound(vc, sound)
          "ok"
        })
        p.probe("ChannelRef::send_soundboard_sound", () => {
          let sound = need(p.s.sound, "sound")
          let vc = need(vc, "voice channel")
          c.channel_ref(vc).send_soundboard_sound(sound)
          "ok"
        })
        // Move to the stage channel to exercise stage voice-state endpoints.
        p.probe_env("modify_current_user_voice_state (stage suppress)", () => {
          let stage = need(p.s.stage, "stage channel")
          shard.send({
            "op": 4,
            "d": {
              "guild_id": "\{g}",
              "channel_id": "\{stage}",
              "self_mute": false,
              "self_deaf": false,
            },
          })
          @async.sleep(2000)
          c.modify_current_user_voice_state(g, channel_id=stage, suppress=true)
          "ok"
        })
        p.probe_env("modify_user_voice_state (bot on stage)", () => {
          let stage = need(p.s.stage, "stage channel")
          c.modify_user_voice_state(g, p.bot_id, stage, suppress=true)
          "ok"
        })
        p.probe("gateway voice state update (leave voice)", () => {
          shard.send({
            "op": 4,
            "d": {
              "guild_id": "\{g}",
              "channel_id": Json::null(),
              "self_mute": false,
              "self_deaf": false,
            },
          })
          "sent"
        })
        // Last: request guild members (may need privileged intent).
        p.probe_env("gateway request guild members (op 8)", () => {
          shard.send({
            "op": 8,
            "d": {
              "guild_id": "\{g}",
              "query": "",
              "limit": 1,
              "nonce": "live-probe",
            },
          })
          let mut count = -1
          let result = @async.with_timeout_opt(10_000, () => {
            for ;; {
              match shard.next() {
                Dispatch(GuildMembersChunk(chunk)) => {
                  count = chunk.members.length()
                  break
                }
                FatallyClosed(code~) =>
                  raise ProbeError(
                    "closed code=\{code} (likely missing intent)",
                  )
                _ => ()
              }
            }
          })
          match result {
            Some(_) => "members=\{count}"
            None => raise ProbeError("no GuildMembersChunk within 10s")
          }
        })
        shard.close()
        group.return_immediately(())
      })
    })
    |> ignore
  catch {
    err => p.push("gateway section", Fail, describe(err))
  }
}

///|
/// Union without assuming a bitor operator on Intents.
fn intents_union(list : Array[@model.Intents]) -> @model.Intents {
  let mut bits = 0U
  for intent in list {
    bits = bits | intent.bits()
  }
  @model.Intents::from_bits(bits)
}
