///|
priv struct CoordinatorClient {
  conn : @socket.Tcp
  gate : @async.Semaphore
}

///|
async fn CoordinatorClient::connect(addr : String) -> CoordinatorClient {
  let conn = @socket.Tcp::connect(@socket.Addr::parse(addr)) catch {
    error => raise CoordinatorError::Transport(message="\{error}")
  }
  { conn, gate: Semaphore(1) }
}

///|
fn CoordinatorClient::close(self : CoordinatorClient) -> Unit {
  self.conn.close()
}

///|
async fn CoordinatorClient::request(
  self : CoordinatorClient,
  request : Json,
) -> Unit {
  self.gate.acquire()
  let response_line = try {
    self.conn.write(request.stringify() + "\n")
    match self.conn.read_until("\n") {
      Some(line) => line
      None => raise CoordinatorError::Disconnected
    }
  } catch {
    CoordinatorError::Disconnected => {
      self.gate.release()
      raise CoordinatorError::Disconnected
    }
    error => {
      self.gate.release()
      raise CoordinatorError::Transport(message="\{error}")
    }
  } noraise {
    line => {
      self.gate.release()
      line
    }
  }
  let response = @json.parse(response_line) catch {
    error =>
      raise CoordinatorError::InvalidResponse(message="invalid JSON: \{error}")
  }
  match response {
    { "ok": True, .. } => ()
    { "ok": False, "error": String(message), .. } =>
      raise CoordinatorError::Remote(message~)
    _ =>
      raise CoordinatorError::InvalidResponse(message="expected an ok response")
  }
}

///|
/// Cross-process implementation of `IdentifyQueue`.
pub struct RemoteIdentifyQueue {
  priv client : CoordinatorClient
}

///|
/// Open one persistent connection to a coordinator.
pub async fn RemoteIdentifyQueue::connect(addr : String) -> RemoteIdentifyQueue {
  { client: CoordinatorClient::connect(addr) }
}

///|
pub fn RemoteIdentifyQueue::close(self : RemoteIdentifyQueue) -> Unit {
  self.client.close()
}

///|
pub async fn RemoteIdentifyQueue::ping(self : RemoteIdentifyQueue) -> Unit {
  self.client.request({ "op": "ping" })
}

///|
pub impl @queue.IdentifyQueue for RemoteIdentifyQueue with fn wait_for_identify(
  self,
  shard_id,
) {
  self.client.request({ "op": "identify_acquire", "shard_id": shard_id })
}

///|
/// Cross-process implementation of `RateLimiter`.
pub struct RemoteRateLimiter {
  priv acquire_client : CoordinatorClient
  priv release_client : CoordinatorClient
}

///|
/// Open one persistent connection to a coordinator.
pub async fn RemoteRateLimiter::connect(addr : String) -> RemoteRateLimiter {
  let acquire_client = CoordinatorClient::connect(addr)
  let release_client = CoordinatorClient::connect(addr) catch {
    error => {
      acquire_client.close()
      raise error
    }
  }
  { acquire_client, release_client }
}

///|
pub fn RemoteRateLimiter::close(self : RemoteRateLimiter) -> Unit {
  self.acquire_client.close()
  self.release_client.close()
}

///|
pub async fn RemoteRateLimiter::ping(self : RemoteRateLimiter) -> Unit {
  self.acquire_client.request({ "op": "ping" })
}

///|
pub impl @ratelimit.RateLimiter for RemoteRateLimiter with fn acquire(
  self,
  bucket_key,
  global_exempt~,
) {
  self.acquire_client.request({
    "op": "http_acquire",
    "bucket": Json::string(bucket_key),
    "global_exempt": global_exempt,
  })
}

///|
pub impl @ratelimit.RateLimiter for RemoteRateLimiter with fn release(
  self,
  bucket_key,
  status~,
  headers~,
) {
  self.release_client.request({
    "op": "http_release",
    "bucket": Json::string(bucket_key),
    "status": status,
    "headers": headers.to_json(),
  })
}
