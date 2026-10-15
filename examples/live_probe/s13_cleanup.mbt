///|
/// Best-effort teardown; the channel deletions double as delete_channel /
/// ChannelRef::delete probes. Guild-level settings are restored.
async fn sec_cleanup(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  if p.s.dm_channel is Some(channel) && p.s.dm_message is Some(message) {
    p.probe("cleanup: delete DM probe message", () => {
      c.delete_message(channel, message)
      p.s.dm_message = None
      "ok"
    })
  }
  if p.s.original_member_nick is Some(original) {
    p.probe("cleanup: restore current member nick", () => {
      match original {
        Value(nick) => ignore(c.modify_current_member(g, nick~))
        Null => ignore(c.modify_current_member(g, clear_nick=true))
      }
      "ok"
    })
  }
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
  // Welcome-screen mutations require COMMUNITY. Restore them before removing
  // a COMMUNITY feature that this probe temporarily enabled.
  if p.s.original_welcome_screen is Some(original) {
    p.probe_env("cleanup: restore guild welcome screen", () => {
      let mut cleared_stale_snapshot = false
      let ws = try {
        match original.description {
          Value(description) =>
            c.modify_guild_welcome_screen(
              g,
              welcome_channels=original.welcome_channels,
              description~,
              audit_reason="live probe cleanup",
            )
          Null =>
            c.modify_guild_welcome_screen(
              g,
              welcome_channels=original.welcome_channels,
              clear_description=true,
              audit_reason="live probe cleanup",
            )
        }
      } catch {
        _ => {
          // A previous interrupted probe may have left a welcome channel that
          // no longer exists. Leave a valid disabled screen in that case.
          cleared_stale_snapshot = true
          c.modify_guild_welcome_screen(
            g,
            enabled=false,
            welcome_channels=[],
            clear_description=true,
            audit_reason="live probe cleanup stale snapshot fallback",
          )
        }
      }
      "channels=\{ws.welcome_channels.length()} stale_snapshot_cleared=\{cleared_stale_snapshot}"
    })
  }
  // Restore guild settings we touched. Only downgrade COMMUNITY if we were
  // the ones who enabled it (original_features is the pre-probe snapshot).
  if p.s.original_guild is Some(_) {
    p.probe("cleanup: modify_guild (restore settings)", () => {
      let original = need(p.s.original_guild, "guild snapshot")
      let we_enabled_community = p.s.community_enabled &&
        !p.s.original_features.contains(Community)
      ignore(
        c.modify_guild(
          g,
          verification_level=original.verification_level,
          default_message_notifications=original.default_message_notifications,
          explicit_content_filter=original.explicit_content_filter,
          premium_progress_bar_enabled=original.premium_progress_bar_enabled.unwrap_or(
            false,
          ),
          audit_reason="live probe cleanup",
        ),
      )
      match original.description {
        Value(description) =>
          ignore(
            c.modify_guild(g, description~, audit_reason="live probe cleanup"),
          )
        Null =>
          ignore(
            c.modify_guild(
              g,
              clear_description=true,
              audit_reason="live probe cleanup",
            ),
          )
      }
      if we_enabled_community {
        ignore(
          c.modify_guild(
            g,
            features=p.s.original_features,
            clear_rules_channel_id=true,
            clear_public_updates_channel_id=true,
            audit_reason="live probe cleanup",
          ),
        )
      } else {
        match original.rules_channel_id {
          Value(channel) =>
            ignore(
              c.modify_guild(
                g,
                rules_channel_id=channel,
                audit_reason="live probe cleanup",
              ),
            )
          Null =>
            ignore(
              c.modify_guild(
                g,
                clear_rules_channel_id=true,
                audit_reason="live probe cleanup",
              ),
            )
        }
        match original.public_updates_channel_id {
          Value(channel) =>
            ignore(
              c.modify_guild(
                g,
                public_updates_channel_id=channel,
                audit_reason="live probe cleanup",
              ),
            )
          Null =>
            ignore(
              c.modify_guild(
                g,
                clear_public_updates_channel_id=true,
                audit_reason="live probe cleanup",
              ),
            )
        }
      }
      let guild = c.get_guild(g)
      "features=\{guild.features.length()}"
    })
  }
  if p.s.original_widget is Some(original) {
    p.probe("cleanup: restore guild widget", () => {
      let settings = match original.channel_id {
        Value(channel) =>
          c.modify_guild_widget(g, enabled=original.enabled, channel_id=channel)
        Null =>
          c.modify_guild_widget(
            g,
            enabled=original.enabled,
            clear_channel_id=true,
          )
      }
      "enabled=\{settings.enabled}"
    })
  }
  if p.s.original_onboarding is Some(original) {
    p.probe_env("cleanup: restore guild onboarding", () => {
      let ob = c.modify_guild_onboarding(
        g,
        original.prompts,
        original.default_channel_ids,
        original.enabled,
        original.mode,
        audit_reason="live probe cleanup",
      )
      "enabled=\{ob.enabled}"
    })
  }
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
