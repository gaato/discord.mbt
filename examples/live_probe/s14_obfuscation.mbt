///|
/// Channel obfuscation: hide one channel of every type the guild allows from
/// the bot, connect with the CHANNEL_OBFUSCATION capability, and record what
/// Discord sends for them (the GUILD_CREATE entries, then the CHANNEL_UPDATEs
/// when the bot regains and loses access) in the payload log, so the decoding
/// tests can use real payloads.
///
/// The channels deny VIEW_CHANNEL to @everyone and allow it to a probe role.
/// The bot holds that role while creating them and drops it to lose sight of
/// them; it takes the role back before deleting them. An administrator sees
/// every channel, so with an ADMINISTRATOR bot role this records full
/// payloads only and reports ENV-LIMITED.
async fn sec_obfuscation(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let hidden : Map[@model.ChannelId, String] = Map([])
  let mut viewer : @model.RoleId? = None
  try {
    let everyone : @model.RoleId = g.cast()
    let roles = c.get_guild_roles(g)
    let me = c.get_guild_member(g, p.bot_id)
    let administrator = roles
      .iter()
      .any(role => {
        (role.id == everyone || me.roles.contains(role.id)) &&
        role.permissions.contains(@model.Permissions::administrator())
      })
    let role = c.create_guild_role(
      g,
      name="probe-obfuscation-viewer",
      permissions=@model.Permissions::none(),
      audit_reason="live probe obfuscation",
    )
    viewer = Some(role.id)
    c.add_member_role(g, p.bot_id, role.id, audit_reason="live probe")
    let overwrites : Array[@model.Overwrite] = [
      {
        id: everyone.cast(),
        typ: Role,
        allow: @model.Permissions::none(),
        deny: @model.Permissions::view_channel(),
      },
      {
        id: role.id.cast(),
        typ: Role,
        allow: @model.Permissions::view_channel(),
        deny: @model.Permissions::none(),
      },
    ]
    // A category stays visible while any child is, so every child is hidden.
    let category = c.create_guild_channel(
      g,
      "probe-hidden",
      typ=GuildCategory,
      permission_overwrites=overwrites,
    )
    hidden[category.id] = "category"
    let kinds : Array[(String, @model.ChannelType, Bool)] = [
      ("text", GuildText, false),
      ("voice", GuildVoice, false),
      ("forum", GuildForum, false),
      ("stage", GuildStageVoice, true),
      ("media", GuildMedia, true),
      ("announcement", GuildAnnouncement, true),
    ]
    for kind in kinds {
      let (label, typ, needs_community) = kind
      if needs_community && !p.s.community_enabled {
        p.push("obfuscation: create hidden \{label}", Skip, "needs COMMUNITY")
        continue
      }
      p.probe_env("obfuscation: create hidden \{label}", () => {
        let channel = c.create_guild_channel(
          g,
          "probe-hidden-\{label}",
          typ~,
          parent_id=category.id,
          permission_overwrites=overwrites,
        )
        hidden[channel.id] = label
        "id=\{channel.id}"
      })
    }
    c.remove_member_role(g, p.bot_id, role.id, audit_reason="live probe")
    p.probe("obfuscation: get_guild_channels with hidden channels", () => {
      let listed = c.get_guild_channels(g).filter(ch => hidden.contains(ch.id))
      "hidden channels listed=\{listed.length()}/\{hidden.length()}"
    })
    obfuscation_gateway(p, hidden, role.id, administrator~)
  } catch {
    err => p.push("obfuscation section", Fail, describe(err))
  }
  // Take the role back so the bot can see, and so delete, the channels.
  if viewer is Some(role) {
    c.add_member_role(g, p.bot_id, role) catch {
      _ => ()
    }
  }
  // Children first: Discord keeps a category's children when it is deleted.
  let order = hidden.to_array().filter(entry => entry.1 != "category") +
    hidden.to_array().filter(entry => entry.1 == "category")
  for entry in order {
    let (id, label) = entry
    p.probe("cleanup: delete hidden \{label}", () => {
      ignore(c.delete_channel(id, audit_reason="live probe cleanup"))
      "id=\{id}"
    })
  }
  if viewer is Some(role) {
    p.probe("cleanup: delete obfuscation viewer role", () => {
      c.delete_guild_role(g, role, audit_reason="live probe cleanup")
      "ok"
    })
  }
}

