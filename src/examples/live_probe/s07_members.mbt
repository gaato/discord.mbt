///|
/// Roles, members, bans. The guild only contains the owner and this bot, so
/// member-mutation targets are the bot itself and ban targets are a real but
/// absent user id (bans work on users who are not members).
const ABSENT_USER : UInt64 = 159985870458322944UL // MEE6, never in this guild

///|
async fn sec_members(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let gr = c.guild_ref(g)
  let mut role_id : @model.RoleId? = None
  p.probe("create_guild_role", () => {
    let role = c.create_guild_role(
      g,
      name="probe-role",
      permissions=@model.Permissions::none(),
      color=0xE91E63,
      hoist=true,
      mentionable=true,
      audit_reason="live probe",
    )
    role_id = Some(role.id)
    p.s.role = Some(role.id)
    "id=\{role.id}"
  })
  p.probe("get_guild_roles + GuildRef::roles", () => {
    let roles = c.get_guild_roles(g)
    ignore(gr.roles())
    "count=\{roles.length()}"
  })
  guard role_id is Some(role) else { return }
  p.probe("get_guild_role + RoleRef::fetch", () => {
    let fetched = c.get_guild_role(g, role)
    ignore(c.role_ref(g, role).fetch())
    "name=\{fetched.name}"
  })
  p.probe("modify_guild_role + RoleRef::edit", () => {
    let edited = c.modify_guild_role(g, role, name="probe-role-2")
    ignore(edited)
    let back = c.role_ref(g, role).edit(name="probe-role")
    "name=\{back.name}"
  })
  p.probe("modify_guild_role_positions", () => {
    let roles = c.modify_guild_role_positions(g, [(role, Some(1))])
    "count=\{roles.length()}"
  })
  p.probe("add_member_role / remove_member_role (bot)", () => {
    c.add_member_role(g, p.bot_id, role, audit_reason="live probe")
    c.remove_member_role(g, p.bot_id, role)
    "ok"
  })
  p.probe("MemberRef::add_role/remove_role", () => {
    let r = c.member_ref(g, p.bot_id)
    r.add_role(role)
    r.remove_role(role)
    "ok"
  })
  p.probe("get_guild_member + MemberRef::fetch", () => {
    let gm = c.get_guild_member(g, p.bot_id)
    ignore(c.member_ref(g, p.bot_id).fetch())
    "roles=\{gm.roles.length()}"
  })
  p.probe("list_guild_members + paginate_guild_members", () => {
    let members = c.list_guild_members(g, limit=10)
    let paged = gr.members(page_size=1).collect(max=3)
    "list=\{members.length()} paged=\{paged.length()}"
  })
  p.probe("search_guild_members", () => {
    let members = c.search_guild_members(g, "がーと", limit=5)
    "count=\{members.length()}"
  })
  p.probe("modify_current_member (nick round-trip)", () => {
    let gm = c.modify_current_member(
      g,
      nick="live-probe-bot",
      audit_reason="live probe nick",
    )
    ignore(gm)
    let cleared = c.modify_current_member(g, clear_nick=true)
    ignore(cleared)
    "ok"
  })
  p.probe("GuildRef::edit_current_member (bio/banner clear)", () => {
    let gm = gr.edit_current_member(nick="live-probe-bot-2")
    ignore(gm)
    ignore(gr.edit_current_member(clear_nick=true))
    "ok"
  })
  p.probe_err(
    "modify_guild_member (self-target rejected; wiring verified)",
    expect=[403],
    () => {
      // Bots must use ModifyCurrentMember for themselves and outrank any other
      // target; without a third member only the refusal is observable.
      let gm = c.modify_guild_member(g, p.bot_id, nick="probe-member-nick")
      ignore(gm)
    },
  )
  p.probe_err("MemberRef::timeout (cannot timeout self)", expect=[400, 403], () => {
    let until = iso8601(now_ms() + 60_000L)
    c.member_ref(g, p.bot_id).timeout(Some(until)) |> ignore
  })
  p.probe("remove_guild_member (absent user; kick is idempotent)", () => {
    c.remove_guild_member(g, @model.Id(ABSENT_USER))
    "204 for non-member"
  })
  p.probe("MemberRef::kick (absent user; idempotent)", () => {
    c.member_ref(g, @model.Id(ABSENT_USER)).kick(reason="live probe")
    "204 for non-member"
  })
  p.probe_err("add_guild_member (bogus oauth token)", expect=[400, 401, 403], () => {
    c.add_guild_member(g, @model.Id(ABSENT_USER), "bogus-access-token")
    |> ignore
  })
  // Bans on a real-but-absent user id.
  p.probe("create_guild_ban", () => {
    c.create_guild_ban(
      g,
      @model.Id(ABSENT_USER),
      delete_message_seconds=0,
      audit_reason="live probe ban",
    )
    "ok"
  })
  p.probe("get_guild_ban", () => {
    let ban = c.get_guild_ban(g, @model.Id(ABSENT_USER))
    "user=\{ban.user.username}"
  })
  p.probe("get_guild_bans + paginate_guild_bans", () => {
    let bans = c.get_guild_bans(g, limit=5)
    let paged = gr.bans(page_size=1).collect(max=3)
    "list=\{bans.length()} paged=\{paged.length()}"
  })
  p.probe("GuildRef::fetch_ban", () => {
    let ban = gr.fetch_ban(@model.Id(ABSENT_USER))
    "user=\{ban.user.username}"
  })
  p.probe("remove_guild_ban", () => {
    c.remove_guild_ban(
      g,
      @model.Id(ABSENT_USER),
      audit_reason="live probe unban",
    )
    "ok"
  })
  p.probe("MemberRef::ban/unban", () => {
    let r = c.member_ref(g, @model.Id(ABSENT_USER))
    r.ban(delete_message_seconds=0, reason="live probe")
    r.unban(reason="live probe")
    "ok"
  })
  p.probe("bulk_guild_ban + unban cleanup", () => {
    let response = c.bulk_guild_ban(
      g,
      [@model.Id(ABSENT_USER)],
      audit_reason="live probe bulk ban",
    )
    for user in response.banned_users {
      c.remove_guild_ban(g, user) catch {
        _ => ()
      }
    }
    "banned=\{response.banned_users.length()} failed=\{response.failed_users.length()}"
  })
  p.probe("delete_guild_role", () => {
    // Keep p.s.role for later sections? No: commands section doesn't need it.
    c.delete_guild_role(g, role, audit_reason="live probe cleanup")
    p.s.role = None
    "ok"
  })
  p.probe("RoleRef::delete (secondary role)", () => {
    let tmp = c.create_guild_role(g, name="probe-role-tmp")
    c.role_ref(g, tmp.id).delete(reason="live probe cleanup")
    "ok"
  })
}
