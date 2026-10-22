///|
/// Serializes shard Identify calls per Discord's `max_concurrency` buckets.
/// One queue instance must be shared by every shard of a bot; cross-process
/// deployments can substitute their own implementation.
pub(open) trait IdentifyQueue {
  /// Block (asynchronously) until this shard may send Identify.
  async fn wait_for_identify(Self, shard_id : Int32) -> Unit
}

///|
priv struct IdentifyBucket {
  gate : @async.Semaphore
  // None until the bucket's first identify, so the first one never waits
  // whatever time the clock starts at.
  mut last_identify_ms : Int64?
}

///|
/// In-process identify queue: `shard_id % max_concurrency` buckets, at most
/// one Identify per bucket per `spacing_ms` (default 5 seconds plus margin).
pub struct InMemoryQueue {
  priv buckets : Array[IdentifyBucket]
  priv spacing_ms : Int32
  priv clock : &@hclock.Clock
}

///|
/// Create a queue with `max_concurrency` identify buckets (the value Discord
/// reports in `GET /gateway/bot`), spacing identifies within each bucket by
/// `spacing_ms`.
pub fn InMemoryQueue::InMemoryQueue(
  max_concurrency~ : Int32 = 1,
  spacing_ms~ : Int32 = 5250,
  clock~ : &@hclock.Clock = @transport.AsyncClock::new(),
) -> InMemoryQueue {
  let buckets = []
  for _ in 0..<max_concurrency {
    buckets.push({ gate: Semaphore(1), last_identify_ms: None, })
  }
  { buckets, spacing_ms, clock, }
}

///|
/// Makes `queue.wait_for_identify(shard_id)` callable as a method.
pub extend InMemoryQueue with IdentifyQueue::{wait_for_identify}

///|
/// Milliseconds until a bucket that last identified at `last_identify_ms` may
/// identify again; 0 when it may now or has never identified.
fn identify_wait_ms(
  last_identify_ms : Int64?,
  spacing_ms : Int32,
  now : Int64,
) -> Int32 {
  guard last_identify_ms is Some(last) else { return 0 }
  let wait = last + spacing_ms.to_int64() - now
  if wait > 0 {
    wait.to_int()
  } else {
    0
  }
}

///|
/// Wait until the shard's bucket (`shard_id % max_concurrency`) allows the
/// next identify.
pub impl IdentifyQueue for InMemoryQueue with fn wait_for_identify(
  self,
  shard_id,
) {
  let bucket = self.buckets[shard_id % self.buckets.length()]
  bucket.gate.acquire()
  defer bucket.gate.release()
  let wait = identify_wait_ms(
    bucket.last_identify_ms,
    self.spacing_ms,
    self.clock.now_unix_ms(),
  )
  if wait > 0 {
    self.clock.sleep(wait)
  }
  bucket.last_identify_ms = Some(self.clock.now_unix_ms())
}