///|
/// The gateway half of `sec_obfuscation`: a shard without transport
/// compression whose transport records the raw channel payloads.
async fn obfuscation_gateway(
  p : P,
  hidden : Map[@model.ChannelId, String],
  viewer : @model.RoleId,
  administrator~ : Bool,
) -> Unit {
  let c = p.client
  let g = p.guild_id
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  let gateway_url = c.get_gateway()
  let ids : Map[String, Unit] = Map([])
  for id in hidden.keys() {
    ids[id.to_string()] = ()
  }
  let guild = g.to_string()
  let record = (text : String) => {
    let frame : Json = @json.parse(text) catch { _ => return }
    guard frame is Object({ "t": String(t), "d": Object(d) as payload, .. }) else {
      return
    }
    if t == "GUILD_CREATE" && d.get("id") is Some(String(id)) && id == guild {
      guard d.get("channels") is Some(Array(channels)) else { return }
      // Only the probe's channels: the rest of GUILD_CREATE is not channel
      // data, and other channels are not the probe's to record.
      for channel in channels {
        if channel is Object({ "id": String(id), .. }) && ids.contains(id) {
          let line : Json = { "gateway": "GUILD_CREATE", "channel": channel }
          p.payloads.push(line.stringify())
        }
      }
    } else if t.has_prefix("CHANNEL_") &&
      d.get("id") is Some(String(id)) &&
      ids.contains(id) {
      let line : Json = { "gateway": t, "channel": payload }
      p.payloads.push(line.stringify())
    }
  }
  @async.with_timeout_opt(90_000, () => {
    @async.with_task_group((group : @async.TaskGroup) => {
      let shard = @gateway.Shard::start(
        group,
        token~,
        intents=@model.Intents::guilds(),
        capabilities=@model.GatewayCapabilities::channel_obfuscation(),
        gateway_url~,
        connector=url => {
          let inner = @gateway.connect_websocket(url)
          RecordingTransport::{ inner, on_text: record, }
        },
      )
      p.probe_env("obfuscation: GUILD_CREATE with hidden channels", () => {
        for ;; {
          match shard.next() {
            Dispatch(GuildCreate(Available(created))) if created.guild.id == g => {
              let by_type = obfuscated_by_type(
                created.channels.filter(ch => hidden.contains(ch.id)),
                hidden,
              )
              if administrator {
                raise ProbeError(
                  "the bot role has ADMINISTRATOR, so no channel is hidden from it (\{by_type})",
                )
              }
              return by_type
            }
            Dispatch(Unknown(t~, ..)) if t.has_prefix("DECODE_ERROR") =>
              fail("GUILD_CREATE failed to decode: \{t}")
            FatallyClosed(code~) => fail("fatally closed code=\{code}")
            _ => ()
          }
        }
      })
      // Regaining access: Discord documents a CHANNEL_UPDATE with full data.
      c.add_member_role(g, p.bot_id, viewer, audit_reason="live probe")
      p.probe_env("obfuscation: CHANNEL_UPDATE on regaining access", () => {
        await_channel_updates(shard, hidden, want_obfuscated=false)
      })
      // Losing access again: whatever Discord sends is recorded.
      c.remove_member_role(g, p.bot_id, viewer, audit_reason="live probe")
      p.probe_env("obfuscation: CHANNEL_UPDATE on losing access", () => {
        await_channel_updates(shard, hidden, want_obfuscated=true)
      })
      shard.close()
      group.return_immediately()
    })
  })
  |> ignore
}

///|
/// Waits up to 10 s for a CHANNEL_UPDATE of every hidden channel and checks
/// whether each is obfuscated.
async fn await_channel_updates(
  shard : @gateway.Shard,
  hidden : Map[@model.ChannelId, String],
  want_obfuscated~ : Bool,
) -> String {
  let seen : Array[@model.Channel] = []
  let done = @async.with_timeout_opt(10_000, () => {
    while seen.length() < hidden.length() {
      match shard.next() {
        Dispatch(ChannelUpdate(channel)) if hidden.contains(channel.id) &&
          !seen.iter().any(ch => ch.id == channel.id) => seen.push(channel)
        Dispatch(Unknown(t~, ..)) if t.has_prefix("DECODE_ERROR") =>
          // A decode failure is a defect, not the environment: FAIL, as the
          // GUILD_CREATE wait above reports it.
          fail("CHANNEL_UPDATE failed to decode: \{t}")
        _ => ()
      }
    }
  })
  let wrong = seen.filter(ch => ch.is_obfuscated() != want_obfuscated)
  let note = "updates=\{seen.length()}/\{hidden.length()} \{obfuscated_by_type(seen, hidden)}"
  if wrong.length() > 0 {
    raise ProbeError(
      "\{wrong.length()} with obfuscated!=\{want_obfuscated}; \{note}",
    )
  }
  if done is None {
    raise ProbeError("timed out; \{note}")
  }
  note
}

///|
fn obfuscated_by_type(
  channels : Array[@model.Channel],
  hidden : Map[@model.ChannelId, String],
) -> String {
  channels
  .map(ch => {
    let label = hidden.get(ch.id).unwrap_or("type \{ch.typ.to_int()}")
    if ch.is_obfuscated() {
      "\{label}:obfuscated"
    } else {
      "\{label}:full"
    }
  })
  .join(" ")
}

///|
/// A gateway transport that hands every text frame to `on_text` before the
/// shard parses it.
struct RecordingTransport {
  inner : &@gateway.GatewayTransport
  on_text : (String) -> Unit
}

///|
impl @gateway.GatewayTransport for RecordingTransport with fn recv(self) {
  let frame = self.inner.recv()
  if frame is Text(text) {
    (self.on_text)(text)
  }
  frame
}

///|
impl @gateway.GatewayTransport for RecordingTransport with fn send(self, text) {
  self.inner.send(text)
}

///|
impl @gateway.GatewayTransport for RecordingTransport with fn close(self, code~) {
  self.inner.close(code~)
}
