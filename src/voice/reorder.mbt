///|
/// Values produced while restoring RTP sequence order.
pub(all) enum ReorderOutput[T] {
  Deliver(T)
  Lost(count~ : Int)
} derive(Debug, Eq)

///|
priv struct ReorderEntry[T] {
  sequence : Int
  arrival_ms : Int64
  packet : T
}

///|
/// A small RTP reorder window. The first packet establishes the expected
/// sequence; later gaps are held until `hold_ms` elapses or eight packets are
/// buffered.
pub struct ReorderBuffer[T] {
  priv entries : Array[ReorderEntry[T]]
  priv mut expected : Int?
  priv hold_ms : Int64
}

///|
/// Create an empty window that holds packets behind a sequence gap for up to
/// `hold_ms` milliseconds.
pub fn[T] ReorderBuffer::new(hold_ms? : Int = 60) -> ReorderBuffer[T] {
  { entries: [], expected: None, hold_ms: hold_ms.to_int64() }
}

///|
fn normalize_sequence(sequence : Int) -> Int {
  sequence & 0xffff
}

///|
fn sequence_distance(a : Int, b : Int) -> Int {
  (a - b) & 0xffff
}

///|
fn sequence_is_after(a : Int, b : Int) -> Bool {
  let distance = sequence_distance(a, b)
  distance != 0 && distance < 0x8000
}

///|
fn[T] ReorderBuffer::find_sequence(
  self : ReorderBuffer[T],
  sequence : Int,
) -> Int? {
  for index, entry in self.entries {
    if entry.sequence == sequence {
      return Some(index)
    }
  }
  None
}

///|
fn[T] ReorderBuffer::take_nearest(
  self : ReorderBuffer[T],
  expected : Int,
) -> ReorderEntry[T] {
  let mut nearest_index = 0
  let mut nearest_distance = sequence_distance(
    self.entries[0].sequence,
    expected,
  )
  for index in 1..<self.entries.length() {
    let distance = sequence_distance(self.entries[index].sequence, expected)
    if distance < nearest_distance {
      nearest_index = index
      nearest_distance = distance
    }
  }
  self.entries.remove(nearest_index)
}

///|
fn[T] ReorderBuffer::drain_contiguous(
  self : ReorderBuffer[T],
  output : Array[ReorderOutput[T]],
) -> Unit {
  for ;; {
    guard self.expected is Some(expected) else { return }
    guard self.find_sequence(expected) is Some(index) else { return }
    let entry = self.entries.remove(index)
    output.push(Deliver(entry.packet))
    self.expected = Some((expected + 1) & 0xffff)
  }
}

///|
/// Insert one RTP packet. Arrival time is supplied by the caller so timeout
/// behavior is deterministic in tests.
pub fn[T] ReorderBuffer::push(
  self : ReorderBuffer[T],
  seq~ : Int,
  arrival_ms~ : Int64,
  packet : T,
) -> Array[ReorderOutput[T]] {
  let sequence = normalize_sequence(seq)
  let output : Array[ReorderOutput[T]] = []
  match self.expected {
    None => {
      output.push(Deliver(packet))
      self.expected = Some((sequence + 1) & 0xffff)
      return output
    }
    Some(expected) => {
      if sequence == expected {
        output.push(Deliver(packet))
        self.expected = Some((expected + 1) & 0xffff)
        self.drain_contiguous(output)
        return output
      }
      // Anything behind the delivery cursor, including a retransmitted packet,
      // is a silent duplicate. Half-range ambiguity is also treated as old.
      if !sequence_is_after(sequence, expected) ||
        self.find_sequence(sequence) is Some(_) {
        return output
      }
      self.entries.push({ sequence, arrival_ms, packet })
    }
  }

  guard self.expected is Some(expected) else { return output }
  let mut oldest_arrival = self.entries[0].arrival_ms
  for entry in self.entries {
    if entry.arrival_ms < oldest_arrival {
      oldest_arrival = entry.arrival_ms
    }
  }
  if self.entries.length() < 8 && arrival_ms - oldest_arrival < self.hold_ms {
    return output
  }

  let entry = self.take_nearest(expected)
  let lost = sequence_distance(entry.sequence, expected)
  if lost > 0 {
    output.push(Lost(count=lost))
  }
  output.push(Deliver(entry.packet))
  self.expected = Some((entry.sequence + 1) & 0xffff)
  self.drain_contiguous(output)
  output
}
