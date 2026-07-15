///|
test "CDN asset URLs and defaults" {
  debug_inspect(
    [
      @util.user_avatar_url(Id(1UL), ImageHash("a_avatar"), size=128),
      @util.user_avatar_url(Id(1UL), ImageHash("avatar"), format=Webp),
      @util.default_user_avatar_url(Id(4194304UL)),
      @util.legacy_default_user_avatar_url(1234),
      @util.guild_icon_url(Id(2UL), ImageHash("icon"), size=16),
      @util.guild_banner_url(Id(2UL), ImageHash("a_banner")),
      @util.guild_splash_url(
        Id(2UL),
        ImageHash("splash"),
        format=Jpeg,
        size=4096,
      ),
      @util.emoji_url(Id(3UL), format=Gif, size=64),
      @util.sticker_url(Id(4UL), format=Lottie),
      @util.sticker_url(Id(5UL), format=Apng, size=256),
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
  try @util.emoji_url(Id(1UL), size=100) catch {
    InvalidSize(size) => inspect(size, content="100")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected invalid size")
  }

  try @util.sticker_url(Id(1UL), format=Unknown(99)) catch {
    UnsupportedStickerFormat(value) => inspect(value, content="99")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected unsupported sticker format")
  }
}
