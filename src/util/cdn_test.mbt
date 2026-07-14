///|
test "CDN asset URLs and defaults" {
  debug_inspect(
    [
      @util.user_avatar_url(
        @model.Id(1UL),
        @model.ImageHash("a_avatar"),
        size=128,
      ),
      @util.user_avatar_url(
        @model.Id(1UL),
        @model.ImageHash("avatar"),
        format=@util.CdnImageFormat::Webp,
      ),
      @util.default_user_avatar_url(@model.Id(4194304UL)),
      @util.legacy_default_user_avatar_url(1234),
      @util.guild_icon_url(@model.Id(2UL), @model.ImageHash("icon"), size=16),
      @util.guild_banner_url(@model.Id(2UL), @model.ImageHash("a_banner")),
      @util.guild_splash_url(
        @model.Id(2UL),
        @model.ImageHash("splash"),
        format=@util.CdnImageFormat::Jpeg,
        size=4096,
      ),
      @util.emoji_url(@model.Id(3UL), format=@util.CdnImageFormat::Gif, size=64),
      @util.sticker_url(@model.Id(4UL), format=@model.StickerFormatType::Lottie),
      @util.sticker_url(
        @model.Id(5UL),
        format=@model.StickerFormatType::Apng,
        size=256,
      ),
    ],
    content=(
      #|[
      #|  "https://cdn.discordapp.com/avatars/1/a_avatar.gif?size=128",
      #|  "https://cdn.discordapp.com/avatars/1/avatar.webp",
      #|  "https://cdn.discordapp.com/embed/avatars/1.png",
      #|  "https://cdn.discordapp.com/embed/avatars/4.png",
      #|  "https://cdn.discordapp.com/icons/2/icon.png?size=16",
      #|  "https://cdn.discordapp.com/banners/2/a_banner.gif",
      #|  "https://cdn.discordapp.com/splashes/2/splash.jpeg?size=4096",
      #|  "https://cdn.discordapp.com/emojis/3.gif?size=64",
      #|  "https://cdn.discordapp.com/stickers/4.json",
      #|  "https://cdn.discordapp.com/stickers/5.png?size=256",
      #|]
    ),
  )
}

///|
test "CDN URLs reject invalid size and unknown sticker format" {
  try @util.emoji_url(@model.Id(1UL), size=100) catch {
    @util.CdnUrlError::InvalidSize(size) => inspect(size, content="100")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected invalid size")
  }

  try
    @util.sticker_url(
      @model.Id(1UL),
      format=@model.StickerFormatType::Unknown(99),
    )
  catch {
    @util.CdnUrlError::UnsupportedStickerFormat(value) =>
      inspect(value, content="99")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected unsupported sticker format")
  }
}
