///|
test "animated WebP keeps animation and combines size query" {
  assert_eq(
    @util.user_avatar_url(Id(1UL), ImageHash("a_hash"), format=Webp),
    "https://cdn.discordapp.com/avatars/1/a_hash.webp?animated=true",
  )
  assert_eq(
    @util.guild_icon_url(Id(1UL), ImageHash("a_hash"), format=Webp, size=128),
    "https://cdn.discordapp.com/icons/1/a_hash.webp?animated=true&size=128",
  )
  assert_eq(
    @util.sticker_url(Id(1UL), format=Gif),
    "https://media.discordapp.net/stickers/1.gif",
  )
}

///|
test "static CDN endpoints accept raster formats but never GIF or animated defaults" {
  let builders : Array[
    (@util.CdnImageFormat?) -> String raise @util.CdnUrlError,
  ] = [
    format => @util.guild_splash_url(Id(1UL), ImageHash("a_hash"), format?),
    format => {
      @util.guild_discovery_splash_url(Id(1UL), ImageHash("a_hash"), format?)
    },
    format => @util.guild_tag_badge_url(Id(1UL), ImageHash("a_hash"), format?),
    format => @util.role_icon_url(Id(1UL), ImageHash("a_hash"), format?),
    format => {
      @util.scheduled_event_cover_url(Id(1UL), ImageHash("a_hash"), format?)
    },
    format => @util.application_icon_url(Id(1UL), ImageHash("a_hash"), format?),
    format => @util.application_cover_url(Id(1UL), ImageHash("a_hash"), format?),
    format => @util.team_icon_url(Id(1UL), ImageHash("a_hash"), format?),
    format => @util.sticker_pack_banner_url(Id(1UL), format?),
  ]
  for build in builders {
    assert_true(build(None).has_suffix(".png"))
    for
      (format, extension) in [
        (@util.CdnImageFormat::Png, "png"),
        (Jpeg, "jpeg"),
        (Webp, "webp"),
      ] {
      assert_true(build(Some(format)).has_suffix("." + extension))
    }
    try build(Some(Gif)) catch {
      @util.CdnUrlError::UnsupportedFormat(..) => ()
      error => raise error
    } noraise {
      _ => fail("expected unsupported format")
    }
  }
}

