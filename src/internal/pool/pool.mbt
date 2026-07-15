///|
/// A keep-alive pool of `@http.Client` connections to one origin.
///
/// `@http.Client` is a single HTTP/1.1 connection with one request in flight,
/// so concurrency requires several of them. Invariants:
/// - a connection is returned to the idle list only after its response body
///   has been fully consumed (the caller's callback must guarantee this);
/// - on any error the connection is closed and dropped, never reused;
/// - total live connections are capped by a semaphore.
pub struct Pool {
  uri : String
  idle : Array[@http.Client]
  slots : @async.Semaphore
  mut closed : Bool
}

///|
pub fn Pool::Pool(uri : String, max_connections? : Int = 4) -> Pool {
  { uri, idle: [], slots: Semaphore(max_connections), closed: false }
}

///|
pub suberror PoolClosed derive(Debug)

///|
/// Run `f` with a connection checked out of the pool. The connection is
/// reused afterwards if `f` succeeds, closed and discarded if it raises.
pub async fn[T] Pool::with_conn(
  self : Pool,
  f : async (@http.Client) -> T,
) -> T {
  guard !self.closed else { raise PoolClosed }
  self.slots.acquire()
  let conn = match self.idle.pop() {
    Some(c) => c
    None =>
      Client(self.uri) catch {
        e => {
          self.slots.release()
          raise e
        }
      }
  }
  try {
    let result = f(conn)
    if self.closed {
      conn.close()
    } else {
      self.idle.push(conn)
    }
    self.slots.release()
    result
  } catch {
    e => {
      conn.close()
      self.slots.release()
      raise e
    }
  }
}

///|
/// Close all idle connections and refuse new checkouts.
pub fn Pool::close(self : Pool) -> Unit {
  self.closed = true
  for conn in self.idle {
    conn.close()
  }
  self.idle.clear()
}
