///|
/// Join one existing voice channel, wait until libdave activates DAVE v1,
/// send one second of inaudible Opus silence, and disconnect. The probe does
/// not create or delete Discord resources. Keep another DAVE-capable Discord
/// client in the channel so the gateway can complete a multi-member MLS group.
/// Set DAVE_PROBE_AUDIBLE=1 and DAVE_PROBE_AUDIO_FILE to an Ogg/Opus file for
/// an explicit, manually confirmed peer-decryption check. Audible playback is
/// capped at 150 20 ms frames (three seconds).
/// Set DAVE_PROBE_RECEIVE=1 to wait up to 20 seconds for ten decrypted peer
/// Opus frames. Receive mode counts frames only and does not store audio.
/// Set DAVE_PROBE_ECHO=1 to hold 100 frames in memory and play them back once;
/// echo mode does not write the received audio to disk.
/// Set DAVE_PROBE_RECORD_PATH to write the same Speaking-gated capture as an
/// Ogg/Opus file. Recording is never enabled without an explicit path.
///
/// Run with DISCORD_TOKEN, GUILD_ID, and CHANNEL_ID set:
///   moon run --target native --release src/examples/dave_probe
suberror DaveProbeError {
  MissingEnvironmentVariable(String)
  DavePeerRequired(negotiated_version~ : Int)
  DaveActivationTimeout(negotiated_version~ : Int)
  DaveMediaFailure(String)
  DaveReceiveTimeout
  ProbeDidNotComplete
} derive(Debug)

///|
fn required_env(name : String) -> String raise DaveProbeError {
  match @env.get_env_var(name) {
    Some(value) if !value.is_empty() => value
    _ => raise MissingEnvironmentVariable(name)
  }
}

///|
struct SilenceProbeSource {
  mut remaining : Int
  done : @aqueue.Queue[Unit]
  mut finished : Bool
}

///|
impl @discord.AudioSource for SilenceProbeSource with fn next_frame(self) {
  if self.remaining > 0 {
    self.remaining -= 1
    Some(@discord.SILENCE_FRAME)
  } else {
    if !self.finished {
      self.finished = true
      self.done.try_put(()) |> ignore
    }
    None
  }
}

///|
struct AudibleProbeSource {
  source : @discord.OggOpusSource
  done : @aqueue.Queue[Unit]
  frames : Ref[Int]
  mut remaining : Int
  mut finished : Bool
}

///|
fn AudibleProbeSource::finish(self : AudibleProbeSource) -> Unit {
  if !self.finished {
    self.finished = true
    (self.done.try_put(()) |> ignore) catch {
      _ => ()
    }
  }
}

///|
impl @discord.AudioSource for AudibleProbeSource with fn next_frame(self) {
  if self.remaining == 0 {
    self.finish()
    return None
  }
  match self.source.next_frame() {
    Some(frame) => {
      self.remaining -= 1
      self.frames.val += 1
      Some(frame)
    }
    None => {
      self.finish()
      None
    }
  }
}

///|
struct BufferedProbeSource {
  frames : Array[Bytes]
  done : @aqueue.Queue[Unit]
  mut cursor : Int
  mut finished : Bool
}

///|
struct UnmappedDropSample {
  ssrc : UInt
  at_ms : Int64
}

///|
struct DropCorrelation {
  matching : Int
  other : Int
  first_lead_ms : Int64
  last_lead_ms : Int64
}

///|
fn BufferedProbeSource::finish(self : BufferedProbeSource) -> Unit {
  if !self.finished {
    self.finished = true
    (self.done.try_put(()) |> ignore) catch {
      _ => ()
    }
  }
}

///|
impl @discord.AudioSource for BufferedProbeSource with fn next_frame(self) {
  match self.frames.get(self.cursor) {
    Some(frame) => {
      self.cursor += 1
      Some(frame)
    }
    None => {
      self.finish()
      None
    }
  }
}

///|
fn audible_probe_path() -> String? raise DaveProbeError {
  match @env.get_env_var("DAVE_PROBE_AUDIBLE") {
    Some("1") => Some(required_env("DAVE_PROBE_AUDIO_FILE"))
    _ => None
  }
}

///|
fn receive_probe_enabled() -> Bool {
  @env.get_env_var("DAVE_PROBE_RECEIVE") == Some("1") || echo_probe_enabled()
}

