///|
/// The result of dispatching one HTTP-delivered interaction.
pub(all) enum InteractionOutcome {
  Reply(
    response~ : @model.InteractionResponse,
    files~ : Array[@dhttp.FileUpload]?
  )
  NoRoute
  NoResponse
  TimedOut
} derive(Debug)

///|
/// A gateway-free interaction dispatcher backed by a caller-owned task group.
pub struct InteractionEndpoint {
  priv framework : @framework.Framework
  priv group : @async.TaskGroup[Unit]
  priv warn : (AppWarning) -> Unit
}

///|
priv enum InteractionRace {
  Captured(@framework.CapturedResponse)
  Completed(Bool)
}

///|
/// How an executor reaches Discord's REST API: with a bot token, from which it
/// builds and owns a client, or through an existing client the caller owns.
pub(all) enum RestAccess {
  /// Build a client from this bot token. The executor closes it when done.
  Token(String)
  /// Use this client. The caller keeps ownership and closes it.
  Client(@dhttp.Client)
}

///|
/// Build a gateway-free dispatcher.
///
/// With `access=Token(token)` the endpoint owns a client built from the token
/// and closes it when `group` finishes; with `access=Client(client)` it uses
/// the caller's client. When `application_id` is omitted, this method resolves
/// it through `GET /applications/@me`. Supplying a client and the id avoids
/// startup HTTP requests. Raises `AppConfigError::EmptyToken` for an empty
/// token.
///
/// Command registration is a deploy-time step. Call `app.sync_commands(...)`
/// from a one-shot program (see `src/examples/workers_echo/register`), never
/// per request.
pub async fn App::serve(
  self : App,
  group : @async.TaskGroup[Unit],
  access~ : RestAccess,
  application_id? : @model.ApplicationId,
) -> InteractionEndpoint {
  let (client, owns_client) = match access {
    Client(client) => (client, false)
    Token(token) => {
      guard !token.is_empty() else { raise AppConfigError::EmptyToken }
      (@dhttp.Client(token), true)
    }
  }
  if owns_client {
    group.add_defer(() => client.close())
  }
  let application_id = match application_id {
    Some(id) => id
    None => client.get_current_application().id
  }
  let framework = @framework.Framework(client, application_id)
  self.attach(framework, client~, application_id~) |> ignore
  { framework, group, warn: self.warn_, }
}

///|
/// Dispatch one interaction and wait only for its initial response deadline.
/// `deadline_ms` is measured from this call: routing starts immediately, and
/// time spent waiting for handler capacity counts against it. A timed-out
/// handler remains attached to the app's task group and continues in the
/// background.
pub async fn InteractionEndpoint::handle_interaction(
  self : InteractionEndpoint,
  interaction : @model.Interaction,
  deadline_ms? : Int = 2500,
) -> InteractionOutcome {
  if interaction.typ == Ping {
    return Reply(response={ typ: Pong, data: None, }, files=None)
  }
  let (gate, capture) = @framework.ResponseGate::capture(
    interaction,
    deadline_ms~,
  )
  let race : @aqueue.Queue[InteractionRace] = Queue(kind=Unbounded)
  self.group.spawn_bg(allow_failure=true, () => {
    let routed = self.framework.process_with(interaction, gate~) catch {
      error if @async.is_being_cancelled() => raise error
      error => {
        (self.warn)(InteractionProcessingFailed(error~))
        true
      }
    }
    if gate.is_pending() {
      race.put(Completed(routed))
    }
  })
  @async.with_task_group(group => {
    let capture_task = group.spawn(no_wait=true, allow_failure=true, () => {
      let captured = capture.get()
      race.put(Captured(captured))
      captured
    })
    let result = match @async.with_timeout_opt(deadline_ms, () => race.get()) {
      Some(Captured(captured)) =>
        Reply(response=captured.response, files=captured.files)
      Some(Completed(true)) => NoResponse
      Some(Completed(false)) => NoRoute
      None => {
        gate.expire()
        // The timeout may win after race.get() consumed a captured reply.
        // Retain it in the task so a callback that left Pending is not lost.
        if gate.state() is Sent(_) {
          let captured = capture_task.wait()
          Reply(response=captured.response, files=captured.files)
        } else {
          TimedOut
        }
      }
    }
    capture_task.cancel()
    result
  })
}

///|
/// Decode and dispatch an interaction JSON body.
///
/// Returns callback JSON only for `Reply`. Multipart files cannot be expressed
/// by this thin JSON API; callers that accept uploads should use
/// `handle_interaction` and inspect `InteractionOutcome::Reply.files`.
pub async fn InteractionEndpoint::handle(
  self : InteractionEndpoint,
  body : Json,
  deadline_ms? : Int = 2500,
) -> Json? {
  let interaction : @model.Interaction = @json.from_json(body)
  match self.handle_interaction(interaction, deadline_ms~) {
    Reply(response~, files=_) => Some(response.to_json())
    NoRoute | NoResponse | TimedOut => None
  }
}
