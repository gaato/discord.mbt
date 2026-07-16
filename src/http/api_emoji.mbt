///|
priv struct EmojiItems {
  items : Array[@model.Emoji]
} derive(FromJson)

///|
fn decode_application_emoji_items(
  json : Json,
) -> Array[@model.Emoji] raise DiscordHttpError {
  let envelope : EmojiItems = decode(json)
  envelope.items
}

///|
fn create_application_emoji_body(name : String, image : String) -> Json {
  @model.ObjBuilder().field("name", name).field("image", image).build()
}

///|
fn modify_application_emoji_body(name : String) -> Json {
  @model.ObjBuilder().field("name", name).build()
}

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

///|
/// List every custom emoji owned by an application.
pub async fn Client::list_application_emojis(
  self : Client,
  application_id : @model.ApplicationId,
) -> Array[@model.Emoji] raise DiscordHttpError {
  decode_application_emoji_items(
    self.request(ListApplicationEmojis(application_id~)),
  )
}

///|
/// Fetch one custom application emoji.
pub async fn Client::get_application_emoji(
  self : Client,
  application_id : @model.ApplicationId,
  emoji_id : @model.EmojiId,
) -> @model.Emoji raise DiscordHttpError {
  decode(self.request(GetApplicationEmoji(application_id~, emoji_id~)))
}

///|
/// Create a custom application emoji. `image` is a data URI.
pub async fn Client::create_application_emoji(
  self : Client,
  application_id : @model.ApplicationId,
  name : String,
  image : String,
) -> @model.Emoji raise DiscordHttpError {
  let body = create_application_emoji_body(name, image)
  decode(self.request(CreateApplicationEmoji(application_id~), body~))
}

///|
/// Rename a custom application emoji.
pub async fn Client::modify_application_emoji(
  self : Client,
  application_id : @model.ApplicationId,
  emoji_id : @model.EmojiId,
  name : String,
) -> @model.Emoji raise DiscordHttpError {
  let body = modify_application_emoji_body(name)
  decode(
    self.request(ModifyApplicationEmoji(application_id~, emoji_id~), body~),
  )
}

///|
/// Delete a custom application emoji.
pub async fn Client::delete_application_emoji(
  self : Client,
  application_id : @model.ApplicationId,
  emoji_id : @model.EmojiId,
) -> Unit raise DiscordHttpError {
  self.request(DeleteApplicationEmoji(application_id~, emoji_id~)) |> ignore
}
