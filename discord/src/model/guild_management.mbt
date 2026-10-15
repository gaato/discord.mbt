///|
/// A guild's public preview, available for discoverable guilds.
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
} derive(ToJson, FromJson, Debug)

///|
/// The result of banning several users in one request.
pub(all) struct BulkBanResponse {
  banned_users : Array[UserId]
  failed_users : Array[UserId]
} derive(ToJson, FromJson, Debug)

///|
/// The number of members pruned, or null when a begin-prune request did not
/// compute the count.
pub(all) struct GuildPruneResult {
  pruned : Nullable[Int32]
} derive(ToJson, FromJson, Debug)

///|
/// A guild's vanity invite code and its current use count.
pub(all) struct GuildVanityUrl {
  code : Nullable[String]
  uses : Int32
} derive(ToJson, FromJson, Debug)
