///|
/// Base channel tree used by every later section.
async fn sec_base_channels(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  p.probe("create_guild_channel (category)", () => {
    let ch = c.create_guild_channel(
      g,
      "live-probe",
      typ=GuildCategory,
      audit_reason="live probe",
    )
    p.s.category = Some(ch.id)
    "id=\{ch.id}"
  })
  p.probe("GuildRef::create_channel (text)", () => {
    let ch = c
      .guild_ref(g)
      .create_channel(
        "probe-text",
        typ=GuildText,
        topic="live probe main text channel",
        parent_id?=p.s.category,
      )
    p.s.text = Some(ch.id)
    "id=\{ch.id}"
  })
  p.probe("create_guild_channel (text2)", () => {
    let ch = c.create_guild_channel(
      g,
      "probe-text-2",
      typ=GuildText,
      parent_id?=p.s.category,
    )
    p.s.text2 = Some(ch.id)
    "id=\{ch.id}"
  })
  p.probe("create_guild_channel (voice)", () => {
    let ch = c.create_guild_channel(
      g,
      "probe-voice",
      typ=GuildVoice,
      parent_id?=p.s.category,
      bitrate=64000,
      user_limit=5,
    )
    p.s.voice = Some(ch.id)
    "id=\{ch.id}"
  })
  // Stage and media channels require the COMMUNITY feature, which sec_guild
  // enables; they are created there.
  p.probe("create_guild_channel (forum)", () => {
    let ch = c.create_guild_channel(
      g,
      "probe-forum",
      typ=GuildForum,
      topic="forum guidelines here",
      parent_id?=p.s.category,
    )
    p.s.forum = Some(ch.id)
    "id=\{ch.id}"
  })
  guard p.s.text is Some(text) else { return }
  p.probe("get_channel", () => {
    let ch = c.get_channel(text)
    "name=\{optnul(ch.name)}"
  })
  p.probe("ChannelRef::fetch", () => {
    let ch = c.channel_ref(text).fetch()
    "type=\{ch.typ.to_int()}"
  })
  p.probe("modify_channel (topic)", () => {
    let ch = c.modify_channel(text, topic="updated by live probe")
    "topic=\{optnul(ch.topic)}"
  })
  p.probe("ChannelRef::edit (rate limit)", () => {
    let ch = c.channel_ref(text).edit(rate_limit_per_user=1)
    ignore(ch)
    let restored = c.channel_ref(text).edit(rate_limit_per_user=0)
    "rate_limit=\{restored.rate_limit_per_user.unwrap_or(-1)}"
  })
  p.probe("get_guild_channels", () => {
    let chans = c.get_guild_channels(g)
    "count=\{chans.length()}"
  })
  p.probe("modify_guild_channel_positions", () => {
    let pos = @dhttp.GuildChannelPosition(text, position=1)
    c.modify_guild_channel_positions(g, [pos])
    "ok"
  })
  p.probe("edit_channel_permissions (deny send for @everyone)", () => {
    // @everyone role id == guild id
    let everyone : @model.GenericId = @model.Id(p.guild_id.value())
    c.edit_channel_permissions(
      text,
      everyone,
      @model.Permissions::none(),
      @model.Permissions::send_messages(),
      0,
      audit_reason="live probe overwrite",
    )
    "ok"
  })
  p.probe("delete_channel_permission", () => {
    let everyone : @model.GenericId = @model.Id(p.guild_id.value())
    c.delete_channel_permission(text, everyone)
    "ok"
  })
  p.probe("trigger_typing", () => {
    c.trigger_typing(text)
    "ok"
  })
  p.probe("ChannelRef::typing", () => {
    c.channel_ref(text).typing()
    "ok"
  })
  p.probe_env("set_voice_channel_status", () => {
    let vc = need(p.s.voice, "voice channel")
    c.set_voice_channel_status(vc, status="probing")
    "ok"
  })
  p.probe("create_channel_invite", () => {
    let invite = c.create_channel_invite(text, max_age=3600, max_uses=1)
    "code set=\{invite.code != ""}"
  })
  p.probe("ChannelRef::create_invite + InviteRef::fetch/delete", () => {
    let invite = c.channel_ref(text).create_invite(max_age=3600, unique=true)
    let fetched = c.invite_ref(invite.code).fetch(with_counts=true)
    ignore(fetched)
    let deleted = c.invite_ref(invite.code).delete(reason="live probe cleanup")
    "code=\{deleted.code}"
  })
  p.probe("get_channel_invites", () => {
    let invites = c.get_channel_invites(text)
    "count=\{invites.length()}"
  })
  p.probe("get_guild_invites", () => {
    let invites = c.get_guild_invites(g)
    "count=\{invites.length()}"
  })
  p.probe("get_invite + delete_invite (client)", () => {
    let invite = c.create_channel_invite(text, max_age=3600)
    let fetched = c.get_invite(invite.code, with_counts=true)
    ignore(fetched)
    let deleted = c.delete_invite(invite.code, audit_reason="cleanup")
    "code=\{deleted.code}"
  })
  p.probe_err(
    "group_dm_add_recipient (bot tokens cannot)",
    expect=[400, 401, 403, 404],
    () => c.group_dm_add_recipient(text, p.owner_id, "bogus-access-token"),
  )
  p.probe_err("group_dm_remove_recipient", expect=[400, 401, 403, 404], () => {
    c.group_dm_remove_recipient(text, p.owner_id)
  })
}
