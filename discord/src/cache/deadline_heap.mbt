///|
/// A binary min-heap of `(deadline, owner)` pairs: the index a resource kept
/// in per-owner buckets uses to find the buckets whose earliest entry has
/// expired without visiting the others. Items are never updated in place;
/// one that no longer matches its bucket is skipped when popped.
priv struct DeadlineHeap[O] {
  items_ : Array[(Int64, O)]
}

///|
fn[O] DeadlineHeap::new() -> DeadlineHeap[O] {
  { items_: [], }
}

///|
fn[O] DeadlineHeap::length(self : DeadlineHeap[O]) -> Int32 {
  self.items_.length()
}

///|
fn[O] DeadlineHeap::clear(self : DeadlineHeap[O]) -> Unit {
  self.items_.clear()
}

///|
fn[O] DeadlineHeap::push(
  self : DeadlineHeap[O],
  deadline : Int64,
  owner : O,
) -> Unit {
  let items = self.items_
  items.push((deadline, owner))
  let mut child = items.length() - 1
  while child > 0 {
    let parent = (child - 1) / 2
    guard items[child].0 < items[parent].0 else { break }
    items.swap(child, parent)
    child = parent
  }
}

///|
/// The earliest item, removed, if its deadline is at most `now`.
fn[O] DeadlineHeap::pop_due(self : DeadlineHeap[O], now : Int64) -> O? {
  let items = self.items_
  guard items.length() > 0 && items[0].0 <= now else { return None }
  let (_, owner) = items[0]
  let last = items.unsafe_pop()
  if items.length() > 0 {
    items[0] = last
    let mut parent = 0
    while true {
      let left = 2 * parent + 1
      let right = left + 1
      let mut smallest = parent
      if left < items.length() && items[left].0 < items[smallest].0 {
        smallest = left
      }
      if right < items.length() && items[right].0 < items[smallest].0 {
        smallest = right
      }
      guard smallest != parent else { break }
      items.swap(parent, smallest)
      parent = smallest
    }
  }
  Some(owner)
}
