///|
/// Experimental native voice connection, playback, and receive APIs.
pub using @voice {
  type VoiceConnection,
  type VoiceEvent,
  type VoiceError,
  type VoiceConnectionState,
  type VoiceTelemetry,
  trait AudioSource,
  type OggOpusSource,
  type OggOpusWriter,
  type OggOpusError,
  type VoiceReceiveStream,
  type ReceivedAudio,
  SILENCE_FRAME,
}
