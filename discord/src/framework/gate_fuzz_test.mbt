// Randomized concurrent use of one ResponseGate on virtual time: callers race
// to send, sinks succeed, fail in each classified way, or hang until released,
// callers are cancelled mid-delivery, and the deadline passes. The model below
// tracks what may have reached Discord and checks the gate never delivers a
// second initial callback, never starts one it should refuse, and reports the
// state the deliveries so far imply.

///|
const GATE_FUZZ_DEADLINE : Int32 = 2500

///|
suberror GateFuzzFailure {
  GateFuzzFailure(@framework.DeliveryFailure)
}

///|
/// How the next sink invocation behaves; a blocked one waits for `Release`.
enum SinkPlan {
  Succeed
  Fail(@framework.DeliveryFailure)
  Block
} derive(Debug)

///|
enum GateStep {
  Send(@model.InteractionResponseType)
  Release(SinkPlan)
  Cancel
  Expire
  Advance(Int32)
} derive(Debug)

///|
/// The gate's state as deliveries so far imply it. `InFlight` reads as
/// `Sent`, which the gate records before its sink runs.
enum GateModelState {
  Pending
  InFlight(@model.InteractionResponseType)
  Sent(@model.InteractionResponseType)
  Unconfirmed(@model.InteractionResponseType)
  Expired
} derive(Debug, Eq)

///|
struct GateModel {
  clock : @simclock.VirtualClock
  deadline_at : Int64
  log : Array[String]
  seed : Int32
  mut state : GateModelState
  mut reached : Int32
  mut successes : Int32
  /// A violation seen inside a caller's task, which cannot fail the test
  /// itself; the driver raises it after the step.
  mut flagged : String?
}

///|
fn GateModel::violation(self : GateModel, message : String) -> Unit raise {
  fail(
    "seed \{self.seed}: \{message}\n" +
    self.log.iter().map(line => "  " + line).collect().join("\n"),
  )
}

///|
fn GateModel::flag(self : GateModel, message : String) -> Unit {
  if self.flagged is None {
    self.flagged = Some(message)
  }
}

///|
/// A pending window reads as expired once its deadline has passed.
fn GateModel::settle_deadline(self : GateModel) -> Unit {
  if self.state == Pending && self.clock.now_unix_ms() >= self.deadline_at {
    self.state = Expired
  }
}

///|
fn GateModel::expected(self : GateModel) -> @framework.ResponseState {
  self.settle_deadline()
  match self.state {
    Pending => Pending
    InFlight(typ) | Sent(typ) => Sent(typ)
    Unconfirmed(typ) => Unconfirmed(typ)
    Expired => Expired
  }
}

///|
fn gate_rand(seed : Int32, stream : Int32) -> @random.Rand {
  @random.Rand::chacha8(
    seed=Bytes::from_array(
      Array::makei(32, i => {
        ((seed * 137 + stream * 53 + i * 29) % 251).to_byte()
      }),
    ),
  )
}

///|
let gate_fuzz_types : Array[@model.InteractionResponseType] = [
  ChannelMessageWithSource,
  DeferredChannelMessageWithSource,
  Modal,
  Pong,
]

///|
fn sink_plan(rand : @random.Rand) -> SinkPlan {
  match rand.int(limit=6) {
    0 | 1 => Succeed
    2 => Fail(Rejected)
    3 => Fail(Expired)
    4 => Fail(Uncertain)
    _ => Block
  }
}

///|
fn gate_step(rand : @random.Rand) -> GateStep {
  let roll = rand.int(limit=100)
  if roll < 40 {
    Send(gate_fuzz_types[rand.int(limit=gate_fuzz_types.length())])
  } else if roll < 60 {
    Release(
      match rand.int(limit=4) {
        0 => Fail(Rejected)
        1 => Fail(Uncertain)
        2 => Fail(Expired)
        _ => Succeed
      },
    )
  } else if roll < 72 {
    Cancel
  } else if roll < 78 {
    Expire
  } else {
    Advance([100, 500, 1000, 2000][rand.int(limit=4)])
  }
}

///|
fn gate_refusal(error : Error) -> Bool {
  error
  is (@framework.ResponseGateError::AlreadyResponded
  | @framework.ResponseGateError::Expired)
}

