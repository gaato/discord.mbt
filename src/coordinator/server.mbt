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
  owners : Map[String, ConnectionState]
  next_connection_id : Ref[Int]
}

///|
priv struct ConnectionState {
  id : Int
  held_buckets : Map[String, Bool]
}

///|
/// Start a JSON-lines coordinator in `group`.
///
/// Use port zero in `addr` to let the OS choose a free port, then pass
/// `coordinator.addr()` to remote clients.
pub fn[X] Coordinator::serve(
  group : @async.TaskGroup[X],
  addr~ : String,
  max_concurrency? : Int = 1,
  identify_spacing_ms? : Int = 5250,
  global_limit? : Int = 50,
) -> Coordinator raise {
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
  let server = @socket.TcpServer::new(@socket.Addr::parse(addr))
  let state : CoordinatorState = {
    identify: @queue.InMemoryQueue::new(
      max_concurrency~,
      spacing_ms=identify_spacing_ms,
    ),
    limiter: @ratelimit.InMemoryRateLimiter::new(global_limit~),
    owners: {},
    next_connection_id: Ref(0),
  }
  let runner : Ref[@async.TaskGroup[Unit]?] = Ref(None)
  group.spawn_bg(allow_failure=true, () => {
    @async.with_task_group(inner => {
      runner.val = Some(inner)
      inner.spawn_bg(() => {
        server.run_forever(allow_failure=true, (conn, _) => {
          serve_connection(conn, state)
        })
      })
    })
  })
  { address: server.addr().to_string(), runner }
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
  let connection : ConnectionState = {
    id: state.next_connection_id.val,
    held_buckets: {},
  }
  state.next_connection_id.val += 1
  try {
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
  } catch {
    error => {
      cleanup_connection(state, connection) catch {
        _ => ()
      }
      raise error
    }
  } noraise {
    _ => cleanup_connection(state, connection) catch { _ => () }
  }
}

///|
async fn cleanup_connection(
  state : CoordinatorState,
  connection : ConnectionState,
) -> Unit {
  let held = [ for bucket, _ in connection.held_buckets => bucket ]
  for bucket in held {
    if state.owners.get(bucket) is Some(owner) && owner.id == connection.id {
      state.owners.remove(bucket)
      state.limiter.release(bucket, status=0, headers={})
    }
    connection.held_buckets.remove(bucket)
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
      state.owners[bucket] = connection
      connection.held_buckets[bucket] = true
      ok_response()
    }
    "http_release" => {
      guard request
        is {
          "bucket": String(bucket),
          "status": status_json,
          "headers": Object(header_fields),
          ..
        } &&
        json_nonnegative_int(status_json) is Some(status) else {
        return error_response(
          "http_release requires bucket, non-negative integer status, and headers object",
        )
      }
      let headers = decode_headers(header_fields) catch {
        error => return error_response("invalid headers: \{error}")
      }
      if state.owners.get(bucket) is Some(owner) {
        state.limiter.release(bucket, status~, headers~)
        owner.held_buckets.remove(bucket)
        state.owners.remove(bucket)
      }
      ok_response()
    }
    unknown => error_response("unknown op: \{unknown}")
  }
}
