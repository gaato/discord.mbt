///|
/// Scheduled events, auto-moderation rules, stage instances.
async fn sec_events(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let gr = c.guild_ref(g)

  // Scheduled events: one of each entity type.
  let start = iso8601(now_ms() + 3600_000L)
  let later = iso8601(now_ms() + 7200_000L)
  let mut external_event : @model.ScheduledEventId? = None
  p.probe("create_guild_scheduled_event (external)", () => {
    let event = c.create_guild_scheduled_event(
      g,
      "probe external event",
      GuildOnly,
      start,
      External,
      entity_metadata={ location: Some("https://example.com/live-probe"), },
      scheduled_end_time=later,
      description="created by live probe",
      audit_reason="live probe",
    )
    external_event = Some(event.id)
    "id=\{event.id}"
  })
  p.probe("GuildRef::create_scheduled_event (voice)", () => {
    let vc = need(p.s.voice, "voice channel")
    let event = gr.create_scheduled_event(
      "probe voice event",
      GuildOnly,
      start,
      Voice,
      channel_id=vc,
    )
    c.delete_guild_scheduled_event(g, event.id) catch {
      _ => ()
    }
    "id=\{event.id}"
  })
  p.probe("create_guild_scheduled_event (stage)", () => {
    let stage = need(p.s.stage, "stage channel")
    let event = c.create_guild_scheduled_event(
      g,
      "probe stage event",
      GuildOnly,
      start,
      StageInstance,
      channel_id=stage,
    )
    let deleted = c
      .scheduled_event_ref(g, event.id)
      .delete(reason="live probe cleanup")
    ignore(deleted)
    "id=\{event.id}"
  })
  guard external_event is Some(event) else { return }
  p.probe("list_guild_scheduled_events", () => {
    let events = c.list_guild_scheduled_events(g, with_user_count=true)
    "count=\{events.length()}"
  })
  p.probe("get_guild_scheduled_event + ScheduledEventRef::fetch", () => {
    let fetched = c.get_guild_scheduled_event(g, event, with_user_count=true)
    ignore(c.scheduled_event_ref(g, event).fetch())
    "name=\{fetched.name}"
  })
  p.probe("modify_guild_scheduled_event + ScheduledEventRef::edit", () => {
    let edited = c.modify_guild_scheduled_event(
      g,
      event,
      name="probe external event 2",
    )
    ignore(edited)
    let back = c.scheduled_event_ref(g, event).edit(name="probe external event")
    "name=\{back.name}"
  })
  p.probe("list_guild_scheduled_event_users (+paginator)", () => {
    let users = c.list_guild_scheduled_event_users(g, event, limit=5)
    let paged = c
      .scheduled_event_ref(g, event)
      .users(page_size=2)
      .collect(max=3)
    "users=\{users.length()} paged=\{paged.length()}"
  })
  p.probe("delete_guild_scheduled_event", () => {
    c.delete_guild_scheduled_event(g, event, audit_reason="live probe cleanup")
    "ok"
  })

  // Auto-moderation rules. Clear leftovers from previous runs first
  // (MentionSpam allows only one rule per guild).
  let leftovers = c.list_auto_moderation_rules(g) catch { _ => [] }
  for rule in leftovers {
    if rule.name.has_prefix("probe") {
      c.delete_auto_moderation_rule(g, rule.id, audit_reason="probe pre-clean") catch {
        _ => ()
      }
    }
  }
  let mut rule_id : @model.AutoModerationRuleId? = None
  p.probe("create_auto_moderation_rule (keyword)", () => {
    let rule = c.create_auto_moderation_rule(
      g,
      "probe keyword rule",
      MessageSend,
      Keyword,
      [{ typ: BlockMessage, metadata: None, }],
      trigger_metadata={
        keyword_filter: Some(["live-probe-blocked-phrase"]),
        presets: None,
        allow_list: Some(["live-probe-allowed"]),
        regex_patterns: None,
        mention_total_limit: None,
        mention_raid_protection_enabled: None,
      },
      enabled=false,
      audit_reason="live probe",
    )
    rule_id = Some(rule.id)
    "id=\{rule.id}"
  })
  p.probe("create_auto_moderation_rule (spam, no trigger_metadata)", () => {
    // Community guilds may already carry a leftover Spam rule; reuse it.
    let existing = leftovers.filter(r => r.trigger_type == Spam)
    if existing is [rule, ..] {
      "reusing existing rule \{rule.id}"
    } else {
      let rule = c.create_auto_moderation_rule(
        g,
        "probe spam rule",
        MessageSend,
        Spam,
        [{ typ: BlockMessage, metadata: None, }],
        enabled=false,
        audit_reason="live probe",
      )
      c.delete_auto_moderation_rule(g, rule.id, audit_reason="cleanup") catch {
        _ => ()
      }
      "id=\{rule.id}"
    }
  })
  p.probe("GuildRef::create_auto_moderation_rule (mention spam)", () => {
    // Community guilds allow exactly one MentionSpam rule and refuse to
    // delete it (code 200006); reuse a leftover instead of re-creating.
    let existing = leftovers.filter(r => r.trigger_type == MentionSpam)
    if existing is [rule, ..] {
      "reusing existing rule \{rule.id} (undeletable on community guilds)"
    } else {
      let rule = gr.create_auto_moderation_rule(
        "probe mention rule",
        MessageSend,
        MentionSpam,
        [{ typ: BlockMessage, metadata: None, }],
        trigger_metadata={
          keyword_filter: None,
          presets: None,
          allow_list: None,
          regex_patterns: None,
          mention_total_limit: Some(10),
          mention_raid_protection_enabled: Some(false),
        },
        enabled=false,
      )
      c.delete_auto_moderation_rule(g, rule.id) catch {
        _ => ()
      }
      "id=\{rule.id}"
    }
  })
  guard rule_id is Some(rule) else { return }
  p.probe("list_auto_moderation_rules", () => {
    let rules = c.list_auto_moderation_rules(g)
    "count=\{rules.length()}"
  })
  p.probe("get_auto_moderation_rule + AutoModerationRuleRef::fetch", () => {
    let fetched = c.get_auto_moderation_rule(g, rule)
    ignore(c.auto_moderation_rule_ref(g, rule).fetch())
    "name=\{fetched.name}"
  })
  p.probe("modify_auto_moderation_rule + ref edit", () => {
    let edited = c.modify_auto_moderation_rule(g, rule, name="probe rule 2")
    ignore(edited)
    let back = c
      .auto_moderation_rule_ref(g, rule)
      .edit(name="probe keyword rule")
    "name=\{back.name}"
  })
  p.probe("delete_auto_moderation_rule", () => {
    c.delete_auto_moderation_rule(g, rule, audit_reason="live probe cleanup")
    "ok"
  })
  p.probe("AutoModerationRuleRef::delete (secondary)", () => {
    let tmp = gr.create_auto_moderation_rule(
      "probe tmp rule",
      MessageSend,
      Keyword,
      [{ typ: BlockMessage, metadata: None, }],
      trigger_metadata={
        keyword_filter: Some(["tmp-phrase"]),
        presets: None,
        allow_list: None,
        regex_patterns: None,
        mention_total_limit: None,
        mention_raid_protection_enabled: None,
      },
      enabled=false,
    )
    gr.auto_moderation_rule_ref(tmp.id).delete(reason="live probe cleanup")
    "ok"
  })

  // Stage instances.
  p.probe_env("create/get/modify/delete stage instance", () => {
    let stage = need(p.s.stage, "stage channel")
    let instance = c.create_stage_instance(
      stage,
      "live probe stage",
      privacy_level=GuildOnly,
      send_start_notification=false,
      audit_reason="live probe",
    )
    ignore(instance)
    let fetched = c.get_stage_instance(stage)
    ignore(fetched)
    ignore(c.channel_ref(stage).stage_instance())
    let edited = c.modify_stage_instance(stage, topic="live probe stage 2")
    ignore(edited)
    ignore(c.channel_ref(stage).edit_stage_instance(topic="live probe stage"))
    c.delete_stage_instance(stage, audit_reason="live probe cleanup")
    "ok"
  })
  p.probe_env("ChannelRef::create_stage_instance/delete_stage_instance", () => {
    let stage = need(p.s.stage, "stage channel")
    let instance = c
      .channel_ref(stage)
      .create_stage_instance("live probe stage again", privacy_level=GuildOnly)
    ignore(instance)
    c.channel_ref(stage).delete_stage_instance(reason="live probe cleanup")
    "ok"
  })
}
