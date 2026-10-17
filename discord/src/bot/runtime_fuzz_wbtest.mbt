// Randomized fault schedules against the Bot runtime on virtual time: one to
// three fixed shards whose peers send HELLO, READY, RESUMED, interactions,
// message events, ACKs, and closes drawn from a seed, while command and event
// handlers of random length (some outlast the shutdown grace, some never
// finish) share a small handler budget and a small event backlog. A schedule
// ends with a requested shutdown, a fatal close, or the caller cancelling
// `run`. After every step and every timer a model checks which handlers
// started, which events were dropped, and how each connection was closed; at
// the end it checks that `run` honoured the grace period and left nothing
// running, open, or pending.

///|
enum BotFuzzStep {
  Hello
  Ready
  Resumed
  Command
  Message
  Ack
  ServerClose(Int32?)
  Fatal
  Advance(Int32)
} derive(Debug)

///|
/// How a schedule ends when its ending step comes.
enum BotFuzzEnding {
  Shutdown
  Cancel
} derive(Debug, Eq)

///|
/// Close codes after which the shard reconnects.
let bot_fuzz_close_codes : Array[Int32?] = [
  None,
  Some(1000),
  Some(1001),
  Some(1006),
  Some(4000),
  Some(4007),
  Some(4009),
]

///|
let bot_fuzz_advances : Array[Int32] = [7, 113, 1009, 2503, 5281, 20011, 61007]

///|
/// Handler run times: quick, a few seconds (around the graces), far past
/// every grace, and `None` for a handler that never finishes.
let bot_fuzz_durations : Array[Int32?] = [
  Some(0),
  Some(41),
  Some(433),
  Some(1297),
  Some(2909),
  Some(7789),
  Some(23017),
  None,
  None,
]

///|
let bot_fuzz_graces : Array[Int32] = [1000, 3000, 8000]

///|
fn bot_fuzz_step(rand : @random.Rand) -> BotFuzzStep {
  // fatal closes are rare, so most schedules reach their ending step
  if rand.int(limit=1000) < 4 {
    return Fatal
  }
  let roll = rand.int(limit=100)
  if roll < 12 {
    Hello
  } else if roll < 24 {
    Ready
  } else if roll < 30 {
    Resumed
  } else if roll < 48 {
    Command
  } else if roll < 68 {
    Message
  } else if roll < 74 {
    Ack
  } else if roll < 79 {
    ServerClose(
      bot_fuzz_close_codes[rand.int(limit=bot_fuzz_close_codes.length())],
    )
  } else {
    Advance(bot_fuzz_advances[rand.int(limit=bot_fuzz_advances.length())])
  }
}

///|
fn bot_fuzz_rand(seed : Int32, stream : Int32) -> @random.Rand {
  @random.Rand::chacha8(
    seed=Bytes::from_array(
      Array::makei(32, i => {
        ((seed * 139 + stream * 67 + i * 19) % 251).to_byte()
      }),
    ),
  )
}

///|
fn[T : @debug.Debug] bot_fuzz_dbg(value : T) -> String {
  @debug.to_string(value)
}

///|
/// The model's view of one connection.
priv struct BotFuzzConn {
  transport : @gatewaysim.FakeTransport
  mut hello : Bool
  mut active : Bool
  mut server_closed : Bool
}

///|
priv enum BotFuzzOutcome {
  Running
  Completed(Int64)
  Cancelled(Int64)
} derive(Eq)

///|
/// One handler invocation, as the handler itself recorded it.
priv struct BotFuzzRun {
  label : String
  command : Bool
  started_at : Int64
  /// When its sleep ends; `None` for a handler that never finishes.
  finish_at : Int64?
  mut outcome : BotFuzzOutcome
}

///|
priv enum BotFuzzAdmit {
  Waiting
  Started
  Dropped
} derive(Debug, Eq)

///|
/// One interaction the peer sent, and what admission did with it.
priv struct BotFuzzCommand {
  id : String
  arrived_at : Int64
  /// A command permit was free and nothing waited when it arrived.
  immediate : Bool
  mut state : BotFuzzAdmit
}

