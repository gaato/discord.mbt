///|
/// One ddmin case: a predicate over a failing input, the result it must
/// shrink to, and the most runs that may take.
priv struct DdminCase {
  name : String
  input : Array[Int32]
  fails : (Array[Int32]) -> Bool
  expected : Array[Int32]
  max_runs : Int32
}

///|
fn has(steps : Array[Int32], step : Int32) -> Bool {
  steps.contains(step)
}

///|
/// Whether `wanted` occurs in `steps` in order, not necessarily adjacent.
fn subsequence(wanted : Array[Int32], steps : Array[Int32]) -> Bool {
  let mut at = 0
  for step in steps {
    if at < wanted.length() && step == wanted[at] {
      at += 1
    }
  }
  at == wanted.length()
}

///|
let ddmin_cases : Array[DdminCase] = [
  {
    name: "one culprit",
    input: Array::makei(16, i => i),
    fails: steps => has(steps, 7),
    expected: [7],
    max_runs: 256,
  },
  {
    name: "two interacting steps far apart",
    input: Array::makei(16, i => i),
    fails: steps => has(steps, 3) && has(steps, 12),
    expected: [3, 12],
    max_runs: 256,
  },
  {
    name: "an ordered sequence of three",
    input: Array::makei(20, i => i),
    fails: steps => subsequence([2, 9, 17], steps),
    expected: [2, 9, 17],
    max_runs: 256,
  },
  {
    name: "repeated values keep the earliest failing copies",
    input: [1, 2, 1, 2, 1, 2],
    fails: steps => subsequence([2, 1], steps),
    expected: [2, 1],
    max_runs: 256,
  },
  {
    name: "no steps needed",
    input: Array::makei(10, i => i),
    fails: _ => true,
    expected: [],
    max_runs: 256,
  },
  {
    name: "a single failing step",
    input: [5],
    fails: steps => has(steps, 5),
    expected: [5],
    max_runs: 256,
  },
  {
    // Non-monotone: adding a step can make a failing sequence pass.
    name: "an even count containing zero",
    input: Array::makei(8, i => i),
    fails: steps => has(steps, 0) && steps.length() % 2 == 0,
    expected: [0, 1],
    max_runs: 256,
  },
  {
    // Non-monotone: 4 hides the failure unless 5 comes with it.
    name: "a masking step",
    input: Array::makei(9, i => i),
    fails: steps => {
      has(steps, 1) && has(steps, 6) && has(steps, 4) == has(steps, 5)
    },
    expected: [1, 6],
    max_runs: 256,
  },
]

///|
async test "ddmin shrinks each case to its known minimal sequence" {
  for case in ddmin_cases {
    let ran : Array[Array[Int32]] = []
    let shrunk = ddmin(case.input, max_runs=case.max_runs, steps => {
      ran.push(steps)
      (case.fails)(steps)
    })
    assert_eq(shrunk.steps, case.expected, msg=case.name)
    assert_false(shrunk.exhausted, msg=case.name)
    assert_eq(shrunk.runs, ran.length(), msg=case.name)
    assert_true(shrunk.runs <= case.max_runs, msg=case.name)
    // every sequence kept in input order and, where the steps are distinct
    // values, never run twice
    let distinct = Set::from_array(case.input).length() == case.input.length()
    for i, steps in ran {
      assert_true(subsequence(steps, case.input), msg=case.name)
      for j in 0..<i {
        assert_false(distinct && ran[j] == steps, msg="\{case.name}: rerun")
      }
    }
    // 1-minimal: removing any one step makes it pass
    for i in 0..<shrunk.steps.length() {
      let without = shrunk.steps.copy()
      without.remove(i) |> ignore
      assert_false((case.fails)(without), msg="\{case.name} without #\{i}")
    }
  }
}

///|
async test "ddmin stops at its run bound with the smallest failure so far" {
  let input = Array::makei(64, i => i)
  let fails = (steps : Array[Int32]) => has(steps, 5) && has(steps, 40)
  for bound in [0, 1, 3, 8] {
    let ran = Ref(0)
    let shrunk = ddmin(input, max_runs=bound, steps => {
      ran.val += 1
      fails(steps)
    })
    assert_true(shrunk.exhausted, msg="bound \{bound}")
    assert_eq(shrunk.runs, bound, msg="bound \{bound}")
    assert_eq(ran.val, bound, msg="bound \{bound}")
    assert_true(fails(shrunk.steps), msg="bound \{bound}")
    assert_true(subsequence(shrunk.steps, input), msg="bound \{bound}")
  }
  let unbounded = ddmin(input, steps => fails(steps), max_runs=256)
  assert_eq(unbounded.steps, [5, 40])
  assert_false(unbounded.exhausted)
}

///|
async test "ddmin is deterministic" {
  let fails = (steps : Array[Int32]) => subsequence([3, 1, 4], steps)
  let input = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 1, 4]
  let first = ddmin(input, steps => fails(steps))
  let second = ddmin(input, steps => fails(steps))
  assert_eq(first.steps, second.steps)
  assert_eq(first.runs, second.runs)
  assert_eq(first.steps, [3, 1, 4])
}

///|
test "chunks split as evenly as integer division allows" {
  let rows : Array[(Int32, Int32, Array[(Int32, Int32)])] = [
    (4, 2, [(0, 2), (2, 4)]),
    (5, 2, [(0, 2), (2, 5)]),
    (5, 3, [(0, 1), (1, 3), (3, 5)]),
    (3, 3, [(0, 1), (1, 2), (2, 3)]),
  ]
  for row in rows {
    let (length, n, expected) = row
    assert_eq(chunks(length, n), expected, msg="\{length}/\{n}")
  }
}

///|
test "complement keeps every other part in order" {
  let parts = [[0, 1], [2], [3, 4]]
  assert_eq(complement(parts, 0), [2, 3, 4])
  assert_eq(complement(parts, 1), [0, 1, 3, 4])
  assert_eq(complement(parts, 2), [0, 1, 2])
}
