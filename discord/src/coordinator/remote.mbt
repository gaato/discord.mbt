///|
priv struct CoordinatorClient {
  addr : @socket.Addr
  conn : Ref[@socket.Tcp?]
  gate : @async.Semaphore
  closed : Ref[Bool]
  liveness : Liveness?
}

///|
/// How a client tells a long wait from a hung coordinator: while a request is
/// unanswered, ping over `probe` every `every_ms`, and give up on the request
/// when a ping is not answered within `timeout_ms`.
priv struct Liveness {
  probe : CoordinatorClient
  every_ms : Int32
  timeout_ms : Int32
}

///|
/// Identify and HTTP acquisitions legitimately wait for minutes: Identify
/// spacing grows with the shard count, and some HTTP buckets reset after ten
/// minutes. A deadline long enough for those would not catch anything, so
/// these requests check that the coordinator still answers instead.
const LIVENESS_EVERY_MS : Int32 = 10_000

///|
const LIVENESS_TIMEOUT_MS : Int32 = 5_000

///|
fn CoordinatorClient::CoordinatorClient(
  addr : String,
  liveness? : (Int32, Int32),
) -> CoordinatorClient raise {
  let addr = @socket.Addr::parse(addr) catch {
    error => raise CoordinatorError::Transport(message="\{Repr(error)}")
  }
  let liveness = liveness.map(liveness => {
    let (every_ms, timeout_ms) = liveness
    let probe = {
      addr,
      conn: Ref(None),
      gate: Semaphore(1),
      closed: Ref(false),
      liveness: None,
    }
    { probe, every_ms, timeout_ms, }
  })
  { addr, conn: Ref(None), gate: Semaphore(1), closed: Ref(false), liveness, }
}

///|
async fn CoordinatorClient::connect(
  addr : String,
  liveness~ : (Int32, Int32) = (LIVENESS_EVERY_MS, LIVENESS_TIMEOUT_MS),
) -> CoordinatorClient {
  let client = CoordinatorClient(addr, liveness~)
  client.connection() |> ignore
  client
}

///|
fn CoordinatorClient::close(self : CoordinatorClient) -> Unit {
  self.closed.val = true
  self.drop_connection()
  if self.liveness is Some(liveness) {
    liveness.probe.close()
  }
}

///|
async fn CoordinatorClient::dial(addr : @socket.Addr) -> @socket.Tcp {
  let conn = @socket.Tcp::connect(addr) catch {
    error if @async.is_being_cancelled() => raise error
    error => raise CoordinatorError::Transport(message="\{Repr(error)}")
  }
  keep_alive(conn)
  conn
}

///|
/// Probe an idle connection so a peer whose host died without closing it is
/// noticed in about 25 seconds rather than at the operating system's default
/// of hours. Acquisitions legitimately wait that long and longer for a bucket
/// reset or Identify spacing, so a request timeout cannot tell a dead peer
/// from a slow answer. Best effort: a platform that refuses keeps the default.
fn keep_alive(conn : @socket.Tcp) -> Unit {
  conn.enable_keepalive(
    idle_before_keep_alive=10,
    keep_alive_interval=5,
    keep_alive_count=3,
  ) catch {
    _ => ()
  }
}

///|
async fn CoordinatorClient::connection(self : CoordinatorClient) -> @socket.Tcp {
  if self.closed.val {
    raise CoordinatorError::Disconnected
  }
  match self.conn.val {
    Some(conn) => conn
    None => {
      let conn = CoordinatorClient::dial(self.addr)
      self.conn.val = Some(conn)
      conn
    }
  }
}

///|
fn CoordinatorClient::drop_connection(self : CoordinatorClient) -> Unit {
  if self.conn.val is Some(conn) {
    self.conn.val = None
    conn.close()
  }
}

///|
fn coordinator_retryable(error : Error) -> Bool {
  error is (CoordinatorError::Transport(..) | CoordinatorError::Disconnected)
}