///|
/// The reference model: the event pipeline the backlog implies, every
/// handler invocation, every interaction, and every connection so far.
priv struct BotFuzzModel {
  clock : @simclock.VirtualClock
  seed : Int32
  log : Array[String]
  started_at : Int64
  shard_count : Int32
  permits : Int32
  backlog : Int32
  grace : Int32
  durations : @random.Rand
  /// How many leading `bot_fuzz_durations` this schedule draws from.
  duration_kinds : Int32
  never : @aqueue.Queue[Unit]
  conns : Array[BotFuzzConn]
  runs : Array[BotFuzzRun]
  commands : Array[BotFuzzCommand]
  /// Event jobs the runner has not taken yet: a message id, or `None` for a
  /// READY or INTERACTION_CREATE job, which no typed handler consumes.
  queue : Array[String?]
  /// The message whose handler waits for an event permit.
  mut blocked : String?
  /// Message handlers the model expects to have started, in order.
  expected_messages : Array[String]
  /// Message handlers that did start, in order.
  messages : Array[String]
  mut dropping : Bool
  mut expected_taken : Int32
  /// `EventDispatched` telemetry: jobs the runner took.
  mut taken : Int32
  /// `EventDispatched` telemetry for a job with a handler to spawn.
  mut message_jobs : Int32
  mut expected_drops : Int32
  mut drops : Int32
  mut expected_backlog_warnings : Int32
  mut backlog_warnings : Int32
  shutdown_warnings : Array[String]
  mut alive_at_warning : Int32
  mut shards : Array[@gateway.Shard]
  mut next_seq : Int32
  mut next_id : Int32
  mut sessions : Int32
  mut shutdown_at : Int64?
  mut fatal_at : Int64?
  mut cancelled_at : Int64?
  mut returned_at : Int64?
  mut raised : Error?
  mut alive_at_return : Int32
  sent_at_return : Array[Int32]
  /// A violation seen inside a handler, hook, or connector, where raising
  /// would be swallowed or would look like a failure of the code under test;
  /// `observe` raises it.
  mut flagged : String?
}

///|
fn BotFuzzModel::flag(self : BotFuzzModel, message : String) -> Unit {
  if self.flagged is None {
    self.flagged = Some(message)
  }
}

///|
fn BotFuzzModel::violation(self : BotFuzzModel, message : String) -> Unit raise {
  fail(
    "seed \{self.seed}: \{message}\n" +
    self.log.iter().map(line => "  " + line).collect().join("\n"),
  )
}

///|
fn BotFuzzModel::now(self : BotFuzzModel) -> Int64 {
  self.clock.now_unix_ms()
}

///|
fn BotFuzzModel::note(self : BotFuzzModel, line : String) -> Unit {
  self.log.push("t=\{self.now() - self.started_at} \{line}")
}

///|
/// Tracked work still alive, as handlers and hooks recorded it: commands
/// waiting for a permit or running, a message handler waiting for an event
/// permit, and message handlers running.
fn BotFuzzModel::alive(self : BotFuzzModel) -> Int32 {
  let mut alive = self.message_jobs - self.messages.length()
  for command in self.commands {
    if command.state == Waiting {
      alive += 1
    }
  }
  for run in self.runs {
    if run.outcome == Running {
      alive += 1
    }
  }
  alive
}

///|
fn BotFuzzModel::running(self : BotFuzzModel, command : Bool) -> Int32 {
  self.runs
  .filter(run => run.command == command && run.outcome == Running)
  .length()
}

///|
fn BotFuzzModel::start(
  self : BotFuzzModel,
  label : String,
  command : Bool,
) -> BotFuzzRun {
  if self.returned_at is Some(_) {
    self.flag("\{label} started after run returned")
  }
  let now = self.now()
  let duration = bot_fuzz_durations[self.durations.int(
      limit=self.duration_kinds,
    )]
  let run = BotFuzzRun::{
    label,
    command,
    started_at: now,
    finish_at: duration.map(ms => now + ms.to_int64()),
    outcome: Running,
  }
  self.runs.push(run)
  self.note("  start \{label} for \{bot_fuzz_dbg(duration)}")
  self.clock.touch()
  run
}

