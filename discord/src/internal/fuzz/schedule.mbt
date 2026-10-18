///|
/// Run a randomized schedule, and when it fails, shrink it with `ddmin` and
/// fail with the original error, the smallest failing step list found, and
/// that list's own error, so a fuzz failure reads as a short reproduction.
///
/// `run` must depend only on the steps it is given (its other randomness
/// seeded from the same seed each time), and every error it raises counts as
/// a failure while shrinking. Cancellation propagates.
pub async fn[T : @debug.Debug] check_schedule(
  steps : Array[T],
  run : async (Array[T]) -> Unit,
  max_runs~ : Int32 = 256,
) -> Unit {
  let error = try run(steps) catch {
    error if @async.is_being_cancelled() => raise error
    error => error
  } noraise {
    _ => return
  }
  let shrunk = ddmin(steps, max_runs~, candidate => {
    try run(candidate) catch {
      error if @async.is_being_cancelled() => raise error
      _ => true
    } noraise {
      _ => false
    }
  })
  // The last failing run need not be the kept one, so run that once more
  // for its error.
  let minimal_error = try run(shrunk.steps) catch {
    error if @async.is_being_cancelled() => raise error
    error => error_text(error)
  } noraise {
    _ => "(passed when re-run: the schedule is not deterministic)"
  }
  fail(
    shrink_report(
      error_text(error),
      steps.length(),
      shrunk.steps.map(step => @debug.to_string(step)),
      shrunk.runs,
      shrunk.exhausted,
      minimal_error,
    ),
  )
}

///|
fn error_text(error : Error) -> String {
  match error {
    Failure(message) => message
    error => "\{Repr(error)}"
  }
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
