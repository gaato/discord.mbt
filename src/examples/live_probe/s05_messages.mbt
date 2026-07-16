///|
/// Messages, reactions, pins, bulk delete, announcement/crosspost/follow,
/// polls (created via the raw-route escape hatch, exercised via typed calls).
async fn sec_messages(p : P) -> Unit {
  let c = p.client
  let text = need(p.s.text, "text channel") catch {
    _ => {
      p.push("messages section", Skip, "no text channel")
      return
    }
  }
  p.probe("create_message (content)", () => {
    // The nonce must be unique per run: enforce_nonce dedupes across runs and
    // can resurrect a deleted message (observed as a 404 on create).
    let msg = c.create_message(
      text,
      content="live probe: plain message",
      nonce=Str("live-probe-\{now_ms()}"),
      enforce_nonce=true,
    )
    p.s.message = Some(msg.id)
    "id=\{msg.id}"
  })
  p.probe("create_message (embeds + components + allowed_mentions)", () => {
    let embed : @model.Embed = {
      title: Some("live probe"),
      typ: None,
      url: None,
      description: Some("embed body"),
      timestamp: Some(iso8601(now_ms())),
      color: Some(0x5865F2),
      footer: None,
      image: None,
      thumbnail: None,
      video: None,
      provider: None,
      author: None,
      fields: Some([{ name: "field", value: "value", inline: Some(true) }]),
      flags: None,
    }
    let button : @model.Button = {
      id: None,
      style: Primary,
      label: Some("probe"),
      emoji: None,
      custom_id: Some("live_probe_button"),
      sku_id: None,
      url: None,
      disabled: None,
    }
    let row : @model.Component = ActionRow({
      id: None,
      components: [Button(button)],
    })
    let msg = c.create_message(
      text,
      content="embed + button",
      embeds=[embed],
      components=[row],
      allowed_mentions=@model.AllowedMentions::none(),
      flags=@model.MessageFlags::suppress_notifications(),
    )
    "id=\{msg.id} embeds=\{msg.embeds.length()}"
  })
  p.probe("create_message (file upload)", () => {
    let file = @dhttp.FileUpload(
      "probe.txt",
      b"hello from live probe\n",
      content_type="text/plain",
      description="test attachment",
    )
    let msg = c.create_message(text, content="with attachment", files=[file])
    "attachments=\{msg.attachments.length()}"
  })
  p.probe("create_message (sticker)", () => {
    let sticker = need(p.s.sticker, "sticker")
    let msg = c.create_message(text, sticker_ids=[sticker])
    "stickers=\{msg.sticker_items.map_or(0, s => s.length())}"
  })
  p.probe("ChannelRef::send + MessageRef::reply", () => {
    let msg = c.channel_ref(text).send(content="handle layer send")
    let reply = c.message_ref(text, msg.id).reply(content="handle layer reply")
    "reply=\{reply.id}"
  })
  guard p.s.message is Some(mid) else { return }
  p.probe("get_message", () => {
    let msg = c.get_message(text, mid)
    "content len=\{msg.content.length()}"
  })
  p.probe("MessageRef::fetch", () => {
    let msg = c.message_ref(text, mid).fetch()
    "id=\{msg.id}"
  })
  p.probe("edit_message", () => {
    let msg = c.edit_message(text, mid, content="live probe: edited")
    "edited=\{msg.edited_timestamp is Value(_)}"
  })
  p.probe("edit_message (keep_attachments merge + clear)", () => {
    let msg = c.create_message(text, content="attachment edit target", files=[
      @dhttp.FileUpload("one.txt", b"one", content_type="text/plain"),
      @dhttp.FileUpload("two.txt", b"two", content_type="text/plain"),
    ])
    let keep : @model.AttachmentRequest = {
      id: msg.attachments[0].id,
      filename: None,
      title: None,
      description: Some("kept by probe"),
      duration_secs: None,
      waveform: None,
      is_spoiler: None,
    }
    let merged = c
      .message_ref(text, msg.id)
      .edit(keep_attachments=[keep], files=[
        @dhttp.FileUpload("three.txt", b"three", content_type="text/plain"),
      ])
    let cleared = c.edit_message(text, msg.id, keep_attachments=[])
    c.delete_message(text, msg.id)
    "merged=\{merged.attachments.length()} cleared=\{cleared.attachments.length()}"
  })
  p.probe("MessageRef::forward (message_reference type=FORWARD)", () => {
    let target = need(p.s.text2, "second text channel")
    let src = c.create_message(text, content="forward source")
    let forwarded = c.message_ref(text, src.id).forward(target)
    c.delete_message(target, forwarded.id)
    c.delete_message(text, src.id)
    "id=\{forwarded.id}"
  })
  p.probe("create_message (shared_client_theme)", () => {
    let msg = c.create_message(text, content="themed", shared_client_theme={
      colors: ["5865F2", "EB459E"],
      gradient_angle: 45,
      base_mix: 58,
      base_theme: None,
    })
    c.delete_message(text, msg.id)
    "theme=\{msg.shared_client_theme is Some(_)}"
  })
  p.probe("get_channel_messages + paginate_messages", () => {
    let msgs = c.get_channel_messages(text, limit=10)
    let paged = c.paginate_messages(text, page_size=2).collect(max=5)
    "list=\{msgs.length()} paged=\{paged.length()}"
  })
  // Reactions: unicode + the custom emoji created earlier.
  p.probe("create_reaction (unicode)", () => {
    c.create_reaction(text, mid, "🔥")
    "ok"
  })
  p.probe("create_reaction (custom emoji)", () => {
    let id = need(p.s.emoji, "custom emoji")
    c.create_reaction(text, mid, "\{p.s.emoji_name}:\{id}")
    "ok"
  })
  p.probe("get_reactions (normal + burst type)", () => {
    let users = c.get_reactions(text, mid, "🔥", limit=5)
    let normal = c.get_reactions(text, mid, "🔥", typ=Normal)
    let burst = c.get_reactions(text, mid, "🔥", typ=Burst)
    "users=\{users.length()} normal=\{normal.length()} burst=\{burst.length()}"
  })
  p.probe("MessageRef::react/reactions/unreact", () => {
    let r = c.message_ref(text, mid)
    r.react("👀")
    let users = r.reactions("👀")
    r.unreact("👀")
    "users=\{users.length()}"
  })
  p.probe("delete_own_reaction", () => {
    c.create_reaction(text, mid, "🎯")
    c.delete_own_reaction(text, mid, "🎯")
    "ok"
  })
  p.probe("delete_user_reaction (bot's own via user route)", () => {
    c.create_reaction(text, mid, "🎲")
    c.delete_user_reaction(text, mid, "🎲", p.bot_id)
    "ok"
  })
  p.probe("delete_all_reactions_for_emoji", () => {
    c.delete_all_reactions_for_emoji(text, mid, "🔥")
    "ok"
  })
  p.probe("delete_all_reactions", () => {
    c.delete_all_reactions(text, mid)
    "ok"
  })
  // Pins
  p.probe("pin_message / get_pinned_messages / unpin_message", () => {
    c.pin_message(text, mid, audit_reason="live probe pin")
    let pins = c.get_pinned_messages(text)
    c.unpin_message(text, mid)
    "pins=\{pins.length()}"
  })
  p.probe("MessageRef::pin/unpin + ChannelRef::pins", () => {
    let r = c.message_ref(text, mid)
    r.pin()
    let pins = c.channel_ref(text).pins()
    r.unpin()
    "pins=\{pins.length()}"
  })
  // Bulk delete
  p.probe("bulk_delete_messages", () => {
    let a = c.create_message(text, content="bulk 1")
    let b = c.create_message(text, content="bulk 2")
    c.bulk_delete_messages(text, [a.id, b.id], audit_reason="live probe bulk")
    "ok"
  })
  p.probe("delete_message", () => {
    let msg = c.create_message(text, content="delete me")
    c.delete_message(text, msg.id, audit_reason="live probe delete")
    "ok"
  })
  p.probe("create_message (poll) + get_poll_answer_voters + expire_poll", () => {
    let msg = c.create_message(text, poll={
      question: { text: Some("live probe poll?"), emoji: None },
      answers: [
        { text: Some("yes"), emoji: None },
        { text: Some("no"), emoji: None },
      ],
      duration: Some(1),
      allow_multiselect: Some(false),
      layout_type: None,
    })
    let voters = c.get_poll_answer_voters(text, msg.id, 1, limit=5)
    let paged = c
      .paginate_poll_answer_voters(text, msg.id, 1, page_size=2)
      .collect(max=3)
    ignore(paged)
    let expired = c.expire_poll(text, msg.id)
    ignore(expired)
    "voters=\{voters.users.length()} poll=\{msg.poll is Some(_)}"
  })
  p.probe("MessageRef::expire_poll (second poll via ChannelRef::send)", () => {
    let msg = c
      .channel_ref(text)
      .send(poll={
        question: { text: Some("second poll?"), emoji: None },
        answers: [{ text: Some("sure"), emoji: None }],
        duration: Some(1),
        allow_multiselect: None,
        layout_type: None,
      })
    let expired = c.message_ref(text, msg.id).expire_poll()
    "id=\{expired.id}"
  })
  // Announcement channel + crosspost + follow (needs COMMUNITY).
  p.probe_env("create_guild_channel (announcement)", () => {
    let ch = c.create_guild_channel(
      p.guild_id,
      "probe-news",
      typ=GuildAnnouncement,
      parent_id?=p.s.category,
    )
    p.s.announcement = Some(ch.id)
    "id=\{ch.id}"
  })
  p.probe_env("crosspost_message", () => {
    let news = need(p.s.announcement, "announcement channel")
    let msg = c.create_message(news, content="live probe announcement")
    let crossposted = c.crosspost_message(news, msg.id)
    "flags=\{crossposted.flags.map_or(0UL, f => f.bits())}"
  })
  p.probe_env("follow_announcement_channel", () => {
    let news = need(p.s.announcement, "announcement channel")
    let target = need(p.s.text2, "follow target channel")
    let followed = c.follow_announcement_channel(news, target)
    // Clean up the follower webhook so cleanup section stays simple.
    c.delete_webhook(followed.webhook_id, audit_reason="live probe cleanup") catch {
      _ => ()
    }
    "webhook=\{followed.webhook_id}"
  })
  p.probe_env("ChannelRef::follow", () => {
    let news = need(p.s.announcement, "announcement channel")
    let target = need(p.s.text, "follow target channel")
    let followed = c.channel_ref(news).follow(target)
    c.delete_webhook(followed.webhook_id) catch {
      _ => ()
    }
    "webhook=\{followed.webhook_id}"
  })
}
