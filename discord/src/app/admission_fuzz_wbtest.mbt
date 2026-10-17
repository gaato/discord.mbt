// Randomized arrivals through `run_admitted` on virtual time: interactions
// with different plans, callback windows, and token lifetimes arrive while
// handlers of random length hold the permits. Every interaction must end in
// exactly one outcome, handlers must never exceed the permits or start after
// their window closed, the auto-defer watchdog must acknowledge at most once
// and only an unanswered interaction, and the budget must drain completely.

///|
enum AdmitOutcome {
  Waiting
  Ran
  Busy
  Warned(String)
} derive(Debug, Eq)

///|
/// One interaction's scripted gate and what happened to it.
struct Arrival {
  plan : AckPlan
  arrived_at : Int64
  deadline_ms : Int32?
  token_ms : Int32
  duration : Int32
  expect_busy : Bool
  mut answered : Bool
  mut defers : Int32
  mut outcome : AdmitOutcome
}

///|
struct AdmitModel {
  clock : @simclock.VirtualClock
  admission : Admission
  permits : Int32
  arrivals : Array[Arrival]
  log : Array[String]
  seed : Int32
  mut running : Int32
  mut flagged : String?
}

///|
fn AdmitModel::flag(self : AdmitModel, message : String) -> Unit {
  if self.flagged is None {
    self.flagged = Some(message)
  }
}

///|
fn AdmitModel::violation(self : AdmitModel, message : String) -> Unit raise {
  fail(
    "seed \{self.seed}: \{message}\n" +
    self.log.iter().map(line => "  " + line).collect().join("\n"),
  )
}

///|
fn AdmitModel::left(self : AdmitModel, until : Int64) -> Int32 {
  let left = until - self.clock.now_unix_ms()
  if left <= 0L {
    0
  } else {
    left.to_int()
  }
}

///|
fn AdmitModel::gate(self : AdmitModel, arrival : Arrival) -> AdmissionGate {
  {
    remaining_ms: () => {
      arrival.deadline_ms.map(ms => {
        self.left(arrival.arrived_at + ms.to_int64())
      })
    },
    token_remaining_ms: () => {
      self.left(arrival.arrived_at + arrival.token_ms.to_int64())
    },
    is_pending: () => !arrival.answered,
    defer_now: _ => {
      if arrival.answered {
        self.flag("auto-deferred an answered interaction")
      }
      arrival.defers += 1
      arrival.answered = true
      self.clock.touch()
    },
  }
}

///|
fn plan_label(plan : AckPlan) -> String {
  match plan {
    Respond => "respond"
    DeferMessage(..) => "defer"
    DeferUpdate => "defer-update"
  }
}

///|
fn admit_rand(seed : Int32, stream : Int32) -> @random.Rand {
  @random.Rand::chacha8(
    seed=Bytes::from_array(
      Array::makei(32, i => {
        ((seed * 113 + stream * 41 + i * 23) % 251).to_byte()
      }),
    ),
  )
}

