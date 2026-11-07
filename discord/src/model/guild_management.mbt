///|
/// A guild's public preview, available for discoverable guilds.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildPreview {
  id : GuildId
  name : String
  icon : Nullable[ImageHash]
  splash : Nullable[ImageHash]
  discovery_splash : Nullable[ImageHash]
  emojis : Array[Emoji]
  features : Array[GuildFeature]
  approximate_member_count : Int32
  approximate_presence_count : Int32
  description : Nullable[String]
  stickers : Array[Sticker]
}

///|
/// The result of banning several users in one request.
#derive(ToJson, FromJson, Debug)
pub(all) struct BulkBanResponse {
  banned_users : Array[UserId]
  failed_users : Array[UserId]
}

///|
/// The number of members pruned, or null when a begin-prune request did not
/// compute the count.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildPruneResult {
  pruned : Nullable[Int32]
}

///|
/// A guild's vanity invite code and its current use count.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildVanityUrl {
  code : Nullable[String]
  uses : Int32
}