///|
/// One newline-terminated response, or `None` when the connection ends first.
/// An unterminated tail at end of stream is a coordinator dying mid-response,
/// so it reads as a disconnect, which is retried, not as a malformed answer.
/// One request is in flight per connection, so anything after the newline is
/// a protocol error.
async fn read_line(conn : @socket.Tcp) -> String? {
  let reader = LineReader::new()
  match reader.next(chunk => conn.read(chunk)) {
    Line(line) => {
      if reader.has_pending() {
        raise CoordinatorError::InvalidResponse(
          message="data after the response line",
        )
      }
      Some(line)
    }
    Ended => None
    TooLong =>
      raise CoordinatorError::InvalidResponse(
        message="response line longer than \{MAX_LINE_BYTES} bytes",
      )
  }
}

///|
fn coordinator_fatal(error : Error) -> Bool {
  @async.is_being_cancelled() || !coordinator_retryable(error)
}

///|
/// `request_once`, abandoned with a retryable `Transport` error when the
/// coordinator stops answering pings while the request waits.
async fn CoordinatorClient::request_watched(
  self : CoordinatorClient,
  request : Json,
) -> Json {
  guard self.liveness is Some(liveness) else {
    return self.request_once(request)
  }
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      for ;; {
        @async.sleep(liveness.every_ms)
        ignore(
          liveness.probe.request(
            { "op": "ping" },
            max_retry=0,
            timeout_ms=liveness.timeout_ms,
          ),
        ) catch {
          error if @async.is_being_cancelled() => raise error
          error => {
            liveness.probe.drop_connection()
            raise CoordinatorError::Transport(
              message="coordinator did not answer a ping within \{liveness.timeout_ms} ms: \{Repr(error)}",
            )
          }
        }
      }
    })
    self.request_once(request)
  })
}

///|
async fn CoordinatorClient::request_once(
  self : CoordinatorClient,
  request : Json,
) -> Json {
  let conn = self.connection()
  let response_line = try {
    conn.write(request.stringify() + "\n")
    match read_line(conn) {
      Some(line) => line
      None => raise CoordinatorError::Disconnected
    }
  } catch {
    error if @async.is_being_cancelled() => raise error
    CoordinatorError::Disconnected => raise CoordinatorError::Disconnected
    CoordinatorError::InvalidResponse(message~) => {
      // The stream is out of step with the requests; start over.
      self.drop_connection()
      raise CoordinatorError::InvalidResponse(message~)
    }
    error => raise CoordinatorError::Transport(message="\{Repr(error)}")
  } noraise {
    line => line
  }
  decode_response(response_line)
}

///|
async fn CoordinatorClient::request(
  self : CoordinatorClient,
  request : Json,
  max_retry~ : Int32 = 5,
  timeout_ms? : Int32,
) -> Json {
  match timeout_ms {
    Some(timeout_ms) =>
      @async.with_timeout(timeout_ms, () => {
        self.request_with_retry(request, max_retry)
      })
    None => self.request_with_retry(request, max_retry)
  }
}

///|
async fn CoordinatorClient::request_with_retry(
  self : CoordinatorClient,
  request : Json,
  max_retry : Int32,
) -> Json {
  self.gate.acquire()
  defer self.gate.release()
  // Cancellation can bypass catch handlers. Discard a partial exchange
  // before releasing the gate so the next request cannot read its response.
  defer (if @async.is_being_cancelled() { self.drop_connection() })
  if self.closed.val {
    raise CoordinatorError::Disconnected
  }
  // Identify and HTTP remotes can replay: identify holds no connection-owned state,
  // disconnect cleanup releases acquired HTTP buckets, and releasing an
  // already-cleaned bucket is a server-side no-op. A lost identify response
  // can repeat the spacing wait, but cannot leak a slot. Cooldowns disable retries.
  @async.retry(
    ExponentialDelay(initial=200, factor=2.0, maximum=5000),
    max_retry~,
    fatal_error=coordinator_fatal,
    () => {
      self.request_watched(request) catch {
        error if @async.is_being_cancelled() => {
          self.drop_connection()
          raise error
        }
        error if coordinator_retryable(error) => {
          self.drop_connection()
          raise error
        }
        error => raise error
      }
    },
  )
}