///|
/// Run a handler body for its drawn duration, recording how it ended.
async fn BotFuzzModel::hold(self : BotFuzzModel, run : BotFuzzRun) -> Unit {
  let mut finished = false
  defer {
    run.outcome = if finished {
      Completed(self.now())
    } else {
      Cancelled(self.now())
    }
    self.clock.touch()
  }
  match run.finish_at {
    Some(at) =>
      (self.clock : &@hclock.Clock).sleep((at - run.started_at).to_int())
    None => self.never.get()
  }
  finished = true
}

///|
fn BotFuzzModel::command_started(
  self : BotFuzzModel,
  id : String,
) -> BotFuzzRun {
  let now = self.now()
  let deadline = @framework.DEFAULT_INTERACTION_DEADLINE_MS.to_int64()
  let mut found = false
  for command in self.commands {
    if command.id == id {
      found = true
      if command.state != Waiting {
        self.flag("command \{id} started while \{bot_fuzz_dbg(command.state)}")
      }
      if now < command.arrived_at || now >= command.arrived_at + deadline {
        self.flag("command \{id} started after its response window closed")
      }
      command.state = Started
      break
    }
    if command.state == Waiting {
      self.flag(
        "command \{id} started before \{command.id}, which waited longer",
      )
    }
  }
  if !found {
    self.flag("unknown command \{id} started")
  }
  if self.running(true) >= self.permits {
    self.flag("more than \{self.permits} command handlers running")
  }
  self.start("command \{id}", true)
}

///|
fn BotFuzzModel::message_started(
  self : BotFuzzModel,
  id : String,
) -> BotFuzzRun {
  if self.messages.contains(id) {
    self.flag("message \{id} reached its handler twice")
  }
  self.messages.push(id)
  if self.running(false) >= self.permits {
    self.flag("more than \{self.permits} message handlers running")
  }
  self.start("message \{id}", false)
}

///|
fn BotFuzzModel::warn(self : BotFuzzModel, warning : @app.AppWarning) -> Unit {
  self.clock.touch()
  let deadline = @framework.DEFAULT_INTERACTION_DEADLINE_MS.to_int64()
  match warning {
    InteractionDropped(target~) => {
      if target != "command:raw" {
        self.flag("dropped unexpected interaction \{target}")
      }
      // Admission waits in arrival order, so the oldest waiter gives up.
      for command in self.commands {
        if command.state == Waiting {
          self.note("  dropped command \{command.id}")
          if self.now() != command.arrived_at + deadline {
            self.flag(
              "command \{command.id} dropped \{self.now() - command.arrived_at} ms after arriving",
            )
          }
          command.state = Dropped
          return
        }
      }
      self.flag("an interaction was dropped while none waited")
    }
    Executor(source~, message~) if source == "gateway" &&
      message.contains(" events behind; dropping ") => {
      self.note("  backlog warning")
      self.backlog_warnings += 1
    }
    Executor(source~, message~) if source == "gateway" &&
      message.contains(" handlers were still running ") => {
      self.note("  shutdown warning: \{message}")
      self.shutdown_warnings.push(message)
      self.alive_at_warning = self.alive()
    }
    _ => self.flag("unexpected warning \{bot_fuzz_dbg(warning)}")
  }
}

///|
fn BotFuzzModel::telemetry(
  self : BotFuzzModel,
  event : @telemetry.TelemetryEvent,
) -> Unit {
  match event {
    EventDropped(backlog~, kind~) => {
      self.note("  dropped \{kind}")
      self.drops += 1
      if backlog != self.backlog {
        self.flag("EventDropped reported backlog \{backlog}")
      }
    }
    EventDispatched(handler_count~, ..) => {
      self.taken += 1
      if handler_count > 0 {
        self.message_jobs += 1
      }
    }
    _ => ()
  }
}

