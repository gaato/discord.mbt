// Randomized fault schedules against the shard: a well-behaved Discord peer
// whose frames, closes, and timing are drawn from a seed, on virtual time.
// After every step a reference model, written from the Gateway docs and the
// public `on_close` policy, checks what the shard sent, how it closed each
// connection, which timers it left pending, and the state it reports.

///|
const FUZZ_INTERVAL : Int32 = 45000

///|
/// One server-side action or a passage of time. Actions whose protocol
/// precondition does not hold (READY before an IDENTIFY, say) are skipped.
enum FuzzStep {
  Hello
  Ready
  Resumed
  Dispatch
  HeartbeatRequest
  Ack
  Reconnect
  InvalidSession(Bool)
  ServerClose(Int32?)
  Garbage
  Advance(Int32)
} derive(Debug)

///|
let fuzz_close_codes : Array[Int32?] = [
  None,
  Some(1000),
  Some(1001),
  Some(1006),
  Some(4000),
  Some(4007),
  Some(4009),
]

///|
/// Codes after which reconnecting cannot succeed; drawn rarely so most
/// schedules keep going.
let fuzz_fatal_codes : Array[Int32] = [4004, 4010, 4011, 4012, 4013, 4014]

///|
let fuzz_advances : Array[Int32] = [100, 1000, 5000, 20000, 45000, 90000]

///|
fn fuzz_step(rand : @random.Rand) -> FuzzStep {
  let roll = rand.int(limit=100)
  if roll < 12 {
    Hello
  } else if roll < 26 {
    Ready
  } else if roll < 36 {
    Resumed
  } else if roll < 50 {
    Dispatch
  } else if roll < 54 {
    HeartbeatRequest
  } else if roll < 66 {
    Ack
  } else if roll < 69 {
    Reconnect
  } else if roll < 73 {
    InvalidSession(rand.int(limit=2) == 0)
  } else if roll < 79 {
    ServerClose(
      if rand.int(limit=20) == 0 {
        Some(fuzz_fatal_codes[rand.int(limit=fuzz_fatal_codes.length())])
      } else {
        fuzz_close_codes[rand.int(limit=fuzz_close_codes.length())]
      },
    )
  } else if roll < 81 {
    Garbage
  } else {
    Advance(fuzz_advances[rand.int(limit=fuzz_advances.length())])
  }
}

///|
fn fuzz_rand(seed : Int32, stream : Int32) -> @random.Rand {
  @random.Rand::chacha8(
    seed=Bytes::from_array(
      Array::makei(32, i => {
        ((seed * 131 + stream * 71 + i * 17) % 251).to_byte()
      }),
    ),
  )
}

///|
/// What the first protocol frame of a connection was.
enum Opening {
  Unopened
  Identified
  Resumed
} derive(Eq, Debug)

///|
/// The model's view of one connection.
struct FuzzConn {
  transport : @gatewaysim.FakeTransport
  mut hello : Bool
  mut opening : Opening
  mut active : Bool
  mut checked : Int32
  mut outstanding : Bool
  mut last_beat_at : Int64
  mut server_closed : Bool
  mut ended : Bool
}

///|
/// Why the connection ended, as the step that caused it says.
enum FuzzEnd {
  Closed(Int32?)
  Invalid(Bool)
} derive(Debug)

///|
enum FuzzDelay {
  NoDelay
  Backoff(Int32)
  InvalidSessionWait
} derive(Debug)

///|
/// The reference model: the session the shard should hold, the reconnect
/// bookkeeping the docs imply, and every connection so far.
struct FuzzModel {
  clock : @simclock.VirtualClock
  conns : Array[FuzzConn]
  log : Array[String]
  seed : Int32
  mut session_id : String?
  mut seq : Int64
  mut next_session : Int32
  mut attempts : Int32
  mut connector_failures : Int32
  mut delay : FuzzDelay
  mut fatal : Int32?
}

///|
fn FuzzModel::violation(self : FuzzModel, message : String) -> Unit raise {
  fail(
    "seed \{self.seed}: \{message}\n" +
    self.log.iter().map(line => "  " + line).collect().join("\n"),
  )
}

