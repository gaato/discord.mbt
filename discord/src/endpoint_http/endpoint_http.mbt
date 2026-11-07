///|
priv enum ServerStartup {
  Ready(String)
  Failed(Error)
}

///|
/// Configuration errors reported by the bounded HTTP server.
pub using @server {type ServerConfigError}

///|
/// An HTTP server dispatching Discord interactions on native or moonrun Wasm.
pub struct InteractionsServer {
  priv address : String
  priv runner : Ref[@async.TaskGroup[Unit]?]
}

///|
/// Return the actual listening address, including an OS-assigned port.
pub fn InteractionsServer::addr(self : InteractionsServer) -> String {
  self.address
}

///|
/// Stop accepting requests and cancel active connection handlers.
pub async fn InteractionsServer::close(
  self : InteractionsServer,
) -> Unit noraise {
  if self.runner.val is Some(inner) {
    inner.return_immediately(())
  }
}

///|
/// Start a Discord HTTP-interactions server in `group` on native or moonrun Wasm.
///
/// Use port zero in `addr` to let the OS choose a free port, then read the
/// resolved address from `InteractionsServer::addr`.
///
/// A request body larger than `max_body_bytes` gets 413, and one not received
/// within `body_timeout_ms` gets 408; both close the connection. Discord's
/// interaction payloads are far below the 1 MiB default. A connection whose
/// next request head does not arrive within `header_timeout_ms`, idle
/// keep-alive time included, is closed. At most `max_connections` clients
/// are served at once; more wait to be accepted. Non-positive limits raise
/// `ServerConfigError` before the server listens.
pub async fn[X] serve_interactions(
  group : @async.TaskGroup[X],
  app : @app.App,
  addr~ : String,
  public_key~ : String,
  access~ : @app.RestAccess,
  application_id? : @model.ApplicationId,
  path~ : String = "/",
  deadline_ms~ : Int32 = 2500,
  max_body_bytes~ : Int32 = 1048576,
  body_timeout_ms~ : Int32 = 5000,
  header_timeout_ms~ : Int32 = 5000,
  max_connections~ : Int32 = 256,
) -> InteractionsServer {
  guard max_body_bytes > 0 else {
    raise @server.InvalidMaxBodyBytes(value=max_body_bytes)
  }
  guard body_timeout_ms > 0 else {
    raise @server.InvalidBodyTimeoutMs(value=body_timeout_ms)
  }
  guard header_timeout_ms > 0 else {
    raise @server.InvalidHeaderTimeoutMs(value=header_timeout_ms)
  }
  guard max_connections > 0 else {
    raise @server.InvalidMaxConnections(value=max_connections)
  }
  let verifier = @verify.InteractionVerifier::new(public_key)
  let runner : Ref[@async.TaskGroup[Unit]?] = Ref(None)
  let startup : @aqueue.Queue[ServerStartup] = Queue(kind=Unbounded)
  let warn : (@app.AppWarning) -> Unit = warning => app.warn(warning)
  group.spawn_bg(allow_failure=true, () => {
    let mut ready = false
    @async.with_task_group(inner => {
      runner.val = Some(inner)
      let endpoint = app.serve(inner, access~, application_id?)
      let handler = interaction_handler(
        endpoint,
        verifier,
        path~,
        deadline_ms~,
        max_body_bytes~,
        warn~,
      )
      @server.serve(
        handler,
        addr~,
        limits={
          ..@server.ServerLimits::default(),
          max_body_bytes,
          body_timeout_ms,
          header_timeout_ms,
          max_connections,
          drain_ms: 0,
        },
        on_listen=address => {
          ready = true
          ignore(startup.try_put(Ready(address)) catch { _ => false })
        },
        on_error=error => {
          warn(
            @app.Executor(
              source="http",
              message="interaction HTTP request failed: \{error.detail}",
            ),
          )
        },
      )
    }) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        if ready {
          warn(
            @app.Executor(
              source="http",
              message="interaction HTTP server stopped: \{Repr(error)}",
            ),
          )
        } else {
          startup.put(Failed(error))
        }
    }
  })
  match startup.get() {
    Ready(address) => { address, runner, }
    Failed(error) => raise error
  }
}
