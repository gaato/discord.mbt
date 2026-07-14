///|
/// The documented subset of a guild embedded in another Discord resource.
///
/// Partial guild payloads vary by endpoint, so fields other than `id` are
/// optional on receipt.
pub(all) struct PartialGuild {
  id : GuildId
  name : String?
  icon : Nullable[ImageHash]?
  splash : Nullable[ImageHash]?
  banner : Nullable[ImageHash]?
  description : Nullable[String]?
  features : Array[GuildFeature]?
  verification_level : VerificationLevel?
  vanity_url_code : Nullable[String]?
  nsfw_level : NsfwLevel?
  premium_subscription_count : Int?
  locale : String?
} derive(ToJson, FromJson, Debug)

///|
/// The documented subset of a channel embedded in another Discord resource.
pub(all) struct PartialChannel {
  id : ChannelId
  typ : ChannelType?
  name : Nullable[String]?
  icon : Nullable[ImageHash]?
  permissions : Permissions?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The subset of a role returned on an invite.
pub(all) struct PartialRole {
  id : RoleId
  name : String
  position : Int
  color : Int
  colors : RoleColors?
  icon : Nullable[ImageHash]?
  unicode_emoji : Nullable[String]?
} derive(ToJson, FromJson, Debug)
