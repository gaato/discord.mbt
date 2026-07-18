///|
fn validate_sticker_fields(
  name : String?,
  description : String?,
  tags : String?,
  allow_empty_description~ : Bool,
) -> Unit raise DiscordHttpError {
  validate_length("sticker name", name, min=2, max=30)
  // Create documents "empty or 2-100 characters"; modify documents 2-100
  // with null (clear_description) as the way to drop it.
  validate_length(
    "sticker description",
    description,
    min=2,
    max=100,
    allow_empty=allow_empty_description,
  )
  validate_length("sticker tags", tags, min=1, max=200)
}

///|
fn sticker_form_fields(
  body : Json,
) -> Array[(String, String)] raise DiscordHttpError {
  guard body is Object(fields) else {
    raise Validation(message="sticker form body must be an object")
  }
  let result : Array[(String, String)] = []
  for key in ["name", "description", "tags"] {
    guard fields.get(key) is Some(String(value)) else {
      raise Validation(message="sticker form field \{key} must be a string")
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
  decode(self.request(GetSticker(sticker_id~)))
}

///|
/// List Discord's standard sticker packs.
pub async fn Client::list_sticker_packs(
  self : Client,
) -> @model.StickerPacksResponse raise DiscordHttpError {
  decode(self.request(ListStickerPacks))
}

///|
/// Fetch one standard sticker pack.
pub async fn Client::get_sticker_pack(
  self : Client,
  pack_id : @model.StickerPackId,
) -> @model.StickerPack raise DiscordHttpError {
  decode(self.request(GetStickerPack(pack_id~)))
}

///|
/// List a guild's custom stickers.
pub async fn Client::list_guild_stickers(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Sticker] raise DiscordHttpError {
  decode(self.request(ListGuildStickers(guild_id~)))
}

///|
/// Fetch one guild sticker.
pub async fn Client::get_guild_sticker(
  self : Client,
  guild_id : @model.GuildId,
  sticker_id : @model.StickerId,
) -> @model.Sticker raise DiscordHttpError {
  decode(self.request(GetGuildSticker(guild_id~, sticker_id~)))
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
  validate_sticker_fields(
    Some(name),
    Some(description),
    Some(tags),
    allow_empty_description=true,
  )
  if file.content.length() > 512 * 1024 {
    raise Validation(message="guild sticker file exceeds 512 KiB")
  }
  let body = @model.ObjBuilder()
    .field("name", name)
    .field("description", description)
    .field("tags", tags)
    .build()
  decode(
    self.request(CreateGuildSticker(guild_id~), body~, audit_reason?, files=[
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
  validate_sticker_fields(
    name,
    description,
    tags,
    allow_empty_description=false,
  )
  let body = @model.ObjBuilder()
    .opt("name", name)
    .und(
      "description",
      patch_nullable("description", description, clear_description),
    )
    .opt("tags", tags)
    .build()
  decode(
    self.request(
      ModifyGuildSticker(guild_id~, sticker_id~),
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
  self.request(DeleteGuildSticker(guild_id~, sticker_id~), audit_reason?)
  |> ignore
}
