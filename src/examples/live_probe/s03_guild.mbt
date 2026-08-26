///|
/// Guild-wide endpoints, including enabling COMMUNITY so announcement
/// channels / welcome screen become testable later.
async fn sec_guild(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let gr = c.guild_ref(g)
  p.probe("GuildRef::fetch (with_counts)", () => {
    let guild = gr.fetch(with_counts=true)
    p.s.original_features = guild.features
    "members=\{guild.approximate_member_count.unwrap_or(-1)} features=\{guild.features.length()}"
  })
  p.probe("get_guild_preview", () => {
    let preview = c.get_guild_preview(g)
    "name=\{preview.name}"
  })
  p.probe("GuildRef::preview", () => {
    let preview = gr.preview()
    "emojis=\{preview.emojis.length()}"
  })
  p.probe("modify_guild (description round-trip + community)", () => {
    let features = p.s.original_features.copy()
    if !features.contains(Community) {
      features.push(Community)
    }
    let guild = c.modify_guild(
      g,
      description="live probe playground",
      features~,
      verification_level=Low,
      explicit_content_filter=AllMembers,
      default_message_notifications=OnlyMentions,
      rules_channel_id?=p.s.text,
      public_updates_channel_id?=p.s.text2,
      audit_reason="live probe community enable",
    )
    p.s.community_enabled = guild.features.contains(Community)
    "community=\{p.s.community_enabled}"
  })
  p.probe_env("create_guild_channel (stage; needs community)", () => {
    let ch = c.create_guild_channel(
      g,
      "probe-stage",
      typ=GuildStageVoice,
      parent_id?=p.s.category,
    )
    p.s.stage = Some(ch.id)
    "id=\{ch.id}"
  })
  p.probe_env("create_guild_channel (media; needs community)", () => {
    let ch = c.create_guild_channel(g, "probe-media", typ=GuildMedia)
    let _ = c.delete_channel(ch.id)
    "id=\{ch.id}"
  })
  p.probe("GuildRef::edit (premium progress bar)", () => {
    let guild = gr.edit(premium_progress_bar_enabled=true)
    ignore(gr.edit(premium_progress_bar_enabled=false))
    "ok=\{guild.premium_progress_bar_enabled.unwrap_or(false)}"
  })
  p.probe("get_guild_voice_regions", () => {
    let regions = c.get_guild_voice_regions(g)
    "count=\{regions.length()}"
  })
  p.probe("list_voice_regions", () => {
    let regions = c.list_voice_regions()
    "count=\{regions.length()}"
  })
  p.probe("get_guild_integrations", () => {
    let integrations = c.get_guild_integrations(g)
    "count=\{integrations.length()}"
  })
  p.probe_err("delete_guild_integration (bogus id)", expect=[404], () => {
    c.delete_guild_integration(g, Id(1234567890123456789UL))
  })
  p.probe_env("get_guild_vanity_url", () => {
    let vanity = c.get_guild_vanity_url(g)
    "uses=\{vanity.uses}"
  })
  p.probe("get_guild_widget_settings", () => {
    let settings = c.get_guild_widget_settings(g)
    "enabled=\{settings.enabled}"
  })
  p.probe("modify_guild_widget (enable)", () => {
    let settings = c.modify_guild_widget(g, enabled=true, channel_id?=p.s.text)
    "enabled=\{settings.enabled}"
  })
  p.probe("get_guild_widget", () => {
    let widget = c.get_guild_widget(g)
    "name=\{widget.name}"
  })
  p.probe("guild_widget_image_url", () => {
    let url = c.guild_widget_image_url(g, style="banner1")
    "url=\{url}"
  })
  p.probe("GuildRef::edit_widget (disable)", () => {
    let settings = gr.edit_widget(enabled=false)
    "enabled=\{settings.enabled}"
  })
  p.probe_env("modify_guild_welcome_screen", () => {
    let text = need(p.s.text, "text channel")
    let ws = c.modify_guild_welcome_screen(
      g,
      enabled=true,
      description="welcome to the live probe",
      welcome_channels=[
        {
          channel_id: text,
          description: "probe channel",
          emoji_id: Null,
          emoji_name: Null,
        },
      ],
    )
    "enabled channels=\{ws.welcome_channels.length()}"
  })
  p.probe_env("get_guild_welcome_screen", () => {
    let ws = c.get_guild_welcome_screen(g)
    "channels=\{ws.welcome_channels.length()}"
  })
  p.probe("get_guild_onboarding", () => {
    let ob = c.get_guild_onboarding(g)
    "enabled=\{ob.enabled}"
  })
  p.probe_env("modify_guild_onboarding (disable)", () => {
    let ob = c.modify_guild_onboarding(g, [], [], false, Default)
    "enabled=\{ob.enabled}"
  })
  p.probe("modify_guild_incident_actions (set + clear)", () => {
    let until = iso8601(now_ms() + 3600_000L)
    let set = c.modify_guild_incident_actions(g, invites_disabled_until=until)
    ignore(set)
    let cleared = c.modify_guild_incident_actions(
      g,
      clear_invites_disabled_until=true,
      clear_dms_disabled_until=true,
    )
    ignore(cleared)
    "ok"
  })
  p.probe("get_guild_prune_count", () => {
    let result = c.get_guild_prune_count(g, days=7)
    "pruned=\{nul(result.pruned)}"
  })
  p.probe("begin_guild_prune", () => {
    // compute_prune_count=false: the synchronous count can exceed the client
    // request timeout even on small guilds.
    let result = c.begin_guild_prune(
      g,
      days=7,
      compute_prune_count=false,
      audit_reason="live probe (no-op on a guild with no prunable members)",
    )
    "pruned=\{nul(result.pruned)}"
  })
  p.probe("get_guild_audit_log", () => {
    let log = c.get_guild_audit_log(g, limit=10)
    "entries=\{log.audit_log_entries.length()}"
  })
  p.probe("paginate_guild_audit_log", () => {
    let entries = gr.audit_log(page_size=5).collect(max=8)
    "entries=\{entries.length()}"
  })
  p.probe_env("search_guild_messages", () => {
    let results = gr.search_messages(content="probe", limit=5)
    "total=\{results.total_results.unwrap_or(-1)}"
  })
  p.probe_err(
    "leave_guild (must not actually leave; bogus guild)",
    expect=[404],
    () => c.leave_guild(Id(1234567890123456789UL)),
  )
}
