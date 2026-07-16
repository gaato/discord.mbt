///|
/// Guild templates, plus Create Guild From Template. The child guild is owned
/// by the bot; Discord has no typed wrapper for DELETE /guilds/{id} (that
/// endpoint is undocumented for bots), so cleanup goes through Route::custom,
/// which doubles as the escape-hatch probe.
async fn sec_templates(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let gr = c.guild_ref(g)
  // A guild can hold a single template; clear any leftover from prior runs.
  let leftovers = c.get_guild_templates(g) catch { _ => [] }
  for template in leftovers {
    let _ = c.delete_guild_template(g, template.code) catch { _ => continue }
  }
  let mut code : String? = None
  p.probe("create_guild_template", () => {
    let template = c.create_guild_template(
      g,
      "live-probe-template",
      description="created by live probe",
    )
    code = Some(template.code)
    "code=\{template.code}"
  })
  guard code is Some(tcode) else { return }
  p.probe("get_guild_templates + GuildRef::templates", () => {
    let templates = c.get_guild_templates(g)
    ignore(gr.templates())
    "count=\{templates.length()}"
  })
  p.probe("get_guild_template (by code)", () => {
    let template = c.get_guild_template(tcode)
    "name=\{template.name}"
  })
  p.probe("modify_guild_template + TemplateRef::edit", () => {
    let edited = c.modify_guild_template(g, tcode, name="live-probe-template-2")
    ignore(edited)
    let back = c.guild_template_ref(g, tcode).edit(name="live-probe-template")
    "name=\{back.name}"
  })
  p.probe("sync_guild_template + TemplateRef::sync/fetch", () => {
    let synced = c.sync_guild_template(g, tcode)
    ignore(synced)
    ignore(c.guild_template_ref(g, tcode).sync())
    ignore(c.guild_template_ref(g, tcode).fetch())
    "ok"
  })
  // Create Guild From Template has been removed from the current developer
  // docs and the live API refuses bots (20001, verified 2026-07-16); only
  // the refusal is observable. A second attempt has been seen to stall for
  // 60s, so the handle variant is not exercised live.
  p.probe_err("create_guild_from_template (bots forbidden)", expect=[400], () => {
    c.create_guild_from_template(tcode, "live-probe-child") |> ignore
  })
  p.push(
    "TemplateRef::create_guild",
    Skip,
    "same bot-forbidden route as create_guild_from_template",
  )
  p.probe("delete_guild_template", () => {
    let deleted = c.delete_guild_template(g, tcode)
    "code=\{deleted.code}"
  })
  p.probe("TemplateRef::delete (secondary)", () => {
    let tmp = gr.create_template("live-probe-template-tmp")
    let deleted = gr.template_ref(tmp.code).delete()
    "code=\{deleted.code}"
  })
}