///|
fn FuzzModel::alive(self : FuzzModel) -> FuzzConn? {
  match self.conns.last() {
    Some(conn) if !conn.ended => Some(conn)
    _ => None
  }
}

///|
fn backoff_cap(attempts : Int32) -> Int32 {
  let cap = 1000 * (1 << (if attempts > 5 { 5 } else { attempts }))
  if cap > 30000 {
    30000
  } else {
    cap
  }
}

///|
/// A connection ended for `cause`: apply the documented reconnect rules.
fn FuzzModel::end(self : FuzzModel, conn : FuzzConn, cause : FuzzEnd) -> Unit {
  conn.ended = true
  if conn.active {
    self.attempts = 0
  }
  let (code, has_session, invalid) = match cause {
    Closed(code) => (code, self.session_id is Some(_), false)
    Invalid(true) => (None, self.session_id is Some(_), false)
    Invalid(false) => (None, false, true)
  }
  match @gateway.on_close(code, has_session) {
    Fatal => {
      self.fatal = Some(code.unwrap_or(0))
      self.delay = NoDelay
    }
    policy => {
      self.attempts += 1
      self.delay = if invalid {
        InvalidSessionWait
      } else {
        Backoff(backoff_cap(self.attempts))
      }
      if policy is Reidentify {
        self.session_id = None
      }
    }
  }
}

///|
/// Check what happened since the last observation. `cause` is the end the
/// last action would explain, if it ended the live connection.
fn FuzzModel::observe(
  self : FuzzModel,
  shard : @gateway.Shard,
  cause : FuzzEnd?,
  timer : Bool,
) -> Unit raise {
  let now = self.clock.now_unix_ms()
  for conn in self.conns {
    let sent = conn.transport.sent
    for i in conn.checked..<sent.length() {
      let frame = sent[i]
      if !conn.hello {
        self.violation("sent \{frame.stringify()} before HELLO")
      }
      match frame {
        { "op": Number(1, ..), "d": d, .. } => {
          let expected : Json = match self.session_id {
            Some(_) => Json::number(self.seq.to_double())
            None => Json::null()
          }
          if d != expected {
            self.violation(
              "heartbeat carried \{d.stringify()}, expected \{expected.stringify()}",
            )
          }
          // the timer's beat must not go out over an unacknowledged one
          if timer && conn.outstanding {
            self.violation("beat again without an ACK instead of reconnecting")
          }
          conn.outstanding = true
          conn.last_beat_at = now
        }
        { "op": Number(2, ..), .. } => {
          if conn.opening != Unopened {
            self.violation("a second IDENTIFY/RESUME on one connection")
          }
          if self.session_id is Some(id) {
            self.violation("identified while session \{id} was resumable")
          }
          conn.opening = Identified
        }
        { "op": Number(6, ..), "d": d, .. } => {
          if conn.opening != Unopened {
            self.violation("a second IDENTIFY/RESUME on one connection")
          }
          guard self.session_id is Some(id) else {
            self.violation("resumed without a session")
            continue
          }
          guard d
            is { "session_id": String(sent_id), "seq": Number(seq, ..), .. } &&
            sent_id == id &&
            seq == self.seq.to_double() else {
            self.violation(
              "RESUME \{d.stringify()} does not match session \{id} at \{self.seq}",
            )
            continue
          }
          conn.opening = Resumed
        }
        _ => self.violation("unexpected frame \{frame.stringify()}")
      }
    }
    conn.checked = sent.length()
    if conn.transport.sends_after_close.val > 0 {
      self.violation("sent after closing a connection")
    }
    if conn.transport.close_calls.val > 1 {
      self.violation(
        "closed a connection \{conn.transport.close_calls.val} times",
      )
    }
  }
  if self.alive() is Some(conn) &&
    (conn.transport.close_calls.val > 0 || conn.server_closed) {
    let cause = match cause {
      Some(cause) => cause
      None if timer => {
        // only a heartbeat timer ends a connection: the zombie check
        if !conn.outstanding {
          self.violation("closed a connection whose heartbeat was acknowledged")
        }
        self.log.push("ZOMBIE")
        Closed(Some(4000))
      }
      None => {
        self.violation("a connection ended without a cause")
        Closed(None)
      }
    }
    if !conn.server_closed && conn.transport.close_code.val != Some(4000) {
      self.violation(
        "closed with \{dbg(conn.transport.close_code.val)}, which drops the session",
      )
    }
    self.end(conn, cause)
  }
  let open = self.conns.filter(conn => conn.transport.close_calls.val == 0)
  if open.length() > 1 {
    self.violation("\{open.length()} connections open at once")
  }
  let pending = self.clock.pending()
  let state = shard.state()
  match (self.fatal, self.alive()) {
    (Some(code), _) =>
      if state != FatallyClosed(code~) || pending != [] {
        self.violation(
          "after fatal \{code}: \{dbg(state)}, timers \{dbg(pending)}",
        )
      }
    (None, Some(conn)) => {
      if conn.transport.close_calls.val > 0 {
        self.violation("the live connection is closed")
      }
      let expected : @gateway.ShardState = match conn.opening {
        _ if !conn.hello => Connecting
        _ if conn.active => Active
        Identified => Identifying
        Resumed => Resuming
        Unopened => Connecting
      }
      if state != expected {
        self.violation("state \{dbg(state)}, expected \{dbg(expected)}")
      }
      let heartbeat = conn.hello && pending is [ms] && ms <= FUZZ_INTERVAL
      if conn.hello != heartbeat || (!conn.hello && pending != []) {
        self.violation(
          "timers \{dbg(pending)} on a connection (hello=\{conn.hello})",
        )
      }
      if conn.outstanding && now - conn.last_beat_at >= FUZZ_INTERVAL.to_int64() {
        self.violation("an unacknowledged heartbeat outlived the interval")
      }
    }
    (None, None) => {
      let range = match self.delay {
        Backoff(cap) => (250, cap + 250)
        InvalidSessionWait => (1000, 5000)
        NoDelay => (0, 0)
      }
      guard pending is [ms] && ms >= range.0 && ms < range.1 else {
        self.violation(
          "waiting with timers \{dbg(pending)}, expected \{dbg(self.delay)}",
        )
        return
      }
      if state != Disconnected(reconnect_attempts=self.attempts) {
        self.violation(
          "state \{dbg(state)}, expected \{self.attempts} attempts",
        )
      }
    }
  }
}

