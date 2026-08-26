///|
priv suberror PoolWbtestFailure {
  PoolWbtestFailure
} derive(Debug)

///|
async fn exchange_once(conn : @http.Client) -> Int {
  conn.request(@http.Get, "/ping")
  let response = conn.end_request()
  ignore(conn.read_all().text())
  response.code
}

///|
async test "pool reuses healthy connections and drops failed or closed ones" {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      server.run_forever(allow_failure=true, (_request, body_reader, conn) => {
        ignore(body_reader.read_all().text())
        conn.send_response(200, "OK")
        conn.write_string("pong")
        conn.end_response()
      })
    })
    let pool = Pool("http://\{server.addr}", max_connections=2)
    let checked_out : Array[@http.Client] = []

    // Two successful checkouts reuse the same physical connection.
    inspect(
      pool.with_conn(conn => {
        checked_out.push(conn)
        exchange_once(conn)
      }),
      content="200",
    )
    inspect(pool.idle.length(), content="1")
    inspect(
      pool.with_conn(conn => {
        checked_out.push(conn)
        exchange_once(conn)
      }),
      content="200",
    )
    inspect(pool.idle.length(), content="1")
    assert_true(physical_equal(checked_out[0], checked_out[1]))

    // A failing callback drops its connection instead of recycling it.
    try failing_checkout(pool, checked_out) catch {
      PoolWbtestFailure => ()
      other => fail("unexpected error \{other}")
    } noraise {
      _ => fail("expected the callback error to propagate")
    }
    inspect(pool.idle.length(), content="0")

    // The next checkout dials a fresh connection.
    inspect(
      pool.with_conn(conn => {
        checked_out.push(conn)
        exchange_once(conn)
      }),
      content="200",
    )
    assert_false(physical_equal(checked_out[2], checked_out[3]))

    // Closing the pool mid-checkout closes the connection instead of
    // recycling it, and later checkouts are refused.
    inspect(
      pool.with_conn(conn => {
        let code = exchange_once(conn)
        pool.close()
        code
      }),
      content="200",
    )
    inspect(pool.idle.length(), content="0")
    try pool.with_conn(conn => exchange_once(conn)) catch {
      PoolClosed => ()
      other => fail("unexpected error \{other}")
    } noraise {
      _ => fail("expected PoolClosed after close")
    }
  })
}

///|
async fn failing_checkout(
  pool : Pool,
  checked_out : Array[@http.Client],
) -> Int {
  pool.with_conn(conn => {
    checked_out.push(conn)
    ignore(exchange_once(conn))
    raise PoolWbtestFailure
  })
}

///|
async test "a failed dial releases the connection slot" {
  // Nothing listens on this address, so every dial fails; with one slot, a
  // leaked semaphore permit would deadlock the second attempt.
  let pool = Pool("http://127.0.0.1:9", max_connections=1)
  for _attempt in 0..<2 {
    try pool.with_conn(conn => exchange_once(conn)) catch {
      PoolClosed => fail("expected a dial failure, not PoolClosed")
      _ => ()
    } noraise {
      _ => fail("expected the dial to fail")
    }
  }
  inspect(pool.idle.length(), content="0")
}

///|
async test "a cancelled checkout drops its connection and releases the slot" {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      server.run_forever(allow_failure=true, (_request, body_reader, conn) => {
        ignore(body_reader.read_all().text())
        conn.send_response(200, "OK")
        conn.write_string("pong")
        conn.end_response()
      })
    })
    let pool = Pool("http://\{server.addr}", max_connections=1)
    defer pool.close()
    let entered = @async.Semaphore(1, initial_value=0)
    let checked_out : Array[@http.Client] = []
    let running = group.spawn(no_wait=true, allow_failure=true, () => {
      pool.with_conn(conn => {
        checked_out.push(conn)
        entered.release()
        @async.sleep(60_000)
        0
      })
    })
    entered.acquire()
    running.cancel()
    try running.wait() catch {
      error if @async.is_cancellation_error(error) => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled checkout unexpectedly completed")
    }

    // max_connections=1 makes this time out if cancellation leaked the slot.
    let code = @async.with_timeout(1000, () => {
      pool.with_conn(conn => {
        checked_out.push(conn)
        exchange_once(conn)
      })
    })
    assert_eq(code, 200)
    assert_eq(checked_out.length(), 2)
    assert_false(physical_equal(checked_out[0], checked_out[1]))
    assert_eq(pool.idle.length(), 1)
  })
}
