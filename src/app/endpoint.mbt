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
  priv spawner : Spawner
  priv warn : (String) -> Unit
}

///|
priv enum InteractionRace {
  Captured(@framework.CapturedResponse)
  Completed(Bool)
}

///|
/// Build a gateway-free dispatcher.
///
/// When `client` is omitted, the endpoint owns a client created from `token`
/// and closes it when `group` finishes. When `application_id` is omitted, this
/// method resolves it through `GET /applications/@me`. Supplying both values
/// avoids startup HTTP requests.
///
/// Command registration is a deploy-time step. Call `app.sync_commands(...)`
/// from a one-shot program (see `src/examples/workers_echo/register`), never
/// per request.
pub async fn App::serve(
  self : App,
  group : @async.TaskGroup[Unit],
  client? : @dhttp.Client,
  token? : String,
  application_id? : @model.ApplicationId,
) -> InteractionEndpoint {
  self.validate()
  let (client, owns_client) = match client {
    Some(client) => (client, false)
    None => {
      guard token is Some(token) && !token.is_empty() else {
        raise AppConfigError::EmptyToken
      }
      (Client(token), true)
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
  { framework, spawner: self.spawner(group), warn: self.warn_, }
}

///|
/// Dispatch one interaction and wait only for its initial response deadline.
/// A timed-out handler remains attached to the app's task group and continues
/// in the background.
pub async fn InteractionEndpoint::handle_interaction(
  self : InteractionEndpoint,
  interaction : @model.Interaction,
  deadline_ms? : Int = 2500,
) -> InteractionOutcome {
  if interaction.typ == Ping {
    return Reply(response={ typ: Pong, data: None, }, files=None)
  }
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  let race : @aqueue.Queue[InteractionRace] = Queue(kind=Unbounded)
  (self.spawner)(() => {
    let routed = self.framework.process_with(interaction, gate~) catch {
      error if @async.is_being_cancelled() => raise error
      error => {
        (self.warn)("interaction processing failed: \{Repr(error)}")
        true
      }
    }
    if !gate.responded() {
      race.put(Completed(routed))
    }
  })
  @async.with_task_group(group => {
    let capture_task = group.spawn(no_wait=true, allow_failure=true, () => {
      race.put(Captured(capture.get()))
    })
    let result = match @async.with_timeout_opt(deadline_ms, () => race.get()) {
      Some(Captured(captured)) =>
        Reply(response=captured.response, files=captured.files)
      Some(Completed(true)) => NoResponse
      Some(Completed(false)) => NoRoute
      None => TimedOut
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
