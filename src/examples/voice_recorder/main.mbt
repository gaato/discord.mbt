///|
/// Record one user's received Opus packets into an Ogg file, stopping after one
/// second of silence. Set DISCORD_TOKEN, GUILD_ID, CHANNEL_ID, TARGET_USER_ID,
/// and optionally OUTPUT_PATH (defaults to `recording.ogg`):
///   moon run --target native --release src/examples/voice_recorder
suberror VoiceRecorderError {
  MissingEnvironmentVariable(String)
} derive(Debug)

///|
fn required_env(name : String) -> String raise VoiceRecorderError {
  match @env.get_env_var(name) {
    Some(value) if !value.is_empty() => value
    _ => raise MissingEnvironmentVariable(name)
  }
}

///|
fn env_or(name : String, default : String) -> String {
  match @env.get_env_var(name) {
    Some(value) if !value.is_empty() => value
    _ => default
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
    let target_user_id = required_env("TARGET_USER_ID")
    let output_path = env_or("OUTPUT_PATH", "recording.ogg")
    let app = @discord.App(sync=Disabled)
    let intents = @model.Intents::guilds() |
      @model.Intents::guild_voice_states()
    let bot = @discord.Bot(app, token~, intents~)
    bot.service(name="voice-recorder", ctx => {
      let connection = ctx.join_voice(guild_id, channel_id)
      errdefer @async.protect_from_cancel(() => {
        connection.disconnect() catch {
          _ => ()
        }
      })
      let stream = connection.subscribe(
        user_id=target_user_id,
        end_after_silence_ms=Some(1000),
      )
      errdefer stream.close()
      let audio : &@discord.AudioSource = stream
      guard audio.next_frame() is Some(first) else {
        stream.close()
        connection.disconnect()
        ctx.shutdown()
        return
      }
      println("[voice] recording \{target_user_id} ...")
      let output = @fs.create(output_path)
      defer output.close()
      let writer = @discord.OggOpusWriter::new(channels=2)
      let mut frame_count = 1
      writer.write_frame(first)
      output.write(writer.take_output())
      while audio.next_frame() is Some(frame) {
        writer.write_frame(frame)
        frame_count += 1
        output.write(writer.take_output())
      }
      writer.finish()
      output.write(writer.take_output())
      println("[voice] saved \{output_path} (\{frame_count} frames)")
      stream.close()
      connection.disconnect()
      ctx.shutdown()
    })
    bot.run()
  } catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      ()
    error => println("[voice] failed: \{Repr(error)}")
  }
  println("[voice] disconnected")
}
