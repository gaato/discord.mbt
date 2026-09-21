///|
/// Harness/configuration failures, distinct from application failures in a result.
pub(all) suberror TestkitError {
  Busy
  FailedHarness
  InvalidConfiguration(String)
  DispatchTimeout
  UnexpectedRest
  RestMismatch
  UnconsumedRest(Int)
} derive(Debug, Eq)

///|
pub(all) enum Routing {
  Matched
  NoRoute
  Rejected
} derive(Debug, Eq)

///|
/// Original errors in observation order; cancellation is never recorded here.
pub(all) enum DispatchFailure {
  App(@app.FailureObservation)
  Dispatch(Error)
} derive(Debug)

///|
/// Independent routing, response and failure axes. Payload accessors return
/// snapshots; errors retain the original Error values in a copied array.
pub struct DispatchResult {
  routing : Routing
  priv response_ : @framework.CapturedResponse?
  priv errors_ : Array[DispatchFailure]
  priv requests_ : Array[@http.PreparedHttpRequest]
}

///|
pub fn DispatchResult::initial_response(
  self : DispatchResult,
) -> @framework.CapturedResponse? {
  self.response_.map(copy_response)
}

///|
pub fn DispatchResult::errors(self : DispatchResult) -> Array[DispatchFailure] {
  self.errors_.copy()
}

///|
pub fn DispatchResult::requests(
  self : DispatchResult,
) -> Array[@http.PreparedHttpRequest] {
  self.requests_.map(copy_request)
}

///|
/// A matched handler that neither responded nor failed.
pub fn DispatchResult::no_response(self : DispatchResult) -> Bool {
  self.routing == Matched && self.response_ is None && self.errors_.is_empty()
}

///|
priv struct RestExpectation {
  route : @http.Route
  response : @http.HttpResponse
}

///|
/// Sequential App executor with strict FIFO REST. It owns no live client
/// between dispatches; separate harnesses can run concurrently.
pub struct Harness {
  priv app_ : @app.App
  priv application_id_ : @model.ApplicationId
  priv script_ : Array[RestExpectation]
  priv mut cursor_ : Int
  priv mut busy_ : Bool
  priv mut failed_ : Bool
  priv mut last_requests_ : Array[@http.PreparedHttpRequest]
}

///|
pub fn Harness::Harness(
  app : @app.App,
  application_id? : @model.ApplicationId,
) -> Harness {
  {
    app_: app,
    application_id_: application_id.unwrap_or(default_application_id()),
    script_: [],
    cursor_: 0,
    busy_: false,
    failed_: false,
    last_requests_: [],
  }
}

///|
/// Queue one response. Matching uses method and exact logical path including
/// query, not rate-limit bucket or Route variant. Payloads are snapshotted.
pub fn Harness::expect_rest(
  self : Harness,
  route : @http.Route,
  response : @http.HttpResponse,
) -> Unit raise TestkitError {
  self.ensure_idle()
  self.script_.push({
    route,
    response: {
      status: response.status,
      headers: response.headers.copy(),
      body: copy_json(response.body),
    },
  })
}

///|
pub fn Harness::assert_rest_complete(self : Harness) -> Unit raise TestkitError {
  self.ensure_idle()
  let remaining = self.script_.length() - self.cursor_
  if remaining != 0 {
    raise UnconsumedRest(remaining)
  }
}

///|
/// Snapshot of the most recent started dispatch's REST attempts, including mismatches.
/// Available after a failed dispatch as well; accessing it does not reset or
/// unpoison the harness. Credentials/payloads are exposed only on request.
pub fn Harness::last_requests(
  self : Harness,
) -> Array[@http.PreparedHttpRequest] {
  self.last_requests_.map(copy_request)
}

///|
fn Harness::ensure_idle(self : Harness) -> Unit raise TestkitError {
  if self.busy_ {
    raise Busy
  }
  if self.failed_ {
    raise FailedHarness
  }
}

///|
priv struct NoWaitLimiter {}

///|
impl @ratelimit.RateLimiter for NoWaitLimiter with fn acquire(
  _,
  _,
  global_exempt~,
) {
  ignore(global_exempt)
}

///|
impl @ratelimit.RateLimiter for NoWaitLimiter with fn release(
  _,
  _,
  status~,
  headers~,
) {
  ignore(status)
  ignore(headers)
}

///|
/// Run real validation, routing, checks, middleware and response validation.
/// Application errors are returned; script violations and timeouts raise after
/// owned tasks finish cleanup. Timeout/script failure poisons this harness.
/// External cancellation propagates and also requires a new harness. Only the
/// harness-created Discord Client is isolated from the network.
pub async fn Harness::dispatch(
  self : Harness,
  interaction : @model.Interaction,
  timeout_ms? : Int = 5000,
) -> DispatchResult {
  self.ensure_idle()
  if timeout_ms <= 0 {
    raise InvalidConfiguration("timeout_ms must be positive")
  }
  if interaction.application_id != self.application_id_ {
    raise InvalidConfiguration(
      "interaction application_id does not match harness",
    )
  }
  self.app_.validate()
  self.busy_ = true
  defer {
    self.busy_ = false
  }
  errdefer {
    self.failed_ = true
  }
  let errors : Array[DispatchFailure] = []
  let requests : Array[@http.PreparedHttpRequest] = []
  self.last_requests_ = requests
  let violation : Ref[TestkitError?] = Ref(None)
  let client = @http.Client(
    "testkit-synthetic-token",
    max_retries=0,
    limiter=NoWaitLimiter::{ },
    transport=request => {
      requests.push(copy_request(request))
      if violation.val is Some(error) {
        raise error
      }
      guard self.script_.get(self.cursor_) is Some(expected) else {
        violation.val = Some(UnexpectedRest)
        raise UnexpectedRest
      }
      if request.route.method_() != expected.route.method_() ||
        request.route.path() != expected.route.path() {
        violation.val = Some(RestMismatch)
        raise RestMismatch
      }
      self.cursor_ += 1
      {
        status: expected.response.status,
        headers: expected.response.headers.copy(),
        body: copy_json(expected.response.body),
      }
    },
  )
  defer client.close()
  let framework = @framework.Framework(client, self.application_id_)
  self.app_.attach(framework, client~, application_id=self.application_id_, failure_observer=observation => {
    errors.push(App(observation))
  })
  |> ignore
  // Capture a snapshot at send time, before a handler can mutate its payload.
  let captured : Ref[@framework.CapturedResponse?] = Ref(None)
  let gate = @framework.ResponseGate(interaction.typ, (response, files) => {
    captured.val = Some(copy_response({ response, files, }))
  })
  let routing = @async.with_timeout(
    timeout_ms,
    () => {
      try framework.process_with(interaction, gate~) catch {
        error if @async.is_being_cancelled() => raise error
        error => {
          errors.push(Dispatch(error))
          return Rejected
        }
      } noraise {
        matched => if matched { Matched } else { NoRoute }
      }
    },
    error=TestkitError::DispatchTimeout,
  )
  if violation.val is Some(error) {
    raise error
  }
  { routing, response_: captured.val, errors_: errors, requests_: requests, }
}
