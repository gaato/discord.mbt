///|
/// Best-effort teardown; the channel deletions double as delete_channel /
/// ChannelRef::delete probes. Guild-level settings are restored.
async fn sec_cleanup(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  if p.s.emoji is Some(emoji) {
    p.probe("cleanup: EmojiRef::delete (primary emoji)", () => {
      c.emoji_ref(g, emoji).delete(reason="live probe cleanup")
      "ok"
    })
  }
  if p.s.sticker is Some(sticker) {
    p.probe("cleanup: delete_guild_sticker", () => {
      c.delete_guild_sticker(g, sticker, audit_reason="live probe cleanup")
      "ok"
    })
  }
  if p.s.sound is Some(sound) {
    p.probe("cleanup: delete_guild_soundboard_sound", () => {
      c.delete_guild_soundboard_sound(
        g,
        sound,
        audit_reason="live probe cleanup",
      )
      "ok"
    })
  }
  if p.s.role is Some(role) {
    c.delete_guild_role(g, role) catch {
      _ => ()
    }
  }
  if p.s.webhook is Some(webhook) {
    c.delete_webhook(webhook) catch {
      _ => ()
    }
  }
  // Community-only channels go first (a stage channel may block removing the
  // COMMUNITY feature), then the feature restore releases the rules/updates
  // channels so the text channels become deletable.
  for
    pair in [
      ("stage", p.s.stage),
      ("announcement", p.s.announcement),
      ("voice", p.s.voice),
      ("forum", p.s.forum),
    ] {
    let (label, id) = pair
    if id is Some(ch) {
      p.probe("cleanup: ChannelRef::delete (\{label})", () => {
        let deleted = c.channel_ref(ch).delete(reason="live probe cleanup")
        "id=\{deleted.id}"
      })
    }
  }
  // Restore guild settings we touched. Only downgrade COMMUNITY if we were
  // the ones who enabled it (original_features is the pre-probe snapshot).
  p.probe("cleanup: modify_guild (restore features/description)", () => {
    let we_enabled_community = p.s.community_enabled &&
      !p.s.original_features.contains(Community)
    let guild = if we_enabled_community {
      c.modify_guild(
        g,
        features=p.s.original_features,
        clear_description=true,
        clear_rules_channel_id=true,
        clear_public_updates_channel_id=true,
        audit_reason="live probe cleanup",
      )
    } else {
      c.modify_guild(
        g,
        clear_description=true,
        audit_reason="live probe cleanup",
      )
    }
    "features=\{guild.features.length()}"
  })
  // With COMMUNITY off, the previously undeletable MentionSpam automod rule
  // becomes deletable.
  let rules = c.list_auto_moderation_rules(g) catch { _ => [] }
  for rule in rules {
    if rule.name.has_prefix("probe") {
      c.delete_auto_moderation_rule(g, rule.id, audit_reason="probe cleanup") catch {
        _ => ()
      }
    }
  }
  if p.s.text is Some(text) {
    p.probe("cleanup: delete_channel (text)", () => {
      let ch = c.delete_channel(text, audit_reason="live probe cleanup")
      "id=\{ch.id}"
    })
  }
  for pair in [("text2", p.s.text2), ("category", p.s.category)] {
    let (label, id) = pair
    if id is Some(ch) {
      p.probe("cleanup: ChannelRef::delete (\{label})", () => {
        let deleted = c.channel_ref(ch).delete(reason="live probe cleanup")
        "id=\{deleted.id}"
      })
    }
  }
}
