///|
/// A per-user stream of received Opus packets. Streams are created with
/// `VoiceConnection::subscribe` and can be passed directly to `play` or read
/// through the `AudioSource` trait.
pub struct VoiceReceiveStream {
  priv connection : VoiceConnection
  priv user_id : String
  priv queue : @aqueue.Queue[Bytes]
  priv end_after_silence_ms : Int?
  priv mut started : Bool
  priv mut closed : Bool
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
/// Subscribe to received Opus packets for one Discord user. With
/// `end_after_silence_ms`, the first frame waits indefinitely and subsequent
/// reads end the stream after the requested silence interval.
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
  end_after_silence_ms? : Int? = None,
) -> VoiceReceiveStream {
  let stream : VoiceReceiveStream = {
    connection: self,
    user_id,
    queue: Queue(kind=Unbounded),
    end_after_silence_ms,
    started: false,
    closed: false,
  }
  if self.closing || self.state_ is Closed(_) {
    stream.close_queue()
  } else {
    self.subscriptions.push(stream)
  }
  stream
}

///|
/// End this stream and unregister it from its connection. Repeated calls are
/// harmless, and a blocked `next_frame` wakes with `None`.
pub fn VoiceReceiveStream::close(self : VoiceReceiveStream) -> Unit {
  guard !self.closed else { return }
  self.connection.remove_subscription(self)
  self.close_queue()
}

///|
pub impl AudioSource for VoiceReceiveStream with fn next_frame(self) {
  guard !self.closed else { return None }
  let next : Bytes? = match (self.started, self.end_after_silence_ms) {
    (true, Some(timeout_ms)) =>
      @async.with_timeout_opt(timeout_ms, () => self.queue.get()) catch {
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
    Some(frame) => {
      self.started = true
      Some(frame)
    }
    None => {
      self.close()
      None
    }
  }
}