///|
fn echo_probe_enabled() -> Bool {
  @env.get_env_var("DAVE_PROBE_ECHO") == Some("1")
}

///|
fn record_probe_path() -> String? {
  match @env.get_env_var("DAVE_PROBE_RECORD_PATH") {
    Some(path) if !path.is_empty() => Some(path)
    _ => None
  }
}

///|
fn is_transient_unmapped_sender(reason : String) -> Bool {
  reason == "DAVE frame has no mapped sender"
}

///|
fn correlate_unmapped_drops(
  samples : Array[UnmappedDropSample],
  peer_ssrc~ : UInt,
  speaking_at_ms~ : Int64,
) -> DropCorrelation {
  let mut matching = 0
  let mut other = 0
  let mut first_at_ms = speaking_at_ms
  let mut last_at_ms = speaking_at_ms
  for sample in samples {
    if sample.ssrc == peer_ssrc {
      if matching == 0 {
        first_at_ms = sample.at_ms
      }
      last_at_ms = sample.at_ms
      matching += 1
    } else {
      other += 1
    }
  }
  {
    matching,
    other,
    first_lead_ms: speaking_at_ms - first_at_ms,
    last_lead_ms: speaking_at_ms - last_at_ms,
  }
}

///|
fn report_drop_correlation(
  samples : Array[UnmappedDropSample],
  peer_ssrc~ : UInt,
  speaking_at_ms~ : Int64,
) -> Unit {
  let correlation = correlate_unmapped_drops(
    samples,
    peer_ssrc~,
    speaking_at_ms~,
  )
  println(
    "[dave] pre-mapping correlation: \{correlation.matching} peer SSRC frame(s), \{correlation.other} other SSRC frame(s)",
  )
  if correlation.matching > 0 {
    println(
      "[dave] peer UDP led Speaking mapping by first/last: \{correlation.first_lead_ms}/\{correlation.last_lead_ms} ms",
    )
  }
}

///|
async fn receive_peer_probe(
  connection : @discord.VoiceConnection,
  required_frames : Int,
  unmapped_drops : Array[UnmappedDropSample],
) -> Array[Bytes] {
  println("[dave] receive probe waiting for peer speaking (20 second timeout)")
  let frames : Array[Bytes] = []
  let sender : Ref[String?] = Ref(None)
  let warmup_frames = Ref(5)
  @async.with_timeout_opt(20_000, () => {
    while frames.length() < required_frames {
      match connection.next_event() {
        SpeakingChanged(user_id~, ssrc~, flags~) if flags != 0 &&
          sender.val is None => {
          sender.val = Some(user_id)
          report_drop_correlation(
            unmapped_drops,
            peer_ssrc=ssrc,
            speaking_at_ms=@clock.now_ms(),
          )
          println(
            "[dave] peer speaking detected; capturing decrypted Opus (memory only)",
          )
        }
        OpusReceived(user_id=Some(user_id), opus~, ..) =>
          match sender.val {
            Some(selected) if selected == user_id =>
              if warmup_frames.val > 0 {
                warmup_frames.val -= 1
              } else {
                frames.push(opus)
              }
            Some(_) => ()
            None => ()
          }
        _ => ()
      }
    }
  })
  |> ignore
  frames
}

///|
fn opus_frame_size_stats(frames : Array[Bytes]) -> (Int, Int, Int) {
  guard frames.get(0) is Some(first) else { return (0, 0, 0) }
  let mut minimum = first.length()
  let mut maximum = minimum
  let mut total = 0
  for frame in frames {
    let size = frame.length()
    minimum = minimum.min(size)
    maximum = maximum.max(size)
    total += size
  }
  (minimum, total / frames.length(), maximum)
}

///|
async fn play_silence_probe(connection : @discord.VoiceConnection) -> Int {
  let done : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let source = SilenceProbeSource::{ remaining: 50, done, finished: false }
  connection.play((source : &@discord.AudioSource))
  guard @async.with_timeout_opt(5_000, () => done.get()) is Some(_) else {
    raise DaveMediaFailure("timed out while sending silent Opus")
  }
  50
}

