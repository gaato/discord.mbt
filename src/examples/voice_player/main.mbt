///|
/// Play one Ogg/Opus file in a voice channel, then leave.
///
/// Prepare a compatible file with:
///   ffmpeg -i input.mp3 -c:a libopus -ar 48000 -ac 2 -frame_duration 20 -f ogg out.ogg
///
/// Run with DISCORD_TOKEN, GUILD_ID, CHANNEL_ID, and AUDIO_FILE set:
///   moon run --target native --release src/examples/voice_player
suberror VoicePlayerError {
  MissingEnvironmentVariable(String)
} derive(Debug)

///|
fn required_env(name : String) -> String raise VoicePlayerError {
  match @env.get_env_var(name) {
    Some(value) if !value.is_empty() => value
    _ => raise MissingEnvironmentVariable(name)
  }
}

///|
struct TrackedOggSource {
  source : @discord.OggOpusSource
  done : @aqueue.Queue[Unit]
  mut finished : Bool
}

///|
impl @discord.AudioSource for TrackedOggSource with fn next_frame(self) {
  match self.source.next_frame() {
    Some(frame) => Some(frame)
    None => {
      if !self.finished {
        self.finished = true
        self.done.try_put(()) |> ignore
      }
      None
    }
  }
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  try {
    let token = required_env("DISCORD_TOKEN")
    let guild_id : @model.GuildId = @model.Id::parse(required_env("GUILD_ID"))
    let channel_id : @model.ChannelId = @model.Id::parse(
      required_env("CHANNEL_ID"),
    )
    let audio_path = required_env("AUDIO_FILE")
    let audio = @fs.read_file(audio_path).binary()
    let source = @discord.OggOpusSource::from_bytes(audio)
    let done : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
    let tracked = TrackedOggSource::{ source, done, finished: false }
    let app = @discord.App(sync=Disabled)
    let bot = @discord.Bot(app, token~, intents=@model.Intents::guilds())
    bot.service(name="voice-player", ctx => {
      let connection = ctx.join_voice(guild_id, channel_id)
      try {
        println("[voice] connected; playing \{audio_path}")
        connection.play((tracked : &@discord.AudioSource))
        done.get()
        connection.stop()
        println("[voice] playback complete")
        connection.disconnect()
        ctx.shutdown()
      } catch {
        error => {
          connection.disconnect() catch {
            _ => ()
          }
          raise error
        }
      }
    })
    bot.run()
  } catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      ()
    error => println("[voice] failed: \{to_repr(error)}")
  }
  println("[voice] disconnected")
}