///|
async fn run_gate_schedule(seed : Int32, length : Int32) -> Unit {
  let clock = @simclock.VirtualClock()
  let plans = gate_rand(seed, 1)
  let steps = gate_rand(seed, 0)
  let model = GateModel::{
    clock,
    deadline_at: clock.now_unix_ms() + GATE_FUZZ_DEADLINE.to_int64(),
    log: [],
    seed,
    state: Pending,
    reached: 0,
    successes: 0,
    flagged: None,
  }
  let blocked : Array[@aqueue.Queue[SinkPlan]] = []
  let returned = Ref(0)
  let sink = async fn(response : @model.InteractionResponse, _files) {
    clock.touch()
    // The gate must only deliver from a pending window before its deadline.
    model.settle_deadline()
    if model.state != Pending {
      model.flag("sink called in state \{@debug.to_string(model.state)}")
    }
    model.state = InFlight(response.typ)
    let mut plan = sink_plan(plans)
    let mut finished = false
    defer (if !finished {
      // cancelled mid-delivery: Discord may have it
      model.log.push("  sink cancelled")
      model.state = Unconfirmed(response.typ)
      model.reached += 1
    })
    if plan is Block {
      let release : @aqueue.Queue[SinkPlan] = Queue(kind=Unbounded)
      blocked.push(release)
      plan = release.get()
      blocked.retain(other => !physical_equal(other, release))
    }
    finished = true
    clock.touch()
    model.log.push("  sink \{@debug.to_string(plan)}")
    match plan {
      Succeed => {
        model.state = Sent(response.typ)
        model.reached += 1
        model.successes += 1
      }
      Fail(kind) => {
        model.state = match kind {
          Rejected => Pending
          Expired => Expired
          _ => {
            model.reached += 1
            Unconfirmed(response.typ)
          }
        }
        raise GateFuzzFailure(kind)
      }
      Block => ()
    }
  }
  let gate = @framework.ResponseGate(
    ApplicationCommand,
    sink,
    classify=error => {
      match error {
        GateFuzzFailure(kind) => kind
        _ => Uncertain
      }
    },
    deadline_ms=GATE_FUZZ_DEADLINE,
    clock~,
  )
  @async.with_task_group(group => {
    let tasks : Array[@async.Task[Unit]] = []
    for _ in 0..<length {
      let step = gate_step(steps)
      match step {
        Send(typ) => {
          model.log.push(@debug.to_string(step))
          tasks.push(
            group.spawn(no_wait=true, allow_failure=true, () => {
              try gate.send({ typ, data: None, }) catch {
                // a caller that arrives mid-delivery waits for its outcome
                error if gate_refusal(error) && model.state is InFlight(_) =>
                  model.flag("refused while a delivery was in flight")
                _ => ()
              } noraise {
                _ => returned.val += 1
              }
            }),
          )
        }
        Release(plan) =>
          if blocked.length() > 0 {
            model.log.push(@debug.to_string(step))
            blocked[0].put(plan)
          }
        Cancel =>
          if tasks.length() > 0 {
            model.log.push(@debug.to_string(step))
            tasks.remove(steps.int(limit=tasks.length())).cancel()
          }
        Expire => {
          model.log.push(@debug.to_string(step))
          gate.expire()
          if model.state == Pending {
            model.state = Expired
          }
        }
        Advance(ms) => {
          model.log.push(@debug.to_string(step))
          clock.advance(ms)
        }
      }
      clock.settle()
      if model.flagged is Some(message) {
        model.violation(message)
      }
      if model.reached > 1 {
        model.violation("\{model.reached} callbacks may have reached Discord")
      }
      if returned.val != model.successes {
        model.violation(
          "\{returned.val} sends returned, \{model.successes} were delivered",
        )
      }
      let expected = model.expected()
      if gate.state() != expected {
        model.violation(
          "state \{@debug.to_string(gate.state())}, expected \{@debug.to_string(expected)}",
        )
      }
    }
    for release in blocked.copy() {
      release.put(Succeed)
    }
    clock.settle()
  })
}

///|
async test "the response gate delivers at most once under random races" {
  for seed in 0..<GATE_FUZZ_SEEDS {
    run_gate_schedule(seed, 40)
  }
}