///|
async fn play_audible_probe(
  connection : @discord.VoiceConnection,
  audio_path : String,
) -> Int {
  let audio = @fs.read_file(audio_path).binary()
  let ogg = @discord.OggOpusSource::from_bytes(audio)
  let done : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let frames = Ref(0)
  let source = AudibleProbeSource::{
    source: ogg,
    done,
    frames,
    remaining: 150,
    finished: false,
  }
  println(
    "[dave] audible peer-decryption probe started (maximum three seconds)",
  )
  connection.play((source : &@discord.AudioSource))
  guard @async.with_timeout_opt(10_000, () => done.get()) is Some(_) else {
    raise DaveMediaFailure("timed out while sending audible Opus")
  }
  guard frames.val > 0 else {
    raise DaveMediaFailure("audible Ogg/Opus file contained no audio frames")
  }
  frames.val
}

///|
async fn play_echo_probe(
  connection : @discord.VoiceConnection,
  frames : Array[Bytes],
) -> Int {
  let done : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let source = BufferedProbeSource::{ frames, done, cursor: 0, finished: false }
  println("[dave] echoing decrypted peer Opus once (memory only)")
  connection.play((source : &@discord.AudioSource))
  guard @async.with_timeout_opt(5_000, () => done.get()) is Some(_) else {
    raise DaveMediaFailure("timed out while echoing peer Opus")
  }
  connection.stop()
  frames.length()
}

///|
async fn write_probe_recording(frames : Array[Bytes], path : String) -> Unit {
  let writer = @discord.OggOpusWriter::new(channels=2)
  for frame in frames {
    writer.write_frame(frame)
  }
  writer.finish()
  let output = @fs.create(path)
  defer output.close()
  output.write(writer.take_output())
  println("[dave] wrote memory-only capture to requested Ogg/Opus path")
}

