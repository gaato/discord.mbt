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
pub struct InteractionApp {
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
/// When `client` is omitted, the app owns a client created from the bot token
/// and closes it when `group` finishes. When `application_id` is omitted, this
/// method always resolves it through `GET /applications/@me`, including when
/// `sync` is false. Supplying both values avoids startup HTTP requests when
/// synchronization is disabled.
///
/// If `sync` is true, command synchronization follows the bot's `CommandSync`
/// setting; `CommandSync::Disabled` still performs no synchronization.
pub async fn Bot::start_interaction_app(
  self : Bot,
  group : @async.TaskGroup[Unit],
  client? : @dhttp.Client,
  application_id? : @model.ApplicationId,
  sync? : Bool = false,
) -> InteractionApp {
  self.validate()
  let owns_client = client is None
  let client = client.unwrap_or_else(() => @dhttp.Client::new(self.token_))
  if owns_client {
    group.add_defer(() => client.close())
  }
  let application_id = match application_id {
    Some(id) => id
    None => client.get_current_application().id
  }
  if sync {
    self.sync_commands(client, application_id)
  }
  let framework = @framework.Framework::new(client, application_id)
  let bot : BotCtx = { client_: client, application_id_: application_id }
  self.populate_framework(framework, bot, None)
  let limiter = @async.Semaphore::new(self.max_in_flight_)
  { framework, spawner: bounded_spawner(group, limiter), warn: self.warn_ }
}

///|
/// Dispatch one interaction and wait only for its initial response deadline.
/// A timed-out handler remains attached to the app's task group and continues
/// in the background.
pub async fn InteractionApp::handle_interaction(
  self : InteractionApp,
  interaction : @model.Interaction,
  deadline_ms? : Int = 2500,
) -> InteractionOutcome {
  if interaction.typ == Ping {
    return Reply(response={ typ: Pong, data: None }, files=None)
  }
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  let race : @aqueue.Queue[InteractionRace] = @aqueue.Queue::new(kind=Unbounded)
  (self.spawner)(() => {
    let routed = self.framework.process_with(interaction, gate~) catch {
      error if @async.is_being_cancelled() ||
        @async.is_cancellation_error(error) => raise error
      error => {
        (self.warn)("interaction processing failed: \{to_repr(error)}")
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
pub async fn InteractionApp::handle(
  self : InteractionApp,
  body : Json,
  deadline_ms? : Int = 2500,
) -> Json? {
  let interaction : @model.Interaction = @json.from_json(body)
  match self.handle_interaction(interaction, deadline_ms~) {
    Reply(response~, files=_) => Some(response.to_json())
    NoRoute | NoResponse | TimedOut => None
  }
}
