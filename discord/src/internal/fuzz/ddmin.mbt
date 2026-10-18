///|
/// What `ddmin` found: a failing subsequence of its input, how many times it
/// ran the predicate, and whether the run bound stopped it early. Without
/// the bound, `steps` is 1-minimal: removing any one step makes it pass.
pub struct Shrunk[T] {
  steps : Array[T]
  runs : Int32
  exhausted : Bool
}

///|
/// Shrink a failing input with Zeller's delta debugging (ddmin): split the
/// current failing sequence into `n` chunks, keep a chunk or a complement that
/// still fails, and otherwise double `n` until the chunks are single steps.
/// The empty sequence is tried first, for a failure that needs no steps.
///
/// `fails(input)` is assumed, not re-run. Kept steps stay in input order, a
/// sequence is never run twice, and `fails` runs at most `max_runs` times;
/// at the bound the smallest failing sequence so far is returned. `fails`
/// must be deterministic for the result to mean anything.
pub async fn[T] ddmin(
  input : Array[T],
  fails : async (Array[T]) -> Bool,
  max_runs~ : Int32 = 256,
) -> Shrunk[T] {
  let search = Search::{ input, fails, max_runs, outcomes: Map([]), runs: 0, }
  let mut current = Array::makei(input.length(), i => i)
  let mut exhausted = false
  if current.length() > 0 {
    match search.probe([]) {
      Some(true) => current = []
      Some(false) => ()
      None => exhausted = true
    }
  }
  let mut n = 2
  while !exhausted && current.length() >= 2 {
    let parts = chunks(current.length(), n).map(range => {
      current[range.0:range.1].to_owned()
    })
    let mut reduced = false
    for part in parts {
      match search.probe(part) {
        Some(true) => {
          current = part
          n = 2
          reduced = true
          break
        }
        Some(false) => ()
        None => {
          exhausted = true
          break
        }
      }
    }
    // With two chunks each complement is the other chunk, already tried.
    if !reduced && !exhausted && n > 2 {
      for i in 0..<parts.length() {
        let rest = complement(parts, i)
        match search.probe(rest) {
          Some(true) => {
            current = rest
            n = (n - 1).max(2)
            reduced = true
            break
          }
          Some(false) => ()
          None => {
            exhausted = true
            break
          }
        }
      }
    }
    if !reduced && !exhausted {
      if n >= current.length() {
        break
      }
      n = (n * 2).min(current.length())
    }
  }
  { steps: current.map(i => input[i]), runs: search.runs, exhausted, }
}

///|
/// The predicate with its memo and run budget. Sequences are kept as input
/// indices, which also key the memo.
priv struct Search[T] {
  input : Array[T]
  fails : async (Array[T]) -> Bool
  max_runs : Int32
  outcomes : Map[String, Bool]
  mut runs : Int32
}

///|
/// Whether the steps at `indices` fail, or `None` once the budget is spent.
async fn[T] Search::probe(self : Search[T], indices : Array[Int32]) -> Bool? {
  let key = indices.map(i => i.to_string()).join(",")
  if self.outcomes.get(key) is Some(outcome) {
    return Some(outcome)
  }
  if self.runs >= self.max_runs {
    return None
  }
  self.runs += 1
  let outcome = (self.fails)(indices.map(i => self.input[i]))
  self.outcomes[key] = outcome
  Some(outcome)
}

///|
/// `[start, end)` of each of `n` contiguous chunks of `length` items, as even
/// as integer division makes them. `n` is at most `length`.
fn chunks(length : Int32, n : Int32) -> Array[(Int32, Int32)] {
  Array::makei(n, i => (i * length / n, (i + 1) * length / n))
}

///|
/// Every part but the one at `skip`, in order.
fn complement(parts : Array[Array[Int32]], skip : Int32) -> Array[Int32] {
  let rest : Array[Int32] = []
  for i, part in parts {
    if i != skip {
      rest.append(part)
    }
  }
  rest
}
