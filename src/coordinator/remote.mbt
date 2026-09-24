///|
priv struct CoordinatorClient {
  addr : @socket.Addr
  conn : Ref[@socket.Tcp?]
  gate : @async.Semaphore
  closed : Ref[Bool]
}

///|
fn CoordinatorClient::CoordinatorClient(
  addr : String,
) -> CoordinatorClient raise {
  let addr = @socket.Addr::parse(addr) catch {
    error => raise CoordinatorError::Transport(message="\{error}")
  }
  { addr, conn: Ref(None), gate: Semaphore(1), closed: Ref(false), }
}

///|
async fn CoordinatorClient::connect(addr : String) -> CoordinatorClient {
  let client = CoordinatorClient(addr)
  client.connection() |> ignore
  client
}

///|
fn CoordinatorClient::close(self : CoordinatorClient) -> Unit {
  self.closed.val = true
  self.drop_connection()
}

///|
async fn CoordinatorClient::dial(addr : @socket.Addr) -> @socket.Tcp {
  @socket.Tcp::connect(addr) catch {
    error if @async.is_being_cancelled() => raise error
    error => raise CoordinatorError::Transport(message="\{error}")
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
fn coordinator_fatal(error : Error) -> Bool {
  @async.is_being_cancelled() || !coordinator_retryable(error)
}

///|
async fn CoordinatorClient::request_once(
  self : CoordinatorClient,
  request : Json,
) -> Json {
  let conn = self.connection()
  let response_line = try {
    conn.write(request.stringify() + "\n")
    match conn.read_until("\n") {
      Some(line) => line
      None => raise CoordinatorError::Disconnected
    }
  } catch {
    error if @async.is_being_cancelled() => raise error
    CoordinatorError::Disconnected => raise CoordinatorError::Disconnected
    error => raise CoordinatorError::Transport(message="\{error}")
  } noraise {
    line => line
  }
  let response = @json.parse(response_line) catch {
    error =>
      raise CoordinatorError::InvalidResponse(message="invalid JSON: \{error}")
  }
  match response {
    { "ok": True, .. } => response
    { "ok": False, "error": String(message), .. } =>
      raise CoordinatorError::Remote(message~)
    _ =>
      raise CoordinatorError::InvalidResponse(message="expected an ok response")
  }
}

///|
async fn CoordinatorClient::request(
  self : CoordinatorClient,
  request : Json,
  max_retry? : Int = 5,
  timeout_ms? : Int,
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
  max_retry : Int,
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
      self.request_once(request) catch {
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
  priv leases : Map[String, Int]
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
  })
  guard response is { "lease": lease_json, .. } &&
    coordinator_nonnegative_int(lease_json) is Some(lease) else {
    raise CoordinatorError::InvalidResponse(message="missing integer lease")
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
fn coordinator_nonnegative_int(value : Json) -> Int? {
  guard value is Number(number, ..) else { return None }
  let integer = number.to_int()
  if integer >= 0 && integer.to_double() == number {
    Some(integer)
  } else {
    None
  }
}

///|
/// Admission policy when the cooldown coordinator is unreachable.
pub(all) enum UnreachablePolicy {
  FailOpen
  FailClosed
} derive(Debug, Eq)

///|
/// Cross-process cooldown windows using the coordinator's clock.
///
/// FailOpen is the default: cooldowns damp abuse, so an outage should not take
/// every command offline. RemoteRateLimiter remains fail-closed because avoiding
/// Discord's 429 bans is a correctness concern. Cancellation always propagates.
pub struct RemoteCooldownStore {
  priv client : CoordinatorClient
  priv timeout_ms : Int
  priv policy : UnreachablePolicy
  priv on_error : (Error) -> Unit
}

///|
/// Open a dedicated connection, independent of blocking HTTP acquisitions.
/// Each acquisition has no retries and a `timeout_ms` deadline, including queue
/// and reconnect time. Transport failures and timeouts call `on_error`, then
/// use `when_unreachable`: Acquired for FailOpen, or Active for the requested window
/// for FailClosed. Other errors propagate. The default error hook does nothing.
/// An initial connection outage is reported but still returns a store; later
/// acquisitions attempt to reconnect within the same deadline.
pub async fn RemoteCooldownStore::connect(
  addr : String,
  timeout_ms? : Int = 1000,
  when_unreachable? : UnreachablePolicy = FailOpen,
  on_error? : (Error) -> Unit,
) -> RemoteCooldownStore {
  if timeout_ms <= 0 {
    raise CoordinatorError::InvalidConfig(message="timeout_ms must be positive")
  }
  let client = CoordinatorClient(addr)
  let on_error = on_error.unwrap_or_else(() => _ => ())
  @async.with_timeout(timeout_ms, () => client.connection() |> ignore) catch {
    error if @async.is_being_cancelled() => {
      client.close()
      raise error
    }
    error if coordinator_unreachable(error) => {
      client.drop_connection()
      on_error(error)
    }
    error => raise error
  }
  { client, timeout_ms, policy: when_unreachable, on_error, }
}

///|
/// Close the connection permanently. Later acquisitions use `when_unreachable`.
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
pub extend RemoteCooldownStore with @cooldown.CooldownStore::{try_acquire}

///|
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
    error if coordinator_unreachable(error) => {
      (self.on_error)(error)
      return match self.policy {
        FailOpen => Acquired
        FailClosed => Active(retry_after_ms=window_ms)
      }
    }
    error => raise error
  }
  guard response is { "retry_after_ms": retry_json, .. } &&
    json_nonnegative_int64(retry_json) is Some(retry_after_ms) else {
    raise CoordinatorError::InvalidResponse(
      message="missing non-negative decimal string retry_after_ms",
    )
  }
  if retry_after_ms == 0L {
    Acquired
  } else {
    Active(retry_after_ms~)
  }
}
