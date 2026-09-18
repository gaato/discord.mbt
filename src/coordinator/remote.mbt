///|
priv struct CoordinatorClient {
  addr : @socket.Addr
  conn : Ref[@socket.Tcp?]
  gate : @async.Semaphore
  closed : Ref[Bool]
}

///|
async fn CoordinatorClient::connect(addr : String) -> CoordinatorClient {
  let addr = @socket.Addr::parse(addr) catch {
    error => raise CoordinatorError::Transport(message="\{error}")
  }
  let conn = CoordinatorClient::dial(addr)
  { addr, conn: Ref(Some(conn)), gate: Semaphore(1), closed: Ref(false), }
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
) -> Json {
  self.gate.acquire()
  defer self.gate.release()
  if self.closed.val {
    raise CoordinatorError::Disconnected
  }
  // Replaying is safe: identify requests hold no connection-owned state,
  // disconnect cleanup releases acquired HTTP buckets, and releasing an
  // already-cleaned bucket is a server-side no-op. A lost identify response
  // can repeat the spacing wait, but cannot leak a slot.
  @async.retry(
    ExponentialDelay(initial=200, factor=2.0, maximum=5000),
    max_retry=5,
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
/// Acquire the HTTP bucket slot from the coordinator's shared accounting.
pub impl @ratelimit.RateLimiter for RemoteRateLimiter with fn acquire(
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
/// Report the response's rate-limit headers back to the coordinator.
pub impl @ratelimit.RateLimiter for RemoteRateLimiter with fn release(
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
      "headers": headers.to_json(),
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
