///|
/// One-shot command registration for the worker: builds the same `App` as
/// entry.js and diff-syncs its commands, so run it after `wrangler deploy`
/// (or from CI). Without `GUILD_ID` the commands are registered globally.
fn command_scope() -> @discord.CommandScope {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId? = Some(@model.Id::parse(raw)) catch {
        _ => None
      }
      match guild_id {
        Some(value) => Guild(value)
        None => {
          println("[register] invalid GUILD_ID, syncing globally")
          Global
        }
      }
    }
    None => Global
  }
}

///|
async fn main {
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  if token.is_empty() {
    println("[register] set DISCORD_TOKEN to register commands")
    return
  }
  let scope = command_scope()
  let app = @workers_echo.worker_app()
  @async.with_task_group(group => {
    let client = @discord.Client(token)
    group.add_defer(() => client.close())
    let application_id = client.get_current_application().id
    let report = app.sync_commands(client, application_id, scope~)
    println("[register] \{Repr(report)}")
  })
}
