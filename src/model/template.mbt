///|
/// A reusable Discord guild template and its serialized guild snapshot.
pub(all) struct GuildTemplate {
  code : String
  name : String
  description : Nullable[String]
  usage_count : Int
  creator_id : UserId
  creator : User
  created_at : Timestamp
  updated_at : Timestamp
  source_guild_id : GuildId
  serialized_source_guild : GuildTemplateSource
  is_dirty : Nullable[Bool]
} derive(ToJson, FromJson, Debug)

///|
/// Stable guild settings exposed in a serialized template snapshot.
///
/// Discord uses integer placeholder IDs for nested roles and channels in this
/// payload, so this is intentionally distinct from `PartialGuild`.
pub(all) struct GuildTemplateSource {
  name : String?
  description : Nullable[String]?
  region : String?
  verification_level : VerificationLevel?
  default_message_notifications : DefaultMessageNotifications?
  explicit_content_filter : ExplicitContentFilter?
  preferred_locale : String?
  afk_timeout : Int?
  roles : Array[GuildTemplateRole]?
  channels : Array[GuildTemplateChannel]?
  afk_channel_id : Nullable[Int]?
  system_channel_id : Nullable[Int]?
  system_channel_flags : SystemChannelFlags?
  icon_hash : Nullable[ImageHash]?
} derive(ToJson, FromJson, Debug)

///|
/// A role in a template snapshot, using the snapshot's integer placeholder ID.
pub(all) struct GuildTemplateRole {
  id : Int
  name : String
  permissions : GuildTemplatePermissions
  color : Int
  colors : Nullable[RoleColors]?
  hoist : Bool
  mentionable : Bool
  icon : Nullable[ImageHash]?
  unicode_emoji : Nullable[String]?
} derive(ToJson, FromJson, Debug)

///|
/// A channel in a template snapshot, using integer placeholder IDs.
pub(all) struct GuildTemplateChannel {
  id : Int
  typ : ChannelType
  name : String
  position : Int
  topic : Nullable[String]?
  bitrate : Int?
  user_limit : Int?
  nsfw : Bool?
  rate_limit_per_user : Int?
  parent_id : Nullable[Int]?
  permission_overwrites : Array[GuildTemplatePermissionOverwrite]?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// A permission overwrite using a template placeholder ID.
pub(all) struct GuildTemplatePermissionOverwrite {
  id : Int
  typ : Int
  allow : GuildTemplatePermissions
  deny : GuildTemplatePermissions
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// A permission bitset encoded as a JSON number in template snapshots.
pub(all) struct GuildTemplatePermissions(UInt64) derive(Eq)

///|
pub fn GuildTemplatePermissions::bits(
  self : GuildTemplatePermissions,
) -> UInt64 {
  self.0
}

///|
pub impl Debug for GuildTemplatePermissions with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for GuildTemplatePermissions with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for GuildTemplatePermissions with fn from_json(
  json,
  path,
) {
  match json {
    Number(_, repr=Some(repr)) =>
      GuildTemplatePermissions(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected template permissions (number or string)"),
            )
        },
      )
    Number(value, repr=None) => GuildTemplatePermissions(value.to_uint64())
    // Discord serializes role permissions inside serialized_source_guild as a
    // decimal string (like Permissions elsewhere).
    String(value) =>
      GuildTemplatePermissions(
        @string.parse_uint64(value) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected template permissions (number or string)"),
            )
        },
      )
    _ =>
      raise JsonDecodeError(
        (path, "expected template permissions (number or string)"),
      )
  }
}