///|
/// Cross-process implementation of `IdentifyQueue`.
pub struct RemoteIdentifyQueue {
  priv client : CoordinatorClient
}

///|
/// Open the initial coordinator connection.
///
/// Later transport failures reconnect automatically with bounded backoff.
pub async fn RemoteIdentifyQueue::connect(addr : String) -> RemoteIdentifyQueue {
  { client: CoordinatorClient::connect(addr), }
}

///|
/// Close the coordinator connection; in-flight and later requests fail.
pub fn RemoteIdentifyQueue::close(self : RemoteIdentifyQueue) -> Unit {
  self.client.close()
}

///|
/// Round-trip a ping through the coordinator to verify connectivity.
pub async fn RemoteIdentifyQueue::ping(self : RemoteIdentifyQueue) -> Unit {
  self.client.request({ "op": "ping" }) |> ignore
}

///|
/// Makes `queue.wait_for_identify(shard_id)` callable as a method.
pub extend RemoteIdentifyQueue with @queue.IdentifyQueue::{wait_for_identify}

///|
/// Acquire the shard's identify slot from the coordinator process.
pub impl @queue.IdentifyQueue for RemoteIdentifyQueue with fn wait_for_identify(
  self,
  shard_id,
) {
  self.client.request({ "op": "identify_acquire", "shard_id": shard_id })
  |> ignore
}

///|
/// Cross-process implementation of `RateLimiter`.
pub struct RemoteRateLimiter {
  priv acquire_client : CoordinatorClient
  priv release_client : CoordinatorClient
  priv leases : Map[String, Json]
}

///|
/// Open the initial coordinator connections.
///
/// Later transport failures reconnect automatically with bounded backoff.
pub async fn RemoteRateLimiter::connect(addr : String) -> RemoteRateLimiter {
  RemoteRateLimiter::connect_with(addr, addr => CoordinatorClient::connect(addr))
}

///|
async fn RemoteRateLimiter::connect_with(
  addr : String,
  connector : async (String) -> CoordinatorClient,
) -> RemoteRateLimiter {
  let acquire_client = connector(addr)
  errdefer acquire_client.close()
  let release_client = connector(addr)
  { acquire_client, release_client, leases: Map([]), }
}

///|
/// Close both coordinator connections; in-flight and later requests fail.
pub fn RemoteRateLimiter::close(self : RemoteRateLimiter) -> Unit {
  self.acquire_client.close()
  self.release_client.close()
  self.leases.clear()
}

///|
/// Round-trip a ping through the coordinator to verify connectivity.
pub async fn RemoteRateLimiter::ping(self : RemoteRateLimiter) -> Unit {
  self.acquire_client.request({ "op": "ping" }) |> ignore
}

///|
/// Makes `acquire` and `release` callable as methods on the limiter.
pub extend RemoteRateLimiter with @runtime.RateLimiter::{acquire, release}

///|
/// Acquire the HTTP bucket slot from the coordinator's shared accounting.
pub impl @runtime.RateLimiter for RemoteRateLimiter with fn acquire(
  self,
  bucket_key,
  global_exempt~,
) {
  let response = self.acquire_client.request({
    "op": "http_acquire",
    "bucket": Json::string(bucket_key),
    "global_exempt": global_exempt,
    // Lets the coordinator refuse clients that predate string leases; an
    // older coordinator ignores it.
    "leases": "string",
  })
  // The lease is opaque; an older coordinator sends an integer.
  guard response is { "lease": lease, .. } &&
    (lease is String(_) || json_nonnegative_int(lease) is Some(_)) else {
    raise CoordinatorError::InvalidResponse(message="missing lease")
  }
  self.leases[bucket_key] = lease
}

