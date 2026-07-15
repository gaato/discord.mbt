///|
#external
pub type WorkerResponse

///|
extern "js" fn WorkerResponse::WorkerResponse(
  kind : String,
  body : String,
) -> Self =
  #| (kind, body) => ({ kind, body })

///|
pub extern "js" fn WorkerResponse::kind(self : Self) -> String =
  #| (response) => response.kind

///|
pub extern "js" fn WorkerResponse::body(self : Self) -> String =
  #| (response) => response.body

///|
#external
pub type WorkerDispatch

///|
extern "js" fn WorkerDispatch::WorkerDispatch(
  response : @js_async.Promise[WorkerResponse],
  background : @js_async.Promise[Unit],
) -> Self =
  #| (response, background) => ({ response, background })

///|
pub extern "js" fn WorkerDispatch::response(
  self : Self,
) -> @js_async.Promise[WorkerResponse] =
  #| (dispatch) => dispatch.response

///|
pub extern "js" fn WorkerDispatch::background(
  self : Self,
) -> @js_async.Promise[Unit] =
  #| (dispatch) => dispatch.background

///|
fn echo_command() -> @discord.Command[String] {
  @discord.slash(
    name="echo",
    description="Echo text from a Cloudflare Worker",
    args=@discord.Args::of(
      @discord.arg_string(name="text", description="What to echo"),
    ),
    handler=Immediate((_, text) => @discord.CommandReply::message(content=text)),
  )
}

///|
fn slow_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="slow",
    description="Defer, then finish in waitUntil",
    args=@discord.Args::unit(),
    handler=Deferred(ephemeral=false, (ctx, _) => {
      @async.sleep(500)
      ctx.edit_original(content="Finished in the background.") |> ignore
    }),
  )
}

///|
fn worker_app() -> @discord.App {
  let app = @discord.App(sync=Disabled)
  app..command(echo_command()).command(slow_command())
  app
}

///|
fn encode_outcome(outcome : @discord.InteractionOutcome) -> WorkerResponse {
  match outcome {
    Reply(response~, files=_) =>
      WorkerResponse("Reply", response.to_json().stringify())
    NoRoute => WorkerResponse("NoRoute", "")
    NoResponse => WorkerResponse("NoResponse", "")
    TimedOut => WorkerResponse("TimedOut", "")
  }
}

///|
async fn run_interaction(
  token : String,
  body : String,
  responses : @aqueue.Queue[WorkerResponse],
) -> Unit {
  let mut response_sent = false
  @async.with_task_group(group => {
    let interaction : @model.Interaction = @json.from_json(@json.parse(body))
    let client = @discord.Client(token)
    group.add_defer(() => client.close())
    let endpoint = worker_app().serve(
      group,
      client~,
      application_id=interaction.application_id,
      sync=false,
    )
    responses.put(encode_outcome(endpoint.handle_interaction(interaction)))
    response_sent = true
  }) catch {
    error => {
      if !response_sent {
        responses.put(WorkerResponse("NoResponse", ""))
      }
      raise error
    }
  }
}

///|
/// Start one interaction dispatch as two JavaScript promises.
///
/// The `response` property resolves with `{ kind, body }` as soon as the
/// initial Discord callback is known. The `background` property resolves only
/// after the endpoint's task group and every deferred handler have completed.
pub fn start_interaction(
  token : String,
  body : String,
  abort_signal : @js_async.AbortSignal,
) -> WorkerDispatch {
  let responses : @aqueue.Queue[WorkerResponse] = Queue(kind=Unbounded)
  let background = @js_async.Promise::from_async(() => {
    run_interaction(token, body, responses)
  })
  // A client disconnect only cancels the initial-response waiter. The task
  // group belongs to the waitUntil background promise and must keep running
  // so deferred handlers can finish after the HTTP request ends.
  let response = @js_async.Promise::from_async(
    () => responses.get(),
    abort_signal~,
  )
  WorkerDispatch(response, background)
}

///|
/// Expose the JS-only facade signature verifier as a JavaScript promise.
pub fn verify_signature(
  public_key : String,
  signature : String,
  timestamp : String,
  body : String,
) -> @js_async.Promise[Bool] {
  @js_async.Promise::from_async(() => {
    @discord.verify_signature(public_key~, signature~, timestamp~, body~)
  })
}
