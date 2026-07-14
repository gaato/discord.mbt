///|
fn validate_sticker_fields(
  name : String?,
  description : String?,
  tags : String?,
) -> Unit raise DiscordHttpError {
  if name is Some(value) && (value.length() < 2 || value.length() > 30) {
    raise DiscordHttpError::Validation(
      message="sticker name must be between 2 and 30 characters",
    )
  }
  if description is Some(value) && (value.length() < 2 || value.length() > 100) {
    raise DiscordHttpError::Validation(
      message="sticker description must be between 2 and 100 characters",
    )
  }
  if tags is Some(value) && (value.length() < 1 || value.length() > 200) {
    raise DiscordHttpError::Validation(
      message="sticker tags must be between 1 and 200 characters",
    )
  }
}

///|
fn sticker_form_fields(
  body : Json,
) -> Array[(String, String)] raise DiscordHttpError {
  guard body is Object(fields) else {
    raise DiscordHttpError::Validation(
      message="sticker form body must be an object",
    )
  }
  let result : Array[(String, String)] = []
  for key in ["name", "description", "tags"] {
    guard fields.get(key) is Some(String(value)) else {
      raise DiscordHttpError::Validation(
        message="sticker form field \{key} must be a string",
      )
    }
    result.push((key, value))
  }
  result
}

///|
/// Fetch a sticker by id.
pub async fn Client::get_sticker(
  self : Client,
  sticker_id : @model.StickerId,
) -> @model.Sticker raise DiscordHttpError {
  decode(self.request(Route::GetSticker(sticker_id~)))
}

///|
/// List Discord's standard sticker packs.
pub async fn Client::list_sticker_packs(
  self : Client,
) -> @model.StickerPacksResponse raise DiscordHttpError {
  decode(self.request(Route::ListStickerPacks))
}

///|
/// Fetch one standard sticker pack.
pub async fn Client::get_sticker_pack(
  self : Client,
  pack_id : @model.StickerPackId,
) -> @model.StickerPack raise DiscordHttpError {
  decode(self.request(Route::GetStickerPack(pack_id~)))
}

///|
/// List a guild's custom stickers.
pub async fn Client::list_guild_stickers(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Sticker] raise DiscordHttpError {
  decode(self.request(Route::ListGuildStickers(guild_id~)))
}

///|
/// Fetch one guild sticker.
pub async fn Client::get_guild_sticker(
  self : Client,
  guild_id : @model.GuildId,
  sticker_id : @model.StickerId,
) -> @model.Sticker raise DiscordHttpError {
  decode(self.request(Route::GetGuildSticker(guild_id~, sticker_id~)))
}

///|
/// Create a guild sticker using Discord's dedicated multipart form shape.
pub async fn Client::create_guild_sticker(
  self : Client,
  guild_id : @model.GuildId,
  file : FileUpload,
  name : String,
  description : String,
  tags : String,
  audit_reason? : String,
) -> @model.Sticker raise DiscordHttpError {
  validate_sticker_fields(Some(name), Some(description), Some(tags))
  if file.content.length() > 512 * 1024 {
    raise DiscordHttpError::Validation(
      message="guild sticker file exceeds 512 KiB",
    )
  }
  let body = @model.ObjBuilder::new()
    .field("name", name)
    .field("description", description)
    .field("tags", tags)
    .build()
  decode(
    self.request(Route::CreateGuildSticker(guild_id~), body~, audit_reason?, files=[
      file,
    ]),
  )
}

///|
/// Modify a guild sticker.
pub async fn Client::modify_guild_sticker(
  self : Client,
  guild_id : @model.GuildId,
  sticker_id : @model.StickerId,
  name? : String,
  description? : String,
  clear_description? : Bool = false,
  tags? : String,
  audit_reason? : String,
) -> @model.Sticker raise DiscordHttpError {
  validate_sticker_fields(name, description, tags)
  let body = @model.ObjBuilder::new()
    .opt("name", name)
    .und(
      "description",
      patch_nullable("description", description, clear_description),
    )
    .opt("tags", tags)
    .build()
  decode(
    self.request(
      Route::ModifyGuildSticker(guild_id~, sticker_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Delete a guild sticker.
pub async fn Client::delete_guild_sticker(
  self : Client,
  guild_id : @model.GuildId,
  sticker_id : @model.StickerId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::DeleteGuildSticker(guild_id~, sticker_id~), audit_reason?)
  |> ignore
}