///|
/// Report the response's rate-limit headers back to the coordinator. A
/// release cut short by cancellation is recovered by the `errdefer` below, as
/// the runtime's `RateLimiter` contract requires.
pub impl @runtime.RateLimiter for RemoteRateLimiter with fn release(
  self,
  bucket_key,
  status~,
  headers~,
) {
  guard self.leases.get(bucket_key) is Some(lease) else {
    raise CoordinatorError::InvalidResponse(message="bucket is not acquired")
  }
  errdefer {
    // The acquire connection owns the server-side gate. If release cannot be
    // confirmed, dropping it makes EOF cleanup release that ownership.
    self.acquire_client.drop_connection()
    self.leases.remove(bucket_key)
  }
  ignore(
    self.release_client.request({
      "op": "http_release",
      "bucket": Json::string(bucket_key),
      "lease": lease,
      "status": status,
      "headers": encode_headers(headers),
    }),
  )
  self.leases.remove(bucket_key)
}

///|
/// Cross-process cooldown windows using the coordinator's clock.
///
/// An unreachable coordinator yields `Unavailable`, and the App applies its
/// `cooldown_outage` policy and warns once per outage. RemoteRateLimiter, by
/// contrast, fails closed because avoiding Discord's 429 bans is a
/// correctness concern. Cancellation always propagates.
pub struct RemoteCooldownStore {
  priv client : CoordinatorClient
  priv timeout_ms : Int32
}

///|
/// Open a dedicated connection, independent of blocking HTTP acquisitions.
/// Each acquisition has no retries and a `timeout_ms` deadline, including queue
/// and reconnect time; a transport failure or timeout yields `Unavailable`.
/// Other errors propagate. A coordinator unreachable at startup still returns
/// a store; later acquisitions attempt to reconnect within the same deadline.
pub async fn RemoteCooldownStore::connect(
  addr : String,
  timeout_ms~ : Int32 = 1000,
) -> RemoteCooldownStore {
  if timeout_ms <= 0 {
    raise CoordinatorError::InvalidConfig(message="timeout_ms must be positive")
  }
  let client = CoordinatorClient(addr)
  @async.with_timeout(timeout_ms, () => client.connection() |> ignore) catch {
    error if @async.is_being_cancelled() => {
      client.close()
      raise error
    }
    error if coordinator_unreachable(error) => client.drop_connection()
    error => raise error
  }
  { client, timeout_ms, }
}

///|
/// Close the connection permanently. Later acquisitions yield `Unavailable`.
pub fn RemoteCooldownStore::close(self : RemoteCooldownStore) -> Unit {
  self.client.close()
}

///|
/// Check connectivity within the deadline, without retries or a fallback.
pub async fn RemoteCooldownStore::ping(self : RemoteCooldownStore) -> Unit {
  self.client.request({ "op": "ping" }, max_retry=0, timeout_ms=self.timeout_ms)
  |> ignore
}

///|
fn coordinator_unreachable(error : Error) -> Bool {
  coordinator_retryable(error) || error is @async.TimeoutError
}

///|
/// Makes `store.try_acquire(key, window_ms=...)` callable as a method.
pub extend RemoteCooldownStore with @cooldown.CooldownStore::{try_acquire}

///|
/// Asks the coordinator to start the window for `key`; an unreachable
/// coordinator or a missed deadline yields `Unavailable`.
pub impl @cooldown.CooldownStore for RemoteCooldownStore with fn try_acquire(
  self,
  key,
  window_ms~,
) {
  let response = self.client.request(
    cooldown_acquire_request(key, window_ms),
    max_retry=0,
    timeout_ms=self.timeout_ms,
  ) catch {
    error if @async.is_being_cancelled() => raise error
    error if coordinator_unreachable(error) =>
      return Unavailable(reason="\{Repr(error)}")
    error => raise error
  }
  decode_cooldown(response)
}