///|
fn BotFuzzModel::connect(self : BotFuzzModel) -> &@gateway.GatewayTransport {
  if self.returned_at is Some(_) {
    self.flag("connected after run returned")
  }
  let transport = @gatewaysim.FakeTransport(clock=self.clock)
  self.conns.push({
    transport,
    hello: false,
    active: false,
    server_closed: false,
  })
  self.clock.touch()
  transport
}

///|
/// An event reached the dispatch loop: it joins the backlog, or is dropped
/// when the backlog is full.
fn BotFuzzModel::dispatch(self : BotFuzzModel, job : String?) -> Unit {
  if self.queue.length() < self.backlog {
    self.queue.push(job)
  } else {
    self.note("  expect a drop")
    self.expected_drops += 1
    if !self.dropping {
      self.dropping = true
      self.expected_backlog_warnings += 1
    }
  }
}

///|
/// Let the model's event runner take every job it can: one at a time, each
/// message waiting for one of `permits` event permits.
fn BotFuzzModel::pump(self : BotFuzzModel) -> Unit {
  let finished = self.runs
    .filter(run => !run.command && run.outcome is Completed(_))
    .length()
  let mut running = self.expected_messages.length() - finished
  while true {
    match self.blocked {
      Some(id) => {
        if running >= self.permits {
          break
        }
        self.expected_messages.push(id)
        running += 1
        self.blocked = None
      }
      None => {
        if self.queue.is_empty() {
          break
        }
        let job = self.queue.remove(0)
        self.expected_taken += 1
        if self.queue.is_empty() {
          self.dropping = false
        }
        self.blocked = job
      }
    }
  }
}

///|
fn BotFuzzModel::live(self : BotFuzzModel, conn : BotFuzzConn) -> Bool {
  ignore(self)
  conn.transport.close_calls.val == 0 && !conn.server_closed
}

///|
/// The shard a connection identified as, if it sent IDENTIFY.
fn bot_fuzz_identified(conn : BotFuzzConn) -> Int32? {
  for frame in conn.transport.sent {
    if frame
      is { "op": Number(2, ..), "d": { "shard": [Number(id, ..), ..], .. }, .. } {
      return Some(id.to_int())
    }
  }
  None
}

///|
fn bot_fuzz_resuming(conn : BotFuzzConn) -> Bool {
  conn.transport.sent.iter().any(frame => frame is { "op": Number(6, ..), .. })
}

///|
fn BotFuzzModel::pick(
  self : BotFuzzModel,
  rand : @random.Rand,
  ok : (BotFuzzConn) -> Bool,
) -> BotFuzzConn? {
  let candidates = self.conns.filter(conn => self.live(conn) && ok(conn))
  if candidates.is_empty() {
    None
  } else {
    Some(candidates[rand.int(limit=candidates.length())])
  }
}

///|
fn bot_fuzz_ready(
  shard : Int32,
  count : Int32,
  session : String,
  seq : Int32,
) -> String {
  "{\"op\":0,\"s\":\{seq},\"t\":\"READY\",\"d\":{\"v\":10,\"user\":{\"id\":\"1\",\"username\":\"bot\",\"discriminator\":\"0\",\"global_name\":null,\"avatar\":null},\"guilds\":[],\"session_id\":\"\{session}\",\"resume_gateway_url\":\"wss://resume.example\",\"application\":{\"id\":\"42\"},\"shard\":[\{shard},\{count}]}}"
}

