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
fn command_scope() -> @app.CommandScope {
  match @env.get_env_var("GUILD_ID") {
    Some(raw) => {
      let guild_id : @model.GuildId? = Some(@model.Id::parse(raw)) catch {
        _ => None
      }
      match guild_id {
        Some(value) => Guild(value)
        None => {
          println("[http] invalid GUILD_ID, syncing globally")
          Global
        }
      }
    }
    None => Global
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
    let app = @app.App()
    app.command(echo_command())
    @async.with_task_group(group => {
      let client = @dhttp.Client(token)
      group.add_defer(() => client.close())
      let application_id = client.get_current_application().id
      let report = app.sync_commands(
        client,
        application_id,
        scope=command_scope(),
      )
      println("[http] command sync: \{Repr(report)}")
      let server = @endpoint_http.serve_interactions(
        group,
        app,
        addr="0.0.0.0:\{port()}",
        public_key~,
        client~,
        application_id~,
      )
      println("[http] listening on \{server.addr()}")
    })
  })
  |> ignore
  println("[bot] shutting down")
}
