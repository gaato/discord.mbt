///|
/// How one run of a schedule ended: the trace it returned, or the text of
/// the error it raised.
priv enum Outcome {
  Passed(String)
  Failed(String)
} derive(Eq)

///|
/// Run a randomized schedule twice, and fail when the two runs disagree; when
/// they agree on a failure, shrink it with `ddmin` and fail with the original
/// error, the smallest failing step list found, and that list's own error, so
/// a fuzz failure reads as a short reproduction.
///
/// `run` returns a trace of what happened (a passing run's log, whose first
/// line names the schedule, such as its seed); a failing run raises. It must depend only on the steps it is given, with its other
/// randomness seeded from the same seed each time: two runs whose traces or
/// errors differ fail the check as not deterministic, naming the first line
/// where they part, instead of passing or failing by chance. Every error `run`
/// raises counts as a failure while shrinking. Cancellation propagates.
pub async fn[T : @debug.Debug] check_schedule(
  steps : Array[T],
  run : async (Array[T]) -> String,
  max_runs~ : Int32 = 256,
) -> Unit {
  let first = run_once(run, steps)
  let second = run_once(run, steps)
  if first != second {
    fail(nondeterminism_report(steps.length(), first, second))
  }
  guard first is Failed(error) else { return }
  let shrunk = ddmin(steps, max_runs~, candidate => {
    run_once(run, candidate) is Failed(_)
  })
  // The last failing run need not be the kept one, so run that once more
  // for its error.
  let minimal_error = match run_once(run, shrunk.steps) {
    Failed(error) => error
    Passed(_) => "(passed when re-run: the schedule is not deterministic)"
  }
  fail(
    shrink_report(
      error,
      steps.length(),
      shrunk.steps.map(step => @debug.to_string(step)),
      shrunk.runs,
      shrunk.exhausted,
      minimal_error,
    ),
  )
}

///|
async fn[T] run_once(
  run : async (Array[T]) -> String,
  steps : Array[T],
) -> Outcome {
  try run(steps) catch {
    error if @async.is_being_cancelled() => raise error
    error => Failed(error_text(error))
  } noraise {
    trace => Passed(trace)
  }
}

///|
fn error_text(error : Error) -> String {
  match error {
    Failure(message) => message
    error => "\{Repr(error)}"
  }
}

///|
/// The failure message for two runs of the same `total` steps that ended
/// differently: how each ended, and the first line where their texts part.
fn nondeterminism_report(
  total : Int32,
  first : Outcome,
  second : Outcome,
) -> String {
  let describe = (outcome : Outcome) => {
    match outcome {
      Passed(_) => "passed"
      Failed(_) => "failed"
    }
  }
  let text = (outcome : Outcome) => {
    match outcome {
      Passed(trace) | Failed(trace) => trace.split("\n").collect()
    }
  }
  let a = text(first)
  let b = text(second)
  let mut line = 0
  while line < a.length() && line < b.length() && a[line] == b[line] {
    line += 1
  }
  let at = (lines : Array[StringView]) => {
    if line < lines.length() {
      "  " + lines[line].to_owned()
    } else {
      "  (ended)"
    }
  }
  // The first line names the schedule (its seed), the last shared one says
  // how far the runs agreed.
  let first_line = if line > 1 {
    "\n  first line: " + a[0].to_owned()
  } else {
    ""
  }
  let common = if line > 0 {
    first_line + "\n  last shared line: " + a[line - 1].to_owned()
  } else {
    ""
  }
  (
    $|the schedule is not deterministic: two runs of the same \{total} steps \{describe(first)} and \{describe(second)}, parting at line \{line + 1}:\{common}
    $|first run:
    $|\{at(a)}
    $|second run:
    $|\{at(b)}
  )
}

///|
/// The failure message of a shrunk schedule.
fn shrink_report(
  original : String,
  total : Int32,
  minimal : Array[String],
  runs : Int32,
  exhausted : Bool,
  minimal_error : String,
) -> String {
  let bound = if exhausted {
    ", stopped at the run bound before reaching a 1-minimal list"
  } else {
    ""
  }
  let steps = if minimal.is_empty() {
    "  (no steps)"
  } else {
    // A step's multi-line debug form stays indented under the list.
    minimal
    .map(step => step.split("\n").map(line => "  " + line.to_owned()).join("\n"))
    .join("\n")
  }
  (
    $|\{original}
    $|ddmin shrank the \{total} steps to \{minimal.length()} in \{runs} runs\{bound}:
    $|\{steps}
    $|which fail with:
    $|\{minimal_error}
  )
}