///|
/// Apply one peer action; returns whether its precondition held.
async fn BotFuzzModel::apply(
  self : BotFuzzModel,
  step : BotFuzzStep,
  rand : @random.Rand,
) -> Bool {
  match step {
    Hello =>
      match self.pick(rand, conn => !conn.hello) {
        Some(conn) => {
          conn.hello = true
          conn.transport.put(BOT_HELLO)
        }
        None => return false
      }
    Ready =>
      match
        self.pick(rand, conn => {
          conn.hello && !conn.active && bot_fuzz_identified(conn) is Some(_)
        }) {
        Some(conn) => {
          guard bot_fuzz_identified(conn) is Some(shard) else { return false }
          self.sessions += 1
          self.next_seq += 1
          conn.active = true
          self.dispatch(None)
          conn.transport.put(
            bot_fuzz_ready(
              shard,
              self.shard_count,
              "sess-\{shard}-\{self.sessions}",
              self.next_seq,
            ),
          )
        }
        None => return false
      }
    Resumed =>
      match
        self.pick(rand, conn => {
          conn.hello && !conn.active && bot_fuzz_resuming(conn)
        }) {
        Some(conn) => {
          self.next_seq += 1
          conn.active = true
          conn.transport.put(
            "{\"op\":0,\"t\":\"RESUMED\",\"s\":\{self.next_seq},\"d\":{}}",
          )
        }
        None => return false
      }
    Command =>
      match self.pick(rand, conn => conn.active) {
        Some(conn) => {
          self.next_seq += 1
          self.next_id += 1
          let id = (500000000000000000L + self.next_id.to_int64()).to_string()
          let immediate = self.running(true) < self.permits &&
            !self.commands.iter().any(command => command.state == Waiting)
          self.commands.push({
            id,
            arrived_at: self.now(),
            immediate,
            state: Waiting,
          })
          self.note("command \{id}")
          self.dispatch(None)
          conn.transport.put(command_frame(self.next_seq, id))
          return true
        }
        None => return false
      }
    Message =>
      match self.pick(rand, conn => conn.active) {
        Some(conn) => {
          self.next_seq += 1
          self.next_id += 1
          let id = (700000000000000000L + self.next_id.to_int64()).to_string()
          self.note("message \{id}")
          self.dispatch(Some(id))
          conn.transport.put(message_delete_frame(self.next_seq, id))
          return true
        }
        None => return false
      }
    Ack =>
      match self.pick(rand, conn => conn.hello) {
        Some(conn) => conn.transport.put("{\"op\":11}")
        None => return false
      }
    ServerClose(code) =>
      match self.pick(rand, _ => true) {
        Some(conn) => {
          conn.server_closed = true
          conn.transport.server_close(code)
        }
        None => return false
      }
    Fatal =>
      // Only a connection the shard is reading from sees the close at once;
      // one held in the identify queue notices it only after identifying.
      match
        self.pick(rand, conn => {
          !conn.hello ||
          bot_fuzz_identified(conn) is Some(_) ||
          bot_fuzz_resuming(conn)
        }) {
        Some(conn) => {
          conn.server_closed = true
          self.fatal_at = Some(self.now())
          conn.transport.server_close(Some(4004))
        }
        None => return false
      }
    Advance(_) => return false
  }
  self.note(bot_fuzz_dbg(step))
  true
}

///|
/// Check what happened since the last observation.
fn BotFuzzModel::observe(self : BotFuzzModel, bot : Bot) -> Unit raise {
  if self.flagged is Some(message) {
    self.violation(message)
  }
  if self.shards.is_empty() {
    self.shards = bot.core.running_shards_.val.map(owner => owner.shard)
  }
  if self.returned_at is None {
    self.pump()
  }
  if self.messages != self.expected_messages {
    self.violation(
      "message handlers started for \{bot_fuzz_dbg(self.messages)}, expected \{bot_fuzz_dbg(self.expected_messages)}",
    )
  }
  if self.taken != self.expected_taken {
    self.violation(
      "the runner took \{self.taken} event jobs, expected \{self.expected_taken}",
    )
  }
  if self.drops != self.expected_drops {
    self.violation(
      "\{self.drops} events dropped, expected \{self.expected_drops}",
    )
  }
  if self.backlog_warnings != self.expected_backlog_warnings {
    self.violation(
      "\{self.backlog_warnings} backlog warnings, expected \{self.expected_backlog_warnings}",
    )
  }
  for command in self.commands {
    if command.immediate && command.state == Waiting {
      self.violation("command \{command.id} waited although a permit was free")
    }
  }
  for conn in self.conns {
    if conn.transport.close_calls.val > 1 {
      self.violation(
        "a connection was closed \{conn.transport.close_calls.val} times",
      )
    }
    if conn.transport.sends_after_close.val > 0 {
      self.violation("sent on a closed connection")
    }
  }
  let now = self.now()
  match (self.shutdown_at, self.returned_at) {
    (Some(at), Some(returned)) =>
      if returned - at > self.grace.to_int64() {
        self.violation(
          "run returned \{returned - at} ms after shutdown, grace \{self.grace}",
        )
      }
    (Some(at), None) => {
      if now - at > self.grace.to_int64() {
        self.violation(
          "run still running \{now - at} ms after shutdown, grace \{self.grace}",
        )
      }
      if self.alive() == 0 {
        self.violation("every handler is done but run has not returned")
      }
    }
    (None, Some(_)) =>
      if self.fatal_at is None && self.cancelled_at is None {
        self.violation("run returned without a shutdown or a fatal close")
      }
    (None, None) =>
      if self.fatal_at is Some(_) || self.cancelled_at is Some(_) {
        self.violation("run kept running after a fatal close or a cancel")
      }
  }
}

