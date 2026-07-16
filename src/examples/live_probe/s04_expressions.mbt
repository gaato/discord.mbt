///|
/// Guild emoji, application emoji, stickers, soundboard.
/// Keeps one emoji / sticker / sound alive for later sections; CRUD churn
/// happens on disposable secondaries.
async fn sec_expressions(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let data_uri = "data:image/png;base64," + EMOJI_PNG_B64

  // Guild emoji
  p.probe("create_guild_emoji", () => {
    let emoji = c.create_guild_emoji(
      g,
      "probe_emoji",
      data_uri,
      audit_reason="live probe",
    )
    p.s.emoji = emoji_id_of(emoji)
    p.s.emoji_name = emoji.name.to_option().unwrap_or("probe_emoji")
    "id=\{emoji_id_of(emoji).map_or("?", id => id.to_string())}"
  })
  p.probe("list_guild_emojis", () => {
    let emojis = c.list_guild_emojis(g)
    "count=\{emojis.length()}"
  })
  p.probe("get_guild_emoji", () => {
    let id = need(p.s.emoji, "guild emoji")
    let emoji = c.get_guild_emoji(g, id)
    "name=\{nul(emoji.name)}"
  })
  p.probe("modify_guild_emoji + EmojiRef round-trip", () => {
    let id = need(p.s.emoji, "guild emoji")
    let renamed = c.modify_guild_emoji(g, id, name="probe_emoji_2")
    ignore(renamed)
    let back = c.emoji_ref(g, id).edit(name="probe_emoji")
    ignore(c.emoji_ref(g, id).fetch())
    p.s.emoji_name = back.name.to_option().unwrap_or("probe_emoji")
    "name=\{p.s.emoji_name}"
  })
  p.probe("delete_guild_emoji (secondary)", () => {
    let emoji = c.create_guild_emoji(g, "probe_tmp_emoji", data_uri)
    let id = need(emoji_id_of(emoji), "secondary emoji id")
    c.delete_guild_emoji(g, id, audit_reason="live probe cleanup")
    "ok"
  })

  // Application emoji
  p.probe("create/list/get/modify/delete application emoji", () => {
    let created = c.create_application_emoji(
      p.app_id,
      "probe_app_emoji",
      data_uri,
    )
    let id = need(emoji_id_of(created), "app emoji id")
    let listed = c.list_application_emojis(p.app_id)
    let fetched = c.get_application_emoji(p.app_id, id)
    ignore(fetched)
    let renamed = c.modify_application_emoji(p.app_id, id, "probe_app_emoji2")
    ignore(renamed)
    ignore(c.application_emoji_ref(p.app_id, id).fetch())
    c.delete_application_emoji(p.app_id, id)
    "listed=\{listed.length()}"
  })

  // Stickers
  p.probe("create_guild_sticker", () => {
    let file = @dhttp.FileUpload(
      "probe.png",
      STICKER_PNG,
      content_type="image/png",
    )
    let sticker = c.create_guild_sticker(
      g,
      file,
      "probe sticker",
      "created by live probe",
      "robot",
      audit_reason="live probe",
    )
    p.s.sticker = Some(sticker.id)
    "id=\{sticker.id}"
  })
  p.probe("list_guild_stickers", () => {
    let stickers = c.list_guild_stickers(g)
    "count=\{stickers.length()}"
  })
  p.probe("get_guild_sticker", () => {
    let id = need(p.s.sticker, "sticker")
    let sticker = c.get_guild_sticker(g, id)
    "name=\{sticker.name}"
  })
  p.probe("modify_guild_sticker + StickerRef::fetch", () => {
    let id = need(p.s.sticker, "sticker")
    let edited = c.modify_guild_sticker(g, id, description="edited by probe")
    ignore(edited)
    let fetched = c.sticker_ref(g, id).fetch()
    "desc=\{fetched.description |> nul}"
  })
  p.probe("get_sticker (global lookup of guild sticker)", () => {
    let id = need(p.s.sticker, "sticker")
    let sticker = c.get_sticker(id)
    "name=\{sticker.name}"
  })
  p.probe("list_sticker_packs", () => {
    let packs = c.list_sticker_packs()
    "count=\{packs.sticker_packs.length()}"
  })
  p.probe("get_sticker_pack", () => {
    let packs = c.list_sticker_packs()
    guard packs.sticker_packs is [first, ..] else {
      raise ProbeError("no sticker packs listed")
    }
    let pack = c.get_sticker_pack(first.id)
    "name=\{pack.name}"
  })

  // Soundboard
  p.probe("list_default_soundboard_sounds", () => {
    let sounds = c.list_default_soundboard_sounds()
    "count=\{sounds.length()}"
  })
  p.probe("create_guild_soundboard_sound", () => {
    let sound = c.create_guild_soundboard_sound(
      g,
      "probe-sound",
      "data:audio/mpeg;base64," + MP3_B64,
      volume=0.5,
      emoji_name="🔔",
      audit_reason="live probe",
    )
    p.s.sound = Some(sound.sound_id)
    "id=\{sound.sound_id}"
  })
  p.probe("list_guild_soundboard_sounds", () => {
    let sounds = c.list_guild_soundboard_sounds(g)
    "count=\{sounds.length()}"
  })
  p.probe("get_guild_soundboard_sound", () => {
    let id = need(p.s.sound, "sound")
    let sound = c.get_guild_soundboard_sound(g, id)
    "name=\{sound.name}"
  })
  p.probe("modify_guild_soundboard_sound + SoundboardSoundRef", () => {
    let id = need(p.s.sound, "sound")
    let edited = c.modify_guild_soundboard_sound(g, id, volume=0.7)
    ignore(edited)
    let fetched = c.soundboard_sound_ref(g, id).fetch()
    "volume=\{fetched.volume}"
  })
  p.probe_err("send_soundboard_sound (bot not in voice)", expect=[400, 403], () => {
    let id = need(p.s.sound, "sound")
    let vc = need(p.s.voice, "voice channel")
    c.send_soundboard_sound(vc, id)
  })
}
