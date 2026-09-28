///|
/// The command sync scope: the `GUILD_ID` guild when set, otherwise global.
/// An invalid `GUILD_ID` stops the program: falling back to a global sync
/// would delete every undeclared global command.
fn command_scope() -> @discord.CommandScope raise {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId = @model.Id::parse(raw) catch {
        _ => fail("GUILD_ID is not a valid guild id: \{raw}")
      }
      @discord.CommandScope::Guild(guild_id)
    }
    None => @discord.CommandScope::Global
  }
}

///|
fn unowned_commands() -> @framework.UnownedCommands {
  match @env.get_env_var("SYNC_UNOWNED") {
    Some("keep") => Keep
    _ => Delete
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
  let app = @interactions_js.interaction_app()
  @async.with_task_group(group => {
    let client = @discord.Client(token)
    group.add_defer(() => client.close())
    let application_id = client.get_current_application().id
    let report = app.sync_commands(
      client,
      application_id,
      scope~,
      unowned=unowned_commands(),
    )
    println("[register] \{Repr(report)}")
  })
}