///|
fn[T : @debug.Debug] dbg(value : T) -> String {
  @debug.to_string(value)
}

///|
fn fuzz_ready(session_id : String) -> String {
  ready_frame().replace(old="sess-1", new=session_id)
}

///|
/// Apply one step; returns the end it would explain and whether it ran.
async fn FuzzModel::apply(
  self : FuzzModel,
  step : FuzzStep,
) -> (FuzzEnd?, Bool) {
  guard self.alive() is Some(conn) else { return (None, false) }
  let transport = conn.transport
  match step {
    Hello if !conn.hello => {
      conn.hello = true
      transport.put(
        "{\"op\":10,\"d\":{\"heartbeat_interval\":\{FUZZ_INTERVAL}}}",
      )
    }
    Ready if conn.opening == Identified && !conn.active => {
      self.next_session += 1
      let id = "sess-\{self.next_session}"
      self.session_id = Some(id)
      self.seq = 1L
      conn.active = true
      transport.put(fuzz_ready(id))
    }
    Resumed if conn.opening == Resumed && !conn.active => {
      self.seq += 1L
      conn.active = true
      transport.put("{\"op\":0,\"t\":\"RESUMED\",\"s\":\{self.seq},\"d\":{}}")
    }
    Dispatch if conn.active || conn.opening == Resumed => {
      self.seq += 1L
      transport.put(
        "{\"op\":0,\"t\":\"FUZZ_EVENT\",\"s\":\{self.seq},\"d\":{}}",
      )
    }
    HeartbeatRequest if conn.hello => transport.put("{\"op\":1,\"d\":null}")
    Ack if conn.hello => {
      conn.outstanding = false
      transport.put("{\"op\":11}")
    }
    Reconnect if conn.hello => {
      transport.put("{\"op\":7,\"d\":null}")
      return (Some(Closed(None)), true)
    }
    InvalidSession(resumable) if conn.hello => {
      transport.put("{\"op\":9,\"d\":\{resumable}}")
      return (Some(Invalid(resumable)), true)
    }
    ServerClose(code) => {
      conn.server_closed = true
      transport.server_close(code)
      return (Some(Closed(code)), true)
    }
    Garbage if conn.hello => {
      transport.put("{")
      return (Some(Closed(None)), true)
    }
    _ => return (None, false)
  }
  (None, true)
}

