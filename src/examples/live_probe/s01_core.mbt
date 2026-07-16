///|
/// Gateway info, current user/application, users, DMs.
async fn sec_core(p : P) -> Unit {
  let c = p.client
  p.probe("get_gateway", () => {
    let url = c.get_gateway()
    "url=\{url}"
  })
  p.probe("get_gateway_bot", () => {
    let info = c.get_gateway_bot()
    "shards=\{info.shards} remaining=\{info.session_start_limit.remaining}"
  })
  p.probe("get_current_user", () => {
    let user = c.get_current_user()
    p.bot_id = user.id
    "id=\{user.id} username=\{user.username}"
  })
  p.probe("get_current_application", () => {
    let app = c.get_current_application()
    p.app_id = app.id
    "id=\{app.id} name=\{app.name}"
  })
  p.probe("get_current_bot_application_information", () => {
    let app = c.get_current_bot_application_information()
    "id=\{app.id}"
  })
  p.probe("edit_current_application (description round-trip)", () => {
    let app = c.get_current_application()
    let desc = app.description
    let edited = c.edit_current_application(description=desc)
    "description len=\{edited.description.length()}"
  })
  p.probe("get_current_user_guilds", () => {
    let guilds = c.get_current_user_guilds(with_counts=true)
    "count=\{guilds.length()}"
  })
  p.probe("paginate_current_user_guilds", () => {
    let guilds = c.paginate_current_user_guilds(page_size=1).collect(max=5)
    "count=\{guilds.length()}"
  })
  p.probe("get_guild (owner discovery)", () => {
    let guild = c.get_guild(p.guild_id)
    p.owner_id = guild.owner_id
    "name=\{guild.name} owner=\{guild.owner_id}"
  })
  p.probe("get_user", () => {
    let user = c.get_user(p.owner_id)
    "username=\{user.username}"
  })
  p.probe("UserRef::fetch", () => {
    let user = c.user_ref(p.owner_id).fetch()
    "username=\{user.username}"
  })
  p.probe("create_dm + message", () => {
    let dm = c.create_dm(p.owner_id)
    let msg = c.create_message(
      dm.id,
      content="live probe run — this DM checks create_dm/create_message",
    )
    "channel=\{dm.id} message=\{msg.id}"
  })
  p.probe("UserRef::dm", () => {
    let _ref = c.user_ref(p.owner_id).dm()
    "ok"
  })
  p.probe("modify_current_user (avatar)", () => {
    let user = c.modify_current_user(
      avatar="data:image/png;base64," + EMOJI_PNG_B64,
    )
    "id=\{user.id}"
  })
  p.probe("modify_current_user (banner round-trip)", () => {
    let user = c.modify_current_user(
      banner="data:image/png;base64," + EMOJI_PNG_B64,
    )
    let has_banner = user.banner is Some(Value(_))
    let cleared = c.modify_current_user(clear_banner=true)
    "set=\{has_banner} cleared=\{!(cleared.banner is Some(Value(_)))}"
  })
  // Bearer-token endpoints: we only have a bot token; a bogus bearer verifies
  // wiring and the authorization-header override path.
  p.probe_err(
    "get_current_authorization_information (bogus bearer)",
    expect=[401],
    () => {
      c.get_current_authorization_information(bearer_token="bogus") |> ignore
    },
  )
  p.probe_err("get_current_user_connections (bogus bearer)", expect=[401], () => {
    c.get_current_user_connections(bearer_token="bogus") |> ignore
  })
  p.probe_err("get_current_user_guild_member (bogus bearer)", expect=[401], () => {
    c.get_current_user_guild_member(p.guild_id, bearer_token="bogus") |> ignore
  })
}
