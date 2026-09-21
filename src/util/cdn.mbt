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
fn hashed_asset_url(
  directory : String,
  hash : @model.ImageHash,
  format : CdnImageFormat?,
  size : Int?,
) -> String raise CdnUrlError {
  let format = asset_format(hash, format)
  append_size(
    "\{cdn_base}/\{directory}/\{hash.to_string()}.\{format.extension()}",
    size,
  )
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
  hashed_asset_url("avatars/\{user_id}", avatar, format, size)
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
/// Build a user profile banner CDN URL.
pub fn user_banner_url(
  user_id : @model.UserId,
  banner : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("banners/\{user_id}", banner, format, size)
}

///|
/// Build the CDN URL of the avatar a member set for one guild
/// (`GuildMember::avatar`). `display_avatar_url` picks between this, the user
/// avatar, and the default avatar.
pub fn guild_member_avatar_url(
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  avatar : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url(
    "guilds/\{guild_id}/users/\{user_id}/avatars",
    avatar,
    format,
    size,
  )
}

///|
/// Build the CDN URL of the banner a member set for one guild.
pub fn guild_member_banner_url(
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  banner : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url(
    "guilds/\{guild_id}/users/\{user_id}/banners",
    banner,
    format,
    size,
  )
}

///|
/// Build the URL of the avatar Discord clients display for `user`: the guild
/// member avatar when `guild_member` carries one, otherwise the user avatar,
/// otherwise the default avatar. `format` and `size` do not apply to the
/// default avatar, which is always a fixed-size PNG.
pub fn display_avatar_url(
  user : @model.User,
  guild_member? : (@model.GuildId, @model.GuildMember),
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  if guild_member is Some((guild_id, profile)) &&
    @model.flatten(profile.avatar) is Some(avatar) {
    return hashed_asset_url(
      "guilds/\{guild_id}/users/\{user.id}/avatars",
      avatar,
      format,
      size,
    )
  }
  if user.avatar is Value(avatar) {
    return hashed_asset_url("avatars/\{user.id}", avatar, format, size)
  }
  // Accounts on the unique-username system report discriminator "0".
  let discriminator = @string.parse_int(user.discriminator) catch { _ => 0 }
  if discriminator == 0 {
    default_user_avatar_url(user.id)
  } else {
    legacy_default_user_avatar_url(discriminator)
  }
}

///|
/// Build an avatar decoration CDN URL from `AvatarDecorationData::asset`.
/// Decorations are served as PNG only.
pub fn avatar_decoration_url(
  asset : @model.ImageHash,
  size? : Int,
) -> String raise CdnUrlError {
  append_size(
    "\{cdn_base}/avatar-decoration-presets/\{asset.to_string()}.png",
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
  hashed_asset_url("icons/\{guild_id}", icon, format, size)
}

///|
/// Build a guild banner CDN URL.
pub fn guild_banner_url(
  guild_id : @model.GuildId,
  banner : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("banners/\{guild_id}", banner, format, size)
}

///|
/// Build a guild invite-splash CDN URL.
pub fn guild_splash_url(
  guild_id : @model.GuildId,
  splash : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("splashes/\{guild_id}", splash, format, size)
}

///|
/// Build a guild discovery-splash CDN URL.
pub fn guild_discovery_splash_url(
  guild_id : @model.GuildId,
  discovery_splash : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url(
    "discovery-splashes/\{guild_id}",
    discovery_splash,
    format,
    size,
  )
}

///|
/// Build a guild tag badge CDN URL from `UserPrimaryGuild::badge`.
pub fn guild_tag_badge_url(
  guild_id : @model.GuildId,
  badge : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("guild-tag-badges/\{guild_id}", badge, format, size)
}

///|
/// Build a role icon CDN URL.
pub fn role_icon_url(
  role_id : @model.RoleId,
  icon : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("role-icons/\{role_id}", icon, format, size)
}

///|
/// Build a guild scheduled event cover image CDN URL.
pub fn scheduled_event_cover_url(
  scheduled_event_id : @model.ScheduledEventId,
  image : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("guild-events/\{scheduled_event_id}", image, format, size)
}

///|
/// Build an application icon CDN URL.
pub fn application_icon_url(
  application_id : @model.ApplicationId,
  icon : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("app-icons/\{application_id}", icon, format, size)
}

///|
/// Build an application cover image CDN URL. The cover shares the icon's
/// `app-icons` directory.
pub fn application_cover_url(
  application_id : @model.ApplicationId,
  cover_image : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("app-icons/\{application_id}", cover_image, format, size)
}

///|
/// Build a team icon CDN URL.
pub fn team_icon_url(
  team_id : @model.TeamId,
  icon : @model.ImageHash,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  hashed_asset_url("team-icons/\{team_id}", icon, format, size)
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

///|
/// Build a sticker pack banner CDN URL from `StickerPack::banner_asset_id`.
/// Every pack banner lives under Discord's own sticker application.
pub fn sticker_pack_banner_url(
  banner_asset_id : @model.GenericId,
  format? : CdnImageFormat,
  size? : Int,
) -> String raise CdnUrlError {
  let format = format.unwrap_or(Png)
  append_size(
    "\{cdn_base}/app-assets/710982414301790216/store/\{banner_asset_id}.\{format.extension()}",
    size,
  )
}