///|
async fn run_shard_schedule(seed : Int32, steps : Array[FuzzStep]) -> Unit {
  let clock = @simclock.VirtualClock()
  let connector_rand = fuzz_rand(seed, 1)
  // some schedules fail most connects, to reach the stale-host fallback
  let failure_percent = [5, 15, 60][seed % 3]
  let model = FuzzModel::{
    clock,
    conns: [],
    log: [],
    seed,
    session_id: None,
    seq: 0L,
    next_session: 0,
    attempts: 0,
    connector_failures: 0,
    delay: NoDelay,
    fatal: None,
  }
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      clock~,
      rand=fuzz_rand(seed, 2),
      connector=url => {
        if model.fatal is Some(_) {
          model.violation("reconnected after a fatal close")
        }
        let base = if model.session_id is Some(_) {
          "wss://resume.example/"
        } else {
          "wss://gateway.discord.gg/"
        }
        if !url.has_prefix(base) {
          model.violation("connected to \{url}, expected \{base}")
        }
        if connector_rand.int(limit=100) < failure_percent {
          model.log.push("  connector failed")
          model.attempts += 1
          model.connector_failures += 1
          model.delay = Backoff(backoff_cap(model.attempts))
          if model.connector_failures >= 3 && model.session_id is Some(_) {
            model.session_id = None
          }
          raise GatewayTestFailure
        }
        model.connector_failures = 0
        let transport = @gatewaysim.FakeTransport(clock~)
        model.conns.push({
          transport,
          hello: false,
          opening: Unopened,
          active: false,
          checked: 0,
          outstanding: false,
          last_beat_at: 0L,
          server_closed: false,
          ended: false,
        })
        (transport : &@gateway.GatewayTransport)
      },
    )
    // Drain events so the shard's bounded queue never blocks its read loop.
    group.spawn_bg(no_wait=true, () => {
      while true {
        ignore(shard.next())
        clock.touch()
      }
    })
    clock.settle()
    model.observe(shard, None, false)
    for step in steps {
      match step {
        Advance(ms) => {
          model.log.push("\{dbg(step)}")
          let target = clock.now_unix_ms() + ms.to_int64()
          while clock.next_deadline() is Some(deadline) && deadline <= target {
            ignore(clock.advance_to_next())
            model.observe(shard, None, true)
          }
          clock.advance((target - clock.now_unix_ms()).to_int())
          model.observe(shard, None, false)
        }
        _ => {
          let (cause, ran) = model.apply(step)
          if ran {
            model.log.push("\{dbg(step)}")
            clock.settle()
            model.observe(shard, cause, false)
          }
        }
      }
    }
    model.log.push("Stop")
    let live = model.alive()
    shard.close()
    clock.settle()
    if live is Some(conn) && conn.transport.close_code.val != Some(1000) {
      model.violation(
        "shutdown closed with \{dbg(conn.transport.close_code.val)}, not 1000",
      )
    }
    if clock.pending() != [] {
      model.violation("timers left after shutdown: \{dbg(clock.pending())}")
    }
    for conn in model.conns {
      if conn.transport.close_calls.val != 1 ||
        conn.transport.sends_after_close.val > 0 {
        model.violation("a connection was not closed exactly once")
      }
    }
  })
}

///|
fn fuzz_steps(seed : Int32, length : Int32) -> Array[FuzzStep] {
  let rand = fuzz_rand(seed, 0)
  Array::makei(length, _ => fuzz_step(rand))
}

///|
async test "shard follows the reference model under random fault schedules" {
  for seed in 0..<FUZZ_SEED_COUNT {
    run_shard_schedule(seed, fuzz_steps(seed, 80))
  }
}
