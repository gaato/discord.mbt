///|
fn validate_soundboard_fields(
  name : String?,
  volume : Double?,
) -> Unit raise DiscordHttpError {
  validate_length("soundboard sound name", name, min=2, max=32)
  if volume is Some(value) && (value < 0.0 || value > 1.0) {
    raise Validation(message="soundboard volume must be between 0 and 1")
  }
}

///|
/// Play a soundboard sound in a voice channel.
pub async fn Client::send_soundboard_sound(
  self : Client,
  channel_id : @model.ChannelId,
  sound_id : @model.SoundboardSoundId,
  source_guild_id? : @model.GuildId,
) -> Unit raise DiscordHttpError {
  let body = @model.ObjBuilder()
    .field("sound_id", sound_id)
    .opt("source_guild_id", source_guild_id)
    .build()
  self.request(SendSoundboardSound(channel_id~), body~) |> ignore
}

///|
/// List Discord's built-in soundboard sounds.
pub async fn Client::list_default_soundboard_sounds(
  self : Client,
) -> Array[@model.SoundboardSound] raise DiscordHttpError {
  decode(self.request(ListDefaultSoundboardSounds))
}

///|
priv struct SoundboardSoundItems {
  items : Array[@model.SoundboardSound]
} derive(FromJson)

///|
/// List the custom soundboard sounds in a guild. Unlike the default-sound
/// listing, this endpoint wraps the array in an `items` envelope.
pub async fn Client::list_guild_soundboard_sounds(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.SoundboardSound] raise DiscordHttpError {
  let envelope : SoundboardSoundItems = decode(
    self.request(ListGuildSoundboardSounds(guild_id~)),
  )
  envelope.items
}

///|
/// Fetch one guild soundboard sound.
pub async fn Client::get_guild_soundboard_sound(
  self : Client,
  guild_id : @model.GuildId,
  sound_id : @model.SoundboardSoundId,
) -> @model.SoundboardSound raise DiscordHttpError {
  decode(self.request(GetGuildSoundboardSound(guild_id~, sound_id~)))
}

///|
/// Create a guild soundboard sound. `sound` is Discord's base64 data URI.
pub async fn Client::create_guild_soundboard_sound(
  self : Client,
  guild_id : @model.GuildId,
  name : String,
  sound : String,
  volume? : Double,
  emoji_id? : @model.EmojiId,
  emoji_name? : String,
  audit_reason? : String,
) -> @model.SoundboardSound raise DiscordHttpError {
  validate_soundboard_fields(Some(name), volume)
  let body = @model.ObjBuilder()
    .field("name", name)
    .field("sound", sound)
    .opt("volume", volume)
    .opt("emoji_id", emoji_id)
    .opt("emoji_name", emoji_name)
    .build()
  decode(
    self.request(CreateGuildSoundboardSound(guild_id~), body~, audit_reason?),
  )
}

///|
/// Modify a guild soundboard sound.
pub async fn Client::modify_guild_soundboard_sound(
  self : Client,
  guild_id : @model.GuildId,
  sound_id : @model.SoundboardSoundId,
  name? : String,
  volume? : Double,
  emoji_id? : @model.EmojiId,
  clear_emoji_id? : Bool = false,
  emoji_name? : String,
  clear_emoji_name? : Bool = false,
  audit_reason? : String,
) -> @model.SoundboardSound raise DiscordHttpError {
  validate_soundboard_fields(name, volume)
  let body = @model.ObjBuilder()
    .opt("name", name)
    .opt("volume", volume)
    .und("emoji_id", patch_nullable("emoji_id", emoji_id, clear_emoji_id))
    .und(
      "emoji_name",
      patch_nullable("emoji_name", emoji_name, clear_emoji_name),
    )
    .build()
  decode(
    self.request(
      ModifyGuildSoundboardSound(guild_id~, sound_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Delete a guild soundboard sound.
pub async fn Client::delete_guild_soundboard_sound(
  self : Client,
  guild_id : @model.GuildId,
  sound_id : @model.SoundboardSoundId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(DeleteGuildSoundboardSound(guild_id~, sound_id~), audit_reason?)
  |> ignore
}