///|
/// Route one random interaction into `group`.
fn AdmitModel::arrive(
  self : AdmitModel,
  group : @async.TaskGroup[Unit],
  rand : @random.Rand,
) -> Unit {
  let plan : AckPlan = if rand.int(limit=2) == 0 {
    Respond
  } else {
    DeferMessage(ephemeral=false)
  }
  // A deferring route is refused exactly when the waiting budget is full.
  let waiting = self.arrivals
    .filter(other => !(other.plan is Respond) && other.outcome == Waiting)
    .length()
  let refuse = !(plan is Respond) && waiting >= self.admission.max_pending
  let arrival = Arrival::{
    plan,
    expect_busy: refuse,
    arrived_at: self.clock.now_unix_ms(),
    deadline_ms: [Some(2500), Some(1500), Some(800), None][rand.int(limit=4)],
    token_ms: [3000, 8000, 900_000][rand.int(limit=3)],
    duration: [0, 400, 2000, 6000][rand.int(limit=4)],
    answered: false,
    defers: 0,
    outcome: Waiting,
  }
  let label = "#\{self.arrivals.length()}"
  self.arrivals.push(arrival)
  self.log.push(
    "\{label} \{plan_label(plan)} deadline=\{@debug.to_string(arrival.deadline_ms)} token=\{arrival.token_ms} run=\{arrival.duration}",
  )
  let gate = self.gate(arrival)
  let end = (outcome : AdmitOutcome) => {
    if arrival.outcome != Waiting {
      self.flag("\{label} ended twice")
    }
    arrival.outcome = outcome
    self.clock.touch()
  }
  group.spawn_bg(() => {
    run_admitted(
      self.admission,
      gate,
      plan,
      warning => end(Warned(warning.to_string())),
      label,
      () => {
        if !refuse {
          self.flag("\{label} refused with \{waiting} waiting")
        }
        end(Busy)
      },
      () => {
        let open = match plan {
          Respond => !((gate.remaining_ms)() is Some(0))
          _ => (gate.token_remaining_ms)() > 0
        }
        if !open {
          self.flag("\{label} started after its window closed")
        }
        end(Ran)
        self.running += 1
        if self.running > self.permits {
          self.flag("\{self.running} handlers running at once")
        }
        // A responding handler answers as it starts; for a deferring route
        // the framework defers before the handler runs.
        arrival.answered = true
        self.admission.clock.sleep(arrival.duration)
        self.running -= 1
        self.clock.touch()
      },
    )
  })
  if refuse {
    self.log.push("  expect busy")
  }
}

///|
async fn run_admission_schedule(seed : Int32, length : Int32) -> Unit {
  let rand = admit_rand(seed, 0)
  let clock = @simclock.VirtualClock()
  let permits = 1 + rand.int(limit=3)
  let admission = scripted_admission(permits, clock~)
  let model = AdmitModel::{
    clock,
    admission: { ..admission, max_pending: 1 + rand.int(limit=3), },
    permits,
    arrivals: [],
    log: [],
    seed,
    running: 0,
    flagged: None,
  }
  model.log.push(
    "permits=\{permits} max_pending=\{model.admission.max_pending}",
  )
  @async.with_task_group(group => {
    for _ in 0..<length {
      if rand.int(limit=100) < 55 {
        model.arrive(group, rand)
      } else {
        let ms = [100, 500, 1000, 3000][rand.int(limit=4)]
        model.log.push("advance \{ms}")
        clock.advance(ms)
      }
      clock.settle()
      if model.flagged is Some(message) {
        model.violation(message)
      }
      for i, arrival in model.arrivals {
        if arrival.expect_busy && arrival.outcome != Busy {
          model.violation("#\{i} should have been refused as busy")
        }
      }
      let waiting = model.arrivals
        .filter(arrival => {
          !(arrival.plan is Respond) && arrival.outcome == Waiting
        })
        .length()
      if model.admission.pending != waiting {
        model.violation(
          "admission counts \{model.admission.pending} waiting, \{waiting} are",
        )
      }
    }
    // Let every handler, wait, and watchdog run out.
    while clock.advance_to_next() {
      ()
    }
  })
  if model.flagged is Some(message) {
    model.violation(message)
  }
  for i, arrival in model.arrivals {
    if arrival.outcome == Waiting {
      model.violation("#\{i} never ended")
    }
    if arrival.defers > 1 {
      model.violation("#\{i} was auto-deferred \{arrival.defers} times")
    }
  }
  if model.admission.pending != 0 || model.running != 0 {
    model.violation("the budget did not drain")
  }
  for _ in 0..<permits {
    if !model.admission.limiter.try_acquire() {
      model.violation("a permit was never returned")
    }
  }
}

///|
async test "admission keeps its budget under random arrivals" {
  for seed in 0..<ADMIT_FUZZ_SEEDS {
    run_admission_schedule(seed, 40)
  }
}