///|
async fn run_probe(
  ctx : @discord.GatewayCtx,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
) -> Unit {
  let negotiated_version = Ref(-1)
  let peer_seen = Ref(false)
  let activations : @aqueue.Queue[Int] = Queue(kind=Unbounded)
  let dave_failures : Array[String] = []
  let unmapped_sender_drops : Array[UnmappedDropSample] = []
  let connection = ctx.join_voice(guild_id, channel_id, timeout_ms=20_000, telemetry=event => {
    match event {
      GatewayEvent(SessionEstablished(dave_protocol_version~, ..)) => {
        negotiated_version.val = dave_protocol_version
        println(
          "[dave] voice session negotiated protocol v\{dave_protocol_version}",
        )
      }
      GatewayEvent(Message(DavePrepareEpoch(epoch~, protocol_version~))) =>
        println("[dave] prepare epoch \{epoch} for v\{protocol_version}")
      GatewayEvent(Message(DaveMlsExternalSender(..))) =>
        println("[dave] received external sender")
      GatewayEvent(Message(DaveMlsProposals(payload~))) =>
        println("[dave] received proposals (\{payload.length()} bytes)")
      GatewayEvent(
        Message(DaveMlsAnnounceCommitTransition(transition_id~, commit~))
      ) =>
        println(
          "[dave] received commit for transition \{transition_id} (\{commit.length()} bytes)",
        )
      GatewayEvent(Message(DaveMlsWelcome(transition_id~, welcome~))) =>
        println(
          "[dave] received Welcome for transition \{transition_id} (\{welcome.length()} bytes)",
        )
      GatewayEvent(
        Message(DavePrepareTransition(transition_id~, protocol_version~))
      ) =>
        println(
          "[dave] prepare transition \{transition_id} for v\{protocol_version}",
        )
      GatewayEvent(Message(DaveExecuteTransition(transition_id~))) =>
        println("[dave] execute transition \{transition_id}")
      GatewayEvent(Message(ClientsConnect(user_ids~))) => {
        if !user_ids.is_empty() {
          peer_seen.val = true
        }
        println(
          "[dave] voice roster announced \{user_ids.length()} participant(s)",
        )
      }
      DaveMediaContextActivated(protocol_version~) => {
        println("[dave] media context activated v\{protocol_version}")
        if protocol_version >= 1 {
          (activations.try_put(protocol_version) |> ignore) catch {
            _ => ()
          }
        }
      }
      DaveBinaryControlSent(opcode~, payload_bytes~) =>
        println(
          "[dave] sent binary opcode \{opcode} (\{payload_bytes} payload bytes)",
        )
      PacketDropped(reason~) if reason.contains("DAVE") =>
        dave_failures.push(reason)
      DaveEncryptDropped(reason~) => dave_failures.push(reason)
      DaveDecryptDropped(ssrc~, reason~, ..) =>
        if is_transient_unmapped_sender(reason) {
          unmapped_sender_drops.push({ ssrc, at_ms: @clock.now_ms() })
        } else {
          dave_failures.push(reason)
        }
      _ => ()
    }
  })
  errdefer @async.protect_from_cancel(() => connection.disconnect())
  guard @async.with_timeout_opt(30_000, () => activations.get())
    is Some(version) else {
    if !peer_seen.val {
      raise DavePeerRequired(negotiated_version=negotiated_version.val)
    }
    raise DaveActivationTimeout(negotiated_version=negotiated_version.val)
  }
  let audio_mode = match audible_probe_path() {
    Some(path) => {
      let frames = play_audible_probe(connection, path)
      "audible peer-check (\{frames} Opus frames)"
    }
    None => {
      let frames = play_silence_probe(connection)
      "silent transport-check (\{frames} Opus frames)"
    }
  }
  connection.stop()
  let recording_path = record_probe_path()
  let required_receive_frames = if echo_probe_enabled() ||
    recording_path is Some(_) {
    100
  } else if receive_probe_enabled() {
    10
  } else {
    0
  }
  let received = if required_receive_frames > 0 {
    receive_peer_probe(
      connection, required_receive_frames, unmapped_sender_drops,
    )
  } else {
    []
  }
  if received.length() < required_receive_frames {
    raise DaveReceiveTimeout
  }
  if !received.is_empty() {
    let (minimum, average, maximum) = opus_frame_size_stats(received)
    println(
      "[dave] captured Opus packet bytes min/avg/max: \{minimum}/\{average}/\{maximum}",
    )
  }
  let echoed_frames = if echo_probe_enabled() {
    play_echo_probe(connection, received)
  } else {
    0
  }
  if recording_path is Some(path) {
    write_probe_recording(received, path)
  }
  guard dave_failures.length() == 0 else {
    raise DaveMediaFailure(dave_failures[0])
  }
  println("[dave] encrypted \{audio_mode} with media context v\{version}")
  if !received.is_empty() {
    println("[dave] decrypted \{received.length()} peer Opus frames")
  }
  if echoed_frames > 0 {
    println("[dave] re-encrypted and echoed \{echoed_frames} peer Opus frames")
  }
  if !unmapped_sender_drops.is_empty() {
    println(
      "[dave] warning: dropped \{unmapped_sender_drops.length()} inbound frame(s) before sender mapping",
    )
  }
  connection.disconnect()
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  let token = required_env("DISCORD_TOKEN")
  let guild_id : @model.GuildId = @model.Id::parse(required_env("GUILD_ID"))
  let channel_id : @model.ChannelId = @model.Id::parse(
    required_env("CHANNEL_ID"),
  )
  let app = @discord.App(sync=Disabled)
  let intents = @model.Intents::guilds() | @model.Intents::guild_voice_states()
  let bot = @discord.Bot(app, token~, intents~)
  let completed = Ref(false)
  let failure : Ref[String?] = Ref(None)
  bot.service(name="dave-probe", ctx => {
    try {
      run_probe(ctx, guild_id, channel_id)
      completed.val = true
    } catch {
      error => {
        let reason = "\{Repr(error)}"
        failure.val = Some(reason)
        match error {
          DavePeerRequired(..) =>
            println(
              "[dave] live probe INCONCLUSIVE: no other voice participant was announced; \{reason}",
            )
          _ => println("[dave] live probe FAIL: \{reason}")
        }
      }
    }
    @async.protect_from_cancel(() => ctx.shutdown())
  })
  let run_result = @async.with_timeout_opt(90_000, () => bot.run()) catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      Some(())
    error => raise error
  }
  guard run_result is Some(_) else { raise DaveProbeError::ProbeDidNotComplete }
  if failure.val is Some(reason) {
    raise DaveMediaFailure(reason)
  }
  guard completed.val else { raise DaveProbeError::ProbeDidNotComplete }
  println("[dave] live probe PASS; disconnected cleanly")
}