///|
/// The checks once `run` has returned and the test group has ended.
fn BotFuzzModel::finish(self : BotFuzzModel) -> Unit raise {
  if self.flagged is Some(message) {
    self.violation(message)
  }
  guard self.returned_at is Some(returned) else {
    self.violation("run never returned")
    return
  }
  let deadline = @framework.DEFAULT_INTERACTION_DEADLINE_MS.to_int64()
  let abrupt = self.fatal_at is Some(_) || self.cancelled_at is Some(_)
  match (self.fatal_at, self.cancelled_at, self.shutdown_at) {
    (Some(at), _, _) => {
      guard self.raised is Some(BotError::FatallyClosed(code=4004)) else {
        self.violation(
          "a fatal close ended run with \{bot_fuzz_dbg(self.raised.map(e => Repr(e)))}",
        )
        return
      }
      if returned != at {
        self.violation("run raised \{returned - at} ms after the fatal close")
      }
    }
    (None, Some(at), _) =>
      if returned != at {
        self.violation("cancelled run returned \{returned - at} ms late")
      }
    (None, None, Some(_)) =>
      if self.raised is Some(error) {
        self.violation("shutdown ended run with \{Repr(error)}")
      }
    (None, None, None) => self.violation("run returned on its own")
  }
  let timed_out = self.shutdown_warnings.length() > 0
  if self.shutdown_warnings.length() > 1 {
    self.violation(
      "\{self.shutdown_warnings.length()} shutdown warnings, expected at most one",
    )
  }
  if timed_out {
    guard self.shutdown_at is Some(at) && !abrupt else {
      self.violation("a shutdown warning without a graceful shutdown")
      return
    }
    if returned != at + self.grace.to_int64() {
      self.violation(
        "warned about running handlers but returned \{returned - at} ms after shutdown",
      )
    }
    let expected = "\{self.alive_at_warning} handlers were still running \{self.grace} ms after shutdown; cancelling them"
    if self.alive_at_warning <= 0 || self.shutdown_warnings[0] != expected {
      self.violation(
        "shutdown warning \{bot_fuzz_dbg(self.shutdown_warnings[0])}, expected \{bot_fuzz_dbg(expected)}",
      )
    }
  } else if !abrupt && self.alive_at_return != 0 {
    self.violation(
      "run returned with \{self.alive_at_return} handlers alive and no warning",
    )
  }
  for run in self.runs {
    match run.outcome {
      Running => self.violation("\{run.label} still running after run returned")
      Completed(at) =>
        if Some(at) != run.finish_at || at > returned {
          self.violation("\{run.label} completed at the wrong time")
        }
      Cancelled(at) => {
        if at != returned || !(abrupt || timed_out) {
          self.violation(
            "\{run.label} cancelled \{returned - at} ms before run returned",
          )
        }
        if run.finish_at is Some(finish) && finish < at {
          self.violation("\{run.label} cancelled after it should have finished")
        }
      }
    }
  }
  for command in self.commands {
    if command.state == Waiting {
      if !(abrupt || timed_out) {
        self.violation("command \{command.id} never ended")
      }
      if command.arrived_at + deadline < returned {
        self.violation("command \{command.id} waited past its window")
      }
    }
  }
  for index, conn in self.conns {
    let transport = conn.transport
    if transport.close_calls.val != 1 || transport.sends_after_close.val > 0 {
      self.violation(
        "connection \{index} closed \{transport.close_calls.val} times, \{transport.sends_after_close.val} sends after closing",
      )
    }
    if index >= self.sent_at_return.length() ||
      transport.sent.length() != self.sent_at_return[index] {
      self.violation("connection \{index} sent after run returned")
    }
  }
  for shard in self.shards {
    if !(shard.state() is (Disconnected(_) | FatallyClosed(_))) {
      self.violation("a shard is still \{bot_fuzz_dbg(shard.state())}")
    }
  }
  if self.clock.pending() != [] {
    self.violation(
      "timers left after run returned: \{bot_fuzz_dbg(self.clock.pending())}",
    )
  }
}

