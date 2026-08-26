///|
/// A lightweight TCP coordinator shared by multiple bot processes.
pub struct Coordinator {
  priv address : String
  priv runner : Ref[@async.TaskGroup[Unit]?]
}

///|
priv struct CoordinatorState {
  identify : @queue.InMemoryQueue
  limiter : @ratelimit.InMemoryRateLimiter
  owners : Map[String, BucketOwner]
  next_connection_id : Ref[Int]
  next_lease_id : Ref[Int]
}

///|
priv struct ConnectionState {
  id : Int
  held_buckets : Ref[Map[String, Int]]
}

///|
priv struct BucketOwner {
  connection : ConnectionState
  lease : Int
}

///|
/// Start a JSON-lines coordinator in `group`.
///
/// Use port zero in `addr` to let the OS choose a free port, then pass
/// `coordinator.addr()` to remote clients.
pub async fn[X] Coordinator::serve(
  group : @async.TaskGroup[X],
  addr~ : String,
  max_concurrency? : Int = 1,
  identify_spacing_ms? : Int = 5250,
  global_limit? : Int = 50,
) -> Coordinator {
  if max_concurrency <= 0 {
    raise CoordinatorError::InvalidConfig(
      message="max_concurrency must be positive",
    )
  }
  if identify_spacing_ms < 0 {
    raise CoordinatorError::InvalidConfig(
      message="identify_spacing_ms must not be negative",
    )
  }
  if global_limit <= 0 {
    raise CoordinatorError::InvalidConfig(
      message="global_limit must be positive",
    )
  }
  let server = @socket.TcpServer(@socket.Addr::parse(addr), reuse_addr=true)
  let state = CoordinatorState::{
    identify: InMemoryQueue(max_concurrency~, spacing_ms=identify_spacing_ms),
    limiter: InMemoryRateLimiter(global_limit~),
    owners: Map([]),
    next_connection_id: Ref(0),
    next_lease_id: Ref(0),
  }
  let runner : Ref[@async.TaskGroup[Unit]?] = Ref(None)
  let started = @async.Semaphore(1, initial_value=0)
  group.spawn_bg(allow_failure=true, () => {
    @async.with_task_group(inner => {
      runner.val = Some(inner)
      started.release()
      inner.spawn_bg(() => {
        server.run_forever(allow_failure=true, (conn, _) => {
          serve_connection(conn, state)
        })
      })
    })
  })
  started.acquire()
  { address: server.addr.to_string(), runner }
}

///|
/// Return the actual listening address, including an OS-assigned port.
pub fn Coordinator::addr(self : Coordinator) -> String {
  self.address
}

///|
/// Stop accepting clients and close active coordinator connections.
///
/// Shutdown cancels the internal task group; cancellation wakes every
/// connection handler, and `run_forever` then closes each client socket and
/// the listener itself (its documented contract forbids closing them here).
pub fn Coordinator::close(self : Coordinator) -> Unit {
  if self.runner.val is Some(inner) {
    inner.return_immediately(()) catch {
      // The runner group already returned; shutdown is idempotent.
      _ => ()
    }
  }
}

///|
async fn serve_connection(conn : @socket.Tcp, state : CoordinatorState) -> Unit {
  let connection = ConnectionState::{
    id: state.next_connection_id.val,
    held_buckets: Ref(Map([])),
  }
  state.next_connection_id.val += 1
  defer @async.protect_from_cancel(() => {
    cleanup_connection(state, connection) catch {
      _ => ()
    }
  })
  while conn.read_until("\n") is Some(line) {
    let response = try
      dispatch_request(@json.parse(line), state, connection)
    catch {
      error if @async.is_being_cancelled() ||
        @async.is_cancellation_error(error) => raise error
      error => error_response("invalid request: \{error}")
    } noraise {
      response => response
    }
    conn.write(response.stringify() + "\n")
  }
}

///|
async fn cleanup_connection(
  state : CoordinatorState,
  connection : ConnectionState,
) -> Unit {
  let held = [ for bucket, _lease in connection.held_buckets.val => bucket ]
  for bucket in held {
    if state.owners.get(bucket) is Some(owner) &&
      owner.connection.id == connection.id {
      state.owners.remove(bucket)
      state.limiter.release(bucket, status=0, headers=Map([]))
    }
    connection.held_buckets.val.remove(bucket)
  }
}

///|
async fn dispatch_request(
  request : Json,
  state : CoordinatorState,
  connection : ConnectionState,
) -> Json {
  guard request is { "op": String(op), .. } else {
    return error_response("missing string op")
  }
  match op {
    "ping" => ok_response()
    "identify_acquire" => {
      guard request is { "shard_id": shard_json, .. } &&
        json_nonnegative_int(shard_json) is Some(shard_id) else {
        return error_response(
          "identify_acquire requires a non-negative integer shard_id",
        )
      }
      state.identify.wait_for_identify(shard_id)
      ok_response()
    }
    "http_acquire" => {
      guard request
        is { "bucket": String(bucket), "global_exempt": exempt_json, .. } &&
        json_bool(exempt_json) is Some(global_exempt) else {
        return error_response(
          "http_acquire requires bucket and boolean global_exempt",
        )
      }
      state.limiter.acquire(bucket, global_exempt~)
      let lease = state.next_lease_id.val
      state.next_lease_id.val += 1
      state.owners[bucket] = BucketOwner::{ connection, lease }
      connection.held_buckets.val[bucket] = lease
      { "ok": true, "lease": lease }
    }
    "http_release" => {
      guard request
        is {
          "bucket": String(bucket),
          "lease": lease_json,
          "status": status_json,
          "headers": Object(header_fields),
          ..
        } &&
        json_nonnegative_int(status_json) is Some(status) &&
        json_nonnegative_int(lease_json) is Some(lease) else {
        return error_response(
          "http_release requires bucket, lease, non-negative integer status, and headers object",
        )
      }
      let headers = decode_headers(header_fields) catch {
        error => return error_response("invalid headers: \{error}")
      }
      if state.owners.get(bucket) is Some(owner) && owner.lease == lease {
        state.limiter.release(bucket, status~, headers~)
        owner.connection.held_buckets.val.remove(bucket)
        state.owners.remove(bucket)
      }
      ok_response()
    }
    unknown => error_response("unknown op: \{unknown}")
  }
}
