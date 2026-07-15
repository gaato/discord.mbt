///|
let cdn_base = "https://cdn.discordapp.com"

///|
/// A raster image format accepted by Discord's CDN.
pub(all) enum CdnImageFormat {
  Png
  Jpeg
  Webp
  Gif
} derive(Eq, Debug)

///|
fn CdnImageFormat::extension(self : CdnImageFormat) -> String {
  match self {
    Png => "png"
    Jpeg => "jpeg"
    Webp => "webp"
    Gif => "gif"
  }
}

///|
/// Invalid CDN URL parameters rejected before a request is made.
pub(all) suberror CdnUrlError {
  InvalidSize(Int)
  UnsupportedStickerFormat(Int)
} derive(Eq, Debug)

///|
fn valid_size(size : Int) -> Bool {
  size >= 16 && size <= 4096 && (size & (size - 1)) == 0
}

///|
fn append_size(url : String, size : Int?) -> String raise CdnUrlError {
  match size {
    None => url
    Some(size) => {
      guard valid_size(size) else { raise InvalidSize(size) }
      "\{url}?size=\{size}"
    }
  }
}

///|
fn asset_format(
  hash : @model.ImageHash,
  requested : CdnImageFormat?,
) -> CdnImageFormat {
  match requested {
    Some(format) => format
    None => if hash.is_animated() { Gif } else { Png }
  }
}

///|
/// Build a user avatar CDN URL. Animated hashes default to GIF; other hashes
/// default to PNG.
///
/// ```mbt check
/// test "build avatar and emoji CDN URLs" {
///   let user_id : @model.UserId = Id(42UL)
///   inspect(
///     @util.user_avatar_url(user_id, ImageHash("a_deadbeef"), size=128),
///     content="https://cdn.discordapp.com/avatars/42/a_deadbeef.gif?size=128",
///   )
///   let emoji_id : @model.EmojiId = Id(7UL)
///   inspect(
///     @util.emoji_url(emoji_id, format=Webp, size=64),
///     content="https://cdn.discordapp.com/emojis/7.webp?size=64",
///   )
/// }
/// ```
pub fn user_avatar_url(
  user_id : @model.UserId,
  avatar : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  let format = asset_format(avatar, format)
  append_size(
    "\{cdn_base}/avatars/\{user_id}/\{avatar.to_string()}.\{format.extension()}",
    size,
  )
}

///|
/// Build a default avatar URL for Discord's username system.
///
/// The avatar index is `(user_id >> 22) % 6`.
///
/// ```mbt check
/// test "derive the default avatar from a snowflake" {
///   let user_id : @model.UserId = Id(1UL << 22)
///   inspect(
///     @util.default_user_avatar_url(user_id),
///     content="https://cdn.discordapp.com/embed/avatars/1.png",
///   )
/// }
/// ```
pub fn default_user_avatar_url(user_id : @model.UserId) -> String {
  let index = (user_id.value() >> 22) % 6UL
  "\{cdn_base}/embed/avatars/\{index}.png"
}

///|
/// Build a legacy discriminator-based default avatar URL.
pub fn legacy_default_user_avatar_url(discriminator : Int) -> String {
  "\{cdn_base}/embed/avatars/\{discriminator % 5}.png"
}

///|
fn guild_asset_url(
  kind : String,
  guild_id : @model.GuildId,
  hash : @model.ImageHash,
  format : CdnImageFormat?,
  size : Int?,
) -> String raise CdnUrlError {
  let format = asset_format(hash, format)
  append_size(
    "\{cdn_base}/\{kind}/\{guild_id}/\{hash.to_string()}.\{format.extension()}",
    size,
  )
}

///|
/// Build a guild icon CDN URL.
pub fn guild_icon_url(
  guild_id : @model.GuildId,
  icon : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  guild_asset_url("icons", guild_id, icon, format, size)
}

///|
/// Build a guild banner CDN URL.
pub fn guild_banner_url(
  guild_id : @model.GuildId,
  banner : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  guild_asset_url("banners", guild_id, banner, format, size)
}

///|
/// Build a guild invite-splash CDN URL.
pub fn guild_splash_url(
  guild_id : @model.GuildId,
  splash : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  guild_asset_url("splashes", guild_id, splash, format, size)
}

///|
/// Build a custom emoji CDN URL. PNG is the default when no format is given.
pub fn emoji_url(
  emoji_id : @model.EmojiId,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  let format = format.unwrap_or(Png)
  append_size("\{cdn_base}/emojis/\{emoji_id}.\{format.extension()}", size)
}

///|
/// Build a sticker CDN URL. Sticker format is required because the ID alone
/// does not encode whether the asset is PNG/APNG, Lottie JSON, or GIF.
pub fn sticker_url(
  sticker_id : @model.StickerId,
  format~ : @model.StickerFormatType,
  size? : Int,
) -> String raise CdnUrlError {
  let extension = match format {
    Png | Apng => "png"
    Lottie => "json"
    Gif => "gif"
    Unknown(value) => raise UnsupportedStickerFormat(value)
  }
  append_size("\{cdn_base}/stickers/\{sticker_id}.\{extension}", size)
}