///|
fn BotFuzzModel::on_return(self : BotFuzzModel) -> Unit {
  self.note("run returned")
  self.returned_at = Some(self.now())
  self.alive_at_return = self.alive()
  for conn in self.conns {
    self.sent_at_return.push(conn.transport.sent.length())
  }
  self.clock.touch()
}

///|
/// Advance virtual time by `ms`, observing after every timer.
async fn BotFuzzModel::advance(
  self : BotFuzzModel,
  bot : Bot,
  ms : Int32,
) -> Unit {
  self.note("advance \{ms}")
  let target = self.now() + ms.to_int64()
  while self.clock.next_deadline() is Some(deadline) && deadline <= target {
    ignore(self.clock.advance_to_next())
    self.observe(bot)
  }
  self.clock.advance((target - self.now()).to_int())
  self.observe(bot)
}

///|
/// End the schedule; false when a shutdown has no READY context to ask.
async fn BotFuzzModel::end(
  self : BotFuzzModel,
  bot : Bot,
  run : @async.Task[Unit],
  ending : BotFuzzEnding,
) -> Bool {
  match ending {
    Shutdown => {
      let contexts = bot.core.running_shards_.val.filter_map(owner => {
        owner.context
      })
      guard contexts is [ctx, ..] else { return false }
      self.note("shutdown")
      self.shutdown_at = Some(self.now())
      ctx.shutdown()
    }
    Cancel => {
      self.note("cancel run")
      self.cancelled_at = Some(self.now())
      run.cancel()
    }
  }
  self.clock.settle()
  self.observe(bot)
  true
}

///|
/// A step that moves some shard toward READY.
fn BotFuzzModel::toward_ready(self : BotFuzzModel) -> BotFuzzStep {
  for conn in self.conns {
    if !self.live(conn) {
      continue
    }
    if !conn.hello {
      return Hello
    }
    if !conn.active && bot_fuzz_identified(conn) is Some(_) {
      return Ready
    }
    if !conn.active && bot_fuzz_resuming(conn) {
      return Resumed
    }
  }
  Advance(1009)
}

