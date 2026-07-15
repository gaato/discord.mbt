///|
/// List every custom emoji in a guild.
pub async fn Client::list_guild_emojis(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Emoji] raise DiscordHttpError {
  decode(self.request(ListGuildEmojis(guild_id~)))
}

///|
/// Fetch one custom guild emoji.
pub async fn Client::get_guild_emoji(
  self : Client,
  guild_id : @model.GuildId,
  emoji_id : @model.EmojiId,
) -> @model.Emoji raise DiscordHttpError {
  decode(self.request(GetGuildEmoji(guild_id~, emoji_id~)))
}

///|
/// Create a custom guild emoji. `image` is a data URI.
pub async fn Client::create_guild_emoji(
  self : Client,
  guild_id : @model.GuildId,
  name : String,
  image : String,
  roles? : Array[@model.RoleId],
  audit_reason? : String,
) -> @model.Emoji raise DiscordHttpError {
  let body = @model.ObjBuilder()
    .field("name", name)
    .field("image", image)
    .opt("roles", roles)
    .build()
  decode(self.request(CreateGuildEmoji(guild_id~), body~, audit_reason?))
}

///|
/// Modify a custom guild emoji.
pub async fn Client::modify_guild_emoji(
  self : Client,
  guild_id : @model.GuildId,
  emoji_id : @model.EmojiId,
  name? : String,
  roles? : Array[@model.RoleId],
  audit_reason? : String,
) -> @model.Emoji raise DiscordHttpError {
  let body = @model.ObjBuilder().opt("name", name).opt("roles", roles).build()
  decode(
    self.request(ModifyGuildEmoji(guild_id~, emoji_id~), body~, audit_reason?),
  )
}

///|
/// Delete a custom guild emoji.
pub async fn Client::delete_guild_emoji(
  self : Client,
  guild_id : @model.GuildId,
  emoji_id : @model.EmojiId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(DeleteGuildEmoji(guild_id~, emoji_id~), audit_reason?) |> ignore
}
