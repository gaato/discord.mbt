///|
/// Default number of unread items a receive stream holds: five seconds of
/// 20 ms Opus frames.
pub const DEFAULT_RECEIVE_BACKLOG : Int32 = 250

///|
/// A per-user stream of received audio. Streams are created with
/// `VoiceConnection::subscribe`; read them with `next_packet`, or as an
/// `AudioSource` (for `play` or recording) when only the Opus frames matter.
pub struct VoiceReceiveStream {
  priv connection : VoiceConnection
  priv user_id : String
  priv backlog : Int32
  priv queue : @aqueue.Queue[ReceivedAudio]
  priv end_after_silence_ms : Int32?
  priv mut dropped : Int32
  priv mut started : Bool
  priv mut closed : Bool
}

///|
/// Queue one item without ever blocking the receive loop. When the backlog is
/// full the frame is discarded and counted; the count reaches the reader as a
/// single `Lost` ahead of the next item that fits, so stream order always
/// accounts for every frame.
fn VoiceReceiveStream::deliver(
  self : VoiceReceiveStream,
  audio : ReceivedAudio,
) -> Unit raise {
  let (missing, frame) = match audio {
    Lost(count~) => (self.dropped + count, None)
    Opus(..) => (self.dropped, Some(audio))
  }
  if missing > 0 && !self.queue.try_put(Lost(count=missing)) {
    self.dropped = missing
  } else {
    self.dropped = 0
  }
  guard frame is Some(frame) else { return }
  if self.dropped > 0 || !self.queue.try_put(frame) {
    self.dropped += 1
    (self.connection.telemetry_)(
      ReceiveDropped(user_id=self.user_id, backlog=self.backlog),
    )
  }
}

///|
fn VoiceConnection::remove_subscription(
  self : VoiceConnection,
  stream : VoiceReceiveStream,
) -> Unit {
  for index, subscription in self.subscriptions {
    if physical_equal(subscription, stream) {
      self.subscriptions.remove(index) |> ignore
      return
    }
  }
}

///|
fn VoiceReceiveStream::close_queue(self : VoiceReceiveStream) -> Unit {
  guard !self.closed else { return }
  self.closed = true
  self.queue.close(clear=true)
}

///|
fn VoiceConnection::close_subscriptions(self : VoiceConnection) -> Unit {
  let subscriptions = self.subscriptions.copy()
  self.subscriptions.clear()
  for subscription in subscriptions {
    subscription.close_queue()
  }
}

///|
/// Subscribe to received audio from one Discord user. Only subscribed users'
/// packets are decrypted; everything else is discarded on arrival.
///
/// With `end_after_silence_ms`, the first read waits indefinitely and later
/// reads end the stream after the requested silence interval. At most
/// `backlog` items wait unread; newer frames are dropped past that and
/// reported as `ReceivedAudio::Lost` (and `VoiceTelemetry::ReceiveDropped`).
/// Raises `InvalidBacklog` when `backlog` is below 2: after a drop, the next
/// delivery needs one slot for the `Lost` marker and one for its frame, so a
/// single slot would never let the stream recover.
///
/// # Example
/// ```mbt nocheck
/// async test {
///   // Echo one speaker until they are silent for one second.
///   connection.play(
///     connection.subscribe(user_id="1234", end_after_silence_ms=Some(1000)),
///   )
///
///   // Or record the same stream into an Ogg/Opus file.
///   let stream = connection.subscribe(user_id="1234")
///   let audio : &@voice.AudioSource = stream
///   let writer = @voice.OggOpusWriter::new(channels=2)
///   while audio.next_frame() is Some(frame) {
///     writer.write_frame(frame)
///   }
///   writer.finish()
/// }
/// ```
pub fn VoiceConnection::subscribe(
  self : VoiceConnection,
  user_id~ : String,
  end_after_silence_ms~ : Int32? = None,
  backlog~ : Int32 = DEFAULT_RECEIVE_BACKLOG,
) -> VoiceReceiveStream raise VoiceError {
  if backlog < 2 {
    raise InvalidBacklog(value=backlog)
  }
  let stream = VoiceReceiveStream::{
    connection: self,
    user_id,
    backlog,
    queue: Queue(kind=Blocking(backlog)),
    end_after_silence_ms,
    dropped: 0,
    started: false,
    closed: false,
  }
  if self.closing || self.state_ is Closed(_) {
    stream.close_queue()
  } else {
    if !self.is_subscribed(user_id) {
      self.receiver.reset_reorder(user_id)
    }
    self.subscriptions.push(stream)
  }
  stream
}

///|
/// End this stream and unregister it from its connection. Repeated calls are
/// harmless, and a blocked read wakes with `None`.
pub fn VoiceReceiveStream::close(self : VoiceReceiveStream) -> Unit {
  guard !self.closed else { return }
  self.connection.remove_subscription(self)
  self.close_queue()
}

///|
/// Yield the subscribed user's next frame or loss marker; `None` after
/// `close`, once the connection ends, or once the configured trailing silence
/// elapses.
pub async fn VoiceReceiveStream::next_packet(
  self : VoiceReceiveStream,
) -> ReceivedAudio? {
  guard !self.closed else { return None }
  let next = match (self.started, self.end_after_silence_ms) {
    (true, Some(timeout_ms)) =>
      @transport.with_timeout_opt(self.connection.clock_, timeout_ms, () => {
        self.queue.get()
      }) catch {
        @aqueue.QueueAlreadyClosed => None
        error => raise error
      }
    _ =>
      Some(self.queue.get()) catch {
        @aqueue.QueueAlreadyClosed => None
        error => raise error
      }
  }
  match next {
    Some(audio) => {
      self.started = true
      Some(audio)
    }
    None => {
      self.close()
      None
    }
  }
}

///|
pub extend VoiceReceiveStream with AudioSource::{next_frame}

///|
/// Yield the next Opus frame received from the subscribed user, skipping
/// loss markers; `None` when `next_packet` would end.
pub impl AudioSource for VoiceReceiveStream with fn next_frame(self) {
  for ;; {
    match self.next_packet() {
      Some(Opus(opus~, ..)) => return Some(opus)
      Some(Lost(..)) => continue
      None => return None
    }
  }
}
