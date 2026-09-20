///|
/// Native Discord HTTP-interactions server.
pub using @endpoint_http {type InteractionsServer, serve_interactions}

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
  SILENCE_FRAME,
}

///|
/// Native gateway executor and typed event descriptors.
pub using @bot {
  type Bot,
  type GatewayCtx,
  type EventType,
  type Events,
  type BotError,
  type ShardConfig,
}
