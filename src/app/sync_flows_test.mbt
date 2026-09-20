///|
fn sync_stub_client(requests : Array[String], fetched : Json) -> @dhttp.Client {
  let client = @dhttp.Client("test-token")
  client.middleware((request, _next) => {
    requests.push(
      "\{@debug.to_string(request.route.method_())} \{request.route.path()}",
    )
    let body : Json = if request.route.method_() is Get {
      fetched
    } else {
      Json::array([])
    }
    { status: 200, headers: Map([]), body, }
  })
  client
}

///|
async test "global sync skips matching sets and replaces stale ones" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="ping",
      description="Ping",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  let application_id : @model.ApplicationId = @model.Id::parse(
    "400000000000000001",
  )

  // The fetched catalog already matches (same name/description/defaults):
  // no PUT must follow the GET.
  let in_sync_requests : Array[String] = []
  let in_sync_client = sync_stub_client(
    in_sync_requests,
    @json.parse(
      (
        #|[{"id":"600000000000000001","application_id":"400000000000000001","name":"ping","description":"Ping","type":1,"default_member_permissions":null,"version":"1"}]
      ),
    ),
  )
  defer in_sync_client.close()
  app.sync_commands(in_sync_client, application_id, scope=Global)
  inspect(
    in_sync_requests.join("\n"),
    content=(
      #|Get /applications/400000000000000001/commands?with_localizations=true
    ),
  )

  // A stale catalog (different description) triggers the bulk PUT.
  let stale_requests : Array[String] = []
  let stale_client = sync_stub_client(
    stale_requests,
    @json.parse(
      (
        #|[{"id":"600000000000000001","application_id":"400000000000000001","name":"ping","description":"Old text","type":1,"default_member_permissions":null,"version":"1"}]
      ),
    ),
  )
  defer stale_client.close()
  app.sync_commands(stale_client, application_id, scope=Global)
  inspect(
    stale_requests.join("\n"),
    content=(
      #|Get /applications/400000000000000001/commands?with_localizations=true
      #|Put /applications/400000000000000001/commands
    ),
  )
}

///|
async test "guild sync targets each configured guild" {
  let guild_a : @model.GuildId = @model.Id::parse("100")
  let guild_b : @model.GuildId = @model.Id::parse("101")
  let app = @app.App()
  app.command(
    @app.slash(
      name="ping",
      description="Ping",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  let requests : Array[String] = []
  let client = sync_stub_client(requests, Json::array([]))
  defer client.close()
  app.sync_commands(
    client,
    @model.Id::parse("400000000000000001"),
    scope=Guilds([guild_a, guild_b]),
  )
  inspect(
    requests.join("\n"),
    content=(
      #|Get /applications/400000000000000001/guilds/100/commands?with_localizations=true
      #|Put /applications/400000000000000001/guilds/100/commands
      #|Get /applications/400000000000000001/guilds/101/commands?with_localizations=true
      #|Put /applications/400000000000000001/guilds/101/commands
    ),
  )
}
