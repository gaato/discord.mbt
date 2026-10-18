///|
async test "a passing schedule runs twice" {
  let runs = Ref(0)
  check_schedule([1, 2, 3], steps => {
    runs.val += 1
    "ran \{steps.length()}"
  })
  assert_eq(runs.val, 2)
}

///|
async test "a failing schedule reports the original and the shrunk steps" {
  let report = try
    check_schedule(Array::makei(20, i => i), steps => {
      if steps.contains(4) && steps.contains(13) {
        fail("boom after \{steps.length()} steps")
      }
      ""
    })
  catch {
    Failure(message) => message
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("expected the schedule to fail")
  }
  let lines = report.split("\n").map(line => line.to_owned()).to_array()
  assert_true(lines[0].has_suffix("boom after 20 steps"))
  assert_true(lines[1].has_prefix("ddmin shrank the 20 steps to 2 in "))
  assert_eq(
    lines[2:].to_owned(),
    ["  4", "  13", "which fail with:"] + [lines[lines.length() - 1]],
  )
  assert_true(lines[lines.length() - 1].has_suffix("boom after 2 steps"))
}

///|
test "the shrink report marks a bounded search and an empty list" {
  inspect(
    shrink_report("seed 3: broke", 40, [], 256, true, "seed 3: broke"),
    content=(
      #|seed 3: broke
      #|ddmin shrank the 40 steps to 0 in 256 runs, stopped at the run bound before reaching a 1-minimal list:
      #|  (no steps)
      #|which fail with:
      #|seed 3: broke
    ),
  )
}

///|
test "the shrink report indents multi-line steps under the list" {
  inspect(
    shrink_report(
      "broke",
      3,
      ["Arrive(\n  {\n    a: 1,\n  },\n)", "Advance(5)"],
      4,
      false,
      "broke",
    ),
    content=(
      #|broke
      #|ddmin shrank the 3 steps to 2 in 4 runs:
      #|  Arrive(
      #|    {
      #|      a: 1,
      #|    },
      #|  )
      #|  Advance(5)
      #|which fail with:
      #|broke
    ),
  )
}

///|
async test "a schedule that fails only once is reported as not deterministic" {
  let runs = Ref(0)
  let report = try
    check_schedule([1, 2], _ => {
      runs.val += 1
      if runs.val == 1 {
        raise ScheduleBroke(2)
      }
      "fine"
    })
  catch {
    Failure(message) => message
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("expected the schedule to fail")
  }
  assert_eq(runs.val, 2)
  guard report.find("FAILED: ") is Some(at) else { fail(report) }
  inspect(
    report[at + "FAILED: ".length():],
    content=(
      #|the schedule is not deterministic: two runs of the same 2 steps failed and passed, parting at line 1:
      #|first run:
      #|  ScheduleBroke(2)
      #|second run:
      #|  fine
    ),
  )
}

///|
async test "passing runs whose traces differ are reported as not deterministic" {
  let runs = Ref(0)
  let report = try
    check_schedule([1], _ => {
      runs.val += 1
      "start\ntimer at \{runs.val}"
    })
  catch {
    Failure(message) => message
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("expected the schedule to fail")
  }
  assert_true(
    report.contains(
      "two runs of the same 1 steps passed and passed, parting at line 2:",
    ),
  )
  assert_true(
    report.has_suffix("first run:\n  timer at 1\nsecond run:\n  timer at 2"),
  )
}

///|
async test "a shrunk schedule that passes when re-run is marked" {
  // The first three runs fail: both full runs and ddmin's probe of the empty
  // list, which it keeps; the final re-run of that list passes.
  let runs = Ref(0)
  let report = try
    check_schedule([1, 2], _ => {
      runs.val += 1
      if runs.val <= 3 {
        fail("broken")
      }
      ""
    })
  catch {
    Failure(message) => message
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("expected the schedule to fail")
  }
  assert_eq(runs.val, 4)
  assert_true(
    report.has_suffix("(passed when re-run: the schedule is not deterministic)"),
  )
}

///|
test "the nondeterminism report shows where two outcomes part" {
  inspect(
    nondeterminism_report(3, Passed("a\nb"), Passed("a\nb\nc")),
    content=(
      #|the schedule is not deterministic: two runs of the same 3 steps passed and passed, parting at line 3:
      #|  first line: a
      #|  last shared line: b
      #|first run:
      #|  (ended)
      #|second run:
      #|  c
    ),
  )
  inspect(
    nondeterminism_report(1, Failed("x"), Passed("y")),
    content=(
      #|the schedule is not deterministic: two runs of the same 1 steps failed and passed, parting at line 1:
      #|first run:
      #|  x
      #|second run:
      #|  y
    ),
  )
}

///|
async test "cancelling a schedule cancels it at any stage" {
  // Which run blocks: either of the two full runs, the one shrinking run
  // (ddmin keeps the empty list it tries first), or the final re-run.
  for blocking in [1, 2, 3, 4] {
    let runs = Ref(0)
    let reached : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
    let finished = Ref(false)
    @async.with_task_group(group => {
      let task = group.spawn(allow_failure=true, () => {
        check_schedule([1, 2, 3], _ => {
          runs.val += 1
          if runs.val == blocking {
            reached.put(())
            let never : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
            never.get()
          }
          fail("broken")
        })
        finished.val = true
      })
      reached.get()
      task.cancel()
    })
    assert_eq(runs.val, blocking, msg="blocking \{blocking}")
    assert_false(finished.val, msg="blocking \{blocking}")
  }
}

///|
priv suberror ScheduleBroke {
  ScheduleBroke(Int32)
} derive(Debug)

///|
async test "an error other than a failure is reported by its debug form" {
  let report = try
    check_schedule([7, 8], steps => {
      if steps.contains(8) {
        raise ScheduleBroke(steps.length())
      }
      ""
    })
  catch {
    Failure(message) => message
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("expected the schedule to fail")
  }
  // `fail` prefixes the report with its location
  guard report.find("FAILED: ") is Some(at) else { fail(report) }
  inspect(
    report[at + "FAILED: ".length():],
    content=(
      #|ScheduleBroke(2)
      #|ddmin shrank the 2 steps to 1 in 3 runs:
      #|  8
      #|which fail with:
      #|ScheduleBroke(1)
    ),
  )
}