///|
test "animated CDN endpoint format and size matrix" {
  let builders : Array[
    (@util.CdnImageFormat, Int) -> String raise @util.CdnUrlError,
  ] = [
    (format, size) => {
      @util.user_avatar_url(Id(1UL), ImageHash("a_hash"), format~, size~)
    },
    (format, size) => {
      @util.user_banner_url(Id(1UL), ImageHash("a_hash"), format~, size~)
    },
    (format, size) => {
      @util.guild_icon_url(Id(1UL), ImageHash("a_hash"), format~, size~)
    },
    (format, size) => {
      @util.guild_banner_url(Id(1UL), ImageHash("a_hash"), format~, size~)
    },
    (format, size) => {
      @util.guild_member_avatar_url(
        Id(1UL),
        Id(2UL),
        ImageHash("a_hash"),
        format~,
        size~,
      )
    },
    (format, size) => {
      @util.guild_member_banner_url(
        Id(1UL),
        Id(2UL),
        ImageHash("a_hash"),
        format~,
        size~,
      )
    },
  ]
  for build in builders {
    for size in [16, 32, 64, 128, 256, 512, 1024, 2048, 4096] {
      for format in [@util.CdnImageFormat::Png, Jpeg, Webp, Gif] {
        let url = build(format, size)
        assert_true(url.has_suffix("size=\{size}"))
        assert_eq(url.contains("animated=true"), format == Webp)
      }
    }
    for size in [0, 15, 100, 8192] {
      try build(Png, size) catch {
        @util.CdnUrlError::InvalidSize(_) => ()
        error => raise error
      } noraise {
        _ => fail("expected invalid size")
      }
    }
  }
}

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
      @util.sticker_url(Id(5UL), format=Apng),
      @util.user_banner_url(Id(1UL), ImageHash("a_banner")),
      @util.guild_member_avatar_url(Id(2UL), Id(1UL), ImageHash("a_local")),
      @util.guild_member_banner_url(Id(2UL), Id(1UL), ImageHash("local")),
      @util.avatar_decoration_url(ImageHash("a_decoration"), size=64),
      @util.guild_discovery_splash_url(Id(2UL), ImageHash("discovery")),
      @util.guild_tag_badge_url(Id(2UL), ImageHash("badge")),
      @util.role_icon_url(Id(6UL), ImageHash("role"), format=Webp),
      @util.scheduled_event_cover_url(Id(7UL), ImageHash("cover")),
      @util.application_icon_url(Id(8UL), ImageHash("icon")),
      @util.application_cover_url(Id(8UL), ImageHash("cover")),
      @util.team_icon_url(Id(9UL), ImageHash("team")),
      @util.sticker_pack_banner_url(Id(10UL), size=1024),
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
      #|  "https://cdn.discordapp.com/stickers/5.png",
      #|  "https://cdn.discordapp.com/banners/1/a_banner.gif",
      #|  "https://cdn.discordapp.com/guilds/2/users/1/avatars/a_local.gif",
      #|  "https://cdn.discordapp.com/guilds/2/users/1/banners/local.png",
      #|  "https://cdn.discordapp.com/avatar-decoration-presets/a_decoration.png?size=64",
      #|  "https://cdn.discordapp.com/discovery-splashes/2/discovery.png",
      #|  "https://cdn.discordapp.com/guild-tag-badges/2/badge.png",
      #|  "https://cdn.discordapp.com/role-icons/6/role.webp",
      #|  "https://cdn.discordapp.com/guild-events/7/cover.png",
      #|  "https://cdn.discordapp.com/app-icons/8/icon.png",
      #|  "https://cdn.discordapp.com/app-icons/8/cover.png",
      #|  "https://cdn.discordapp.com/team-icons/9/team.png",
      #|  "https://cdn.discordapp.com/app-assets/710982414301790216/store/10.png?size=1024",
      #|]
    ),
  )
}

///|
test "CDN URLs reject invalid size and unknown sticker format" {
  try @util.emoji_url(Id(1UL), size=100) catch {
    InvalidSize(size) => inspect(size, content="100")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid size")
  }

  try @util.sticker_url(Id(1UL), format=Unknown(99)) catch {
    UnsupportedStickerFormat(value) => inspect(value, content="99")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsupported sticker format")
  }
}

///|
test "display avatar falls back from guild member to user to default" {
  fn user(avatar : Json, discriminator : String) -> @model.User raise {
    @json.from_json({
      "id": "4194304",
      "username": "mona",
      "discriminator": discriminator,
      "avatar": avatar,
    })
  }

  fn guild_member(avatar : Json) -> (@model.GuildId, @model.GuildMember) raise {
    (
      Id(7UL),
      @json.from_json({ "avatar": avatar, "roles": [], "joined_at": null }),
    )
  }

  debug_inspect(
    [
      @util.display_avatar_url(
        user("global", "0"),
        guild_member=guild_member("a_local"),
        size=64,
      ),
      @util.display_avatar_url(
        user("global", "0"),
        guild_member=guild_member(null),
        format=Webp,
      ),
      @util.display_avatar_url(user("global", "0")),
      @util.display_avatar_url(user(null, "0"), size=64),
      @util.display_avatar_url(user(null, "1234")),
    ],
    content=(
      #|[
      #|  "https://cdn.discordapp.com/guilds/7/users/4194304/avatars/a_local.gif?size=64",
      #|  "https://cdn.discordapp.com/avatars/4194304/global.webp",
      #|  "https://cdn.discordapp.com/avatars/4194304/global.png",
      #|  "https://cdn.discordapp.com/embed/avatars/1.png",
      #|  "https://cdn.discordapp.com/embed/avatars/4.png",
      #|]
    ),
  )
}
