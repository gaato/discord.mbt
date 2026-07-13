///|
/// A reusable soundboard sound configured for Discord playback.
pub(all) struct SoundboardSound {
  name : String
  sound_id : SoundboardSoundId
  volume : Double
  emoji_id : Nullable[EmojiId]
  emoji_name : Nullable[String]
  guild_id : GuildId?
  available : Bool
  user : User?
} derive(ToJson, FromJson, Debug)