///|
async fn run_bot_schedule(seed : Int32, length : Int32) -> Unit {
  let rand = bot_fuzz_rand(seed, 0)
  let shard_count = 1 + rand.int(limit=3)
  let permits = 1 + rand.int(limit=3)
  let backlog = 1 + rand.int(limit=3)
  let grace = bot_fuzz_graces[rand.int(limit=bot_fuzz_graces.length())]
  let max_concurrency = 1 + rand.int(limit=shard_count)
  let end_at = length / 3 + rand.int(limit=length - length / 3)
  let ending : BotFuzzEnding = if rand.int(limit=6) == 0 {
    Cancel
  } else {
    Shutdown
  }
  let clock = @simclock.VirtualClock()
  let model = BotFuzzModel::{
    clock,
    seed,
    log: [],
    started_at: clock.now_unix_ms(),
    shard_count,
    permits,
    backlog,
    grace,
    durations: bot_fuzz_rand(seed, 2),
    // a third of the schedules only run handlers that finish within seconds
    duration_kinds: if seed % 3 == 0 {
      6
    } else {
      bot_fuzz_durations.length()
    },
    never: Queue(kind=Unbounded),
    conns: [],
    runs: [],
    commands: [],
    queue: [],
    blocked: None,
    expected_messages: [],
    messages: [],
    dropping: false,
    expected_taken: 0,
    taken: 0,
    message_jobs: 0,
    expected_drops: 0,
    drops: 0,
    expected_backlog_warnings: 0,
    backlog_warnings: 0,
    shutdown_warnings: [],
    alive_at_warning: 0,
    shards: [],
    next_seq: 0,
    next_id: 0,
    sessions: 0,
    shutdown_at: None,
    fatal_at: None,
    cancelled_at: None,
    returned_at: None,
    raised: None,
    alive_at_return: 0,
    sent_at_return: [],
    flagged: None,
  }
  model.log.push(
    "shards=\{shard_count} permits=\{permits} backlog=\{backlog} grace=\{grace} max_concurrency=\{max_concurrency} \{bot_fuzz_dbg(ending)} at step \{end_at}",
  )
  let app = @app.AppBuilder(max_in_flight=permits)
  app.on_warn(warning => model.warn(warning))
  app.command(
    @app.slash(
      name="raw",
      description="Fuzzed command",
      args=@interaction.Args::unit(),
      handler=Raw(raw => {
        model.hold(model.command_started(raw.interaction.id.to_string()))
      }),
    ),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((_request, _next) => {
    model.flag("unexpected REST call")
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let builder = BotBuilder(
    app.build(),
    token="test-token",
    client~,
    shards=Fixed(count=shard_count),
    event_backlog=backlog,
    shutdown_grace_ms=grace,
  )
  builder.core.gateway_bot_info_.val = Some(
    manager_gateway_info(shards=shard_count, max_concurrency~),
  )
  builder.core.connector_.val = Some(_ => model.connect())
  builder.core.clock_.val = clock
  builder.on(Events::message_delete(), (_, event) => {
    model.hold(model.message_started(event.id.to_string()))
  })
  builder.on_telemetry(event => model.telemetry(event))
  let bot = builder.build()
  let steps = bot_fuzz_rand(seed, 1)
  @async.with_task_group(group => {
    let run = group.spawn(no_wait=true, allow_failure=true, () => {
      defer model.on_return()
      bot.run() catch {
        error if @async.is_being_cancelled() => raise error
        error => model.raised = Some(error)
      }
    })
    clock.settle()
    model.observe(bot)
    // Count only steps whose precondition held, so every schedule does
    // `length` things whatever its draws.
    let mut ended = false
    let mut applied = 0
    for _ in 0..<(length * 4) {
      if applied >= length {
        break
      }
      if applied >= end_at && model.end(bot, run, ending) {
        ended = true
        break
      }
      match bot_fuzz_step(steps) {
        Advance(ms) => {
          model.advance(bot, ms)
          applied += 1
        }
        step =>
          if model.apply(step, steps) {
            applied += 1
            clock.settle()
            model.observe(bot)
          }
      }
      if model.fatal_at is Some(_) {
        break
      }
    }
    if model.fatal_at is None && !ended {
      // A shutdown needs a READY context; bring a shard there first.
      let mut tries = 0
      while !model.end(bot, run, ending) {
        tries += 1
        if tries > 200 {
          model.violation("no shard became READY to request the shutdown")
        }
        match model.toward_ready() {
          Advance(ms) => model.advance(bot, ms)
          step =>
            if model.apply(step, steps) {
              clock.settle()
              model.observe(bot)
            }
        }
      }
    }
    while model.returned_at is None {
      guard clock.advance_to_next() else {
        model.violation(
          "run never returned: \{model.alive()} handlers alive, no timer pending",
        )
        return
      }
      model.observe(bot)
    }
    clock.settle()
    model.observe(bot)
  })
  model.finish()
}

///|
async test "the bot runtime follows the model under random fault schedules" {
  for seed in 0..<BOT_FUZZ_SEEDS {
    run_bot_schedule(seed, 60)
  }
}
