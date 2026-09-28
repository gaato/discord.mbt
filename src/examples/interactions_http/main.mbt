///|
fn echo_command() -> @app.Command[String] {
  @app.slash(
    name="echo",
    description="Echo text back",
    args=@interaction.Args::of(
      @interaction.arg_string(name="text", description="What to echo"),
    ),
    handler=Immediate((_, text) => @app.CommandReply::message(content=text)),
  )
}

///|
/// The command sync scope: the `GUILD_ID` guild when set, otherwise global.
/// An invalid `GUILD_ID` stops the program: falling back to a global sync
/// would delete every undeclared global command.
fn command_scope() -> @app.CommandScope raise {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId = @model.Id::parse(raw) catch {
        _ => fail("GUILD_ID is not a valid guild id: \{raw}")
      }
      @app.CommandScope::Guild(guild_id)
    }
    None => @app.CommandScope::Global
  }
}

///|
fn port() -> Int {
  match @env.get_env_var("PORT") {
    Some(value) => @string.parse_int(value) catch { _ => 8080 }
    None => 8080
  }
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  @async.handle_cancellation(() => {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    let public_key = @env.get_env_var("PUBLIC_KEY").unwrap_or("")
    let app = @app.AppBuilder()
    app.command(echo_command())
    @async.with_task_group(group => {
      let client = @dhttp.Client(token)
      group.add_defer(() => client.close())
      let application_id = client.get_current_application().id
      let report = app
        .build()
        .sync_commands(client, application_id, scope=command_scope())
      println("[http] command sync: \{Repr(report)}")
      let server = @endpoint_http.serve_interactions(
        group,
        app.build(),
        access=Client(client),
        addr="0.0.0.0:\{port()}",
        public_key~,
        application_id~,
      )
      println("[http] listening on \{server.addr()}")
    })
  })
  |> ignore
  println("[bot] shutting down")
}
