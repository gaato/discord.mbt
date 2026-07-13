///|
/// Serializes shard Identify calls per Discord's `max_concurrency` buckets.
/// One queue instance must be shared by every shard of a bot; cross-process
/// deployments can substitute their own implementation.
pub(open) trait IdentifyQueue {
  /// Block (asynchronously) until this shard may send Identify.
  async fn wait_for_identify(Self, shard_id : Int) -> Unit
}

///|
priv struct IdentifyBucket {
  gate : @async.Semaphore
  mut last_identify_ms : Int64
}

///|
/// In-process identify queue: `shard_id % max_concurrency` buckets, at most
/// one Identify per bucket per `spacing_ms` (default 5 seconds plus margin).
pub struct InMemoryQueue {
  priv buckets : Array[IdentifyBucket]
  priv spacing_ms : Int
}

///|
pub fn InMemoryQueue::new(
  max_concurrency? : Int = 1,
  spacing_ms? : Int = 5250,
) -> InMemoryQueue {
  let buckets = []
  for _ in 0..<max_concurrency {
    buckets.push({ gate: @async.Semaphore::new(1), last_identify_ms: 0 })
  }
  { buckets, spacing_ms }
}

///|
pub impl IdentifyQueue for InMemoryQueue with fn wait_for_identify(
  self,
  shard_id,
) {
  let bucket = self.buckets[shard_id % self.buckets.length()]
  bucket.gate.acquire()
  try {
    let wait = bucket.last_identify_ms +
      self.spacing_ms.to_int64() -
      @async.now()
    if wait > 0 {
      @async.sleep(wait.to_int())
    }
    bucket.last_identify_ms = @async.now()
  } catch {
    e => {
      bucket.gate.release()
      raise e
    }
  }
  bucket.gate.release()
}
