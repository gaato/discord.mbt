///|
/// Play one audio file in a voice channel, then leave. Files ending in `.ogg`
/// use the in-memory Ogg path; every other extension is transcoded and streamed
/// through ffmpeg without buffering the complete output.
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
async fn[X] load_audio_source(
  group : @async.TaskGroup[X],
  audio_path : String,
) -> (@discord.OggOpusSource, () -> Unit) {
  if audio_path.has_suffix(".ogg") {
    let audio = @fs.read_file(audio_path).binary()
    (@discord.OggOpusSource::from_bytes(audio), () => ())
  } else {
    let (stdout, process_stdout) = @process.read_from_process()
    errdefer stdout.close()
    @process.spawn(
      group,
      "ffmpeg",
      [
        "-loglevel", "error", "-i", audio_path, "-f", "ogg", "-c:a", "libopus", "-ar",
        "48000", "-ac", "2", "-frame_duration", "20", "pipe:1",
      ],
      stdout=process_stdout,
      no_wait=true,
    )
    |> ignore
    let source = @discord.OggOpusSource::from_reader(stdout)
    (source, () => stdout.close())
  }
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
  ignore(
    @async.handle_cancellation(() => {
      let token = required_env("DISCORD_TOKEN")
      let guild_id : @model.GuildId = @model.Id::parse(required_env("GUILD_ID"))
      let channel_id : @model.ChannelId = @model.Id::parse(
        required_env("CHANNEL_ID"),
      )
      let audio_path = required_env("AUDIO_FILE")
      @async.with_task_group(process_group => {
        let (source, close_source) = load_audio_source(
          process_group, audio_path,
        )
        defer close_source()
        let done : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
        let tracked = TrackedOggSource::{ source, done, finished: false, }
        let app = @discord.App()
        let intents = @model.Intents::guilds() |
          @model.Intents::guild_voice_states()
        let bot = @discord.Bot(app, token~, intents~)
        bot.service(name="voice-player", ctx => {
          let connection = ctx.join_voice(guild_id, channel_id)
          errdefer @async.protect_from_cancel(() => {
            connection.disconnect() catch {
              _ => ()
            }
          })
          println("[voice] connected; playing \{audio_path}")
          connection.play((tracked : &@discord.AudioSource))
          done.get()
          connection.stop()
          println("[voice] playback complete")
          connection.disconnect()
          ctx.shutdown()
        })
        bot.run()
      })
    }) catch {
      error => {
        println("[voice] failed: \{Repr(error)}")
        None
      }
    },
  )
  println("[voice] disconnected")
}
