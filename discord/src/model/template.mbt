///|
/// A reusable Discord guild template and its serialized guild snapshot.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildTemplate {
  code : String
  name : String
  description : Nullable[String]
  usage_count : Int32
  creator_id : UserId
  creator : User
  created_at : Timestamp
  updated_at : Timestamp
  source_guild_id : GuildId
  serialized_source_guild : GuildTemplateSource
  is_dirty : Nullable[Bool]
}

///|
/// Stable guild settings exposed in a serialized template snapshot.
///
/// Discord uses integer placeholder IDs for nested roles and channels in this
/// payload, so this is intentionally distinct from `PartialGuild`.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildTemplateSource {
  name : String?
  description : Nullable[String]?
  region : String?
  verification_level : VerificationLevel?
  default_message_notifications : DefaultMessageNotifications?
  explicit_content_filter : ExplicitContentFilter?
  preferred_locale : String?
  afk_timeout : Int32?
  roles : Array[GuildTemplateRole]?
  channels : Array[GuildTemplateChannel]?
  afk_channel_id : Nullable[Int32]?
  system_channel_id : Nullable[Int32]?
  system_channel_flags : SystemChannelFlags?
  icon_hash : Nullable[ImageHash]?
}

///|
/// A role in a template snapshot, using the snapshot's integer placeholder ID.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildTemplateRole {
  id : Int32
  name : String
  permissions : GuildTemplatePermissions
  color : Int32
  colors : Nullable[RoleColors]?
  hoist : Bool
  mentionable : Bool
  icon : Nullable[ImageHash]?
  unicode_emoji : Nullable[String]?
}

///|
/// A channel in a template snapshot, using integer placeholder IDs.
#derive(ToJson(fields(typ(rename="type"))), FromJson(fields(typ(rename="type"))), Debug)
pub(all) struct GuildTemplateChannel {
  id : Int32
  typ : ChannelType
  name : String
  position : Int32
  topic : Nullable[String]?
  bitrate : Int32?
  user_limit : Int32?
  nsfw : Bool?
  rate_limit_per_user : Int32?
  parent_id : Nullable[Int32]?
  permission_overwrites : Array[GuildTemplatePermissionOverwrite]?
}

///|
/// A permission overwrite using a template placeholder ID.
#derive(ToJson(fields(typ(rename="type"))), FromJson(fields(typ(rename="type"))), Debug)
pub(all) struct GuildTemplatePermissionOverwrite {
  id : Int32
  typ : Int32
  allow : GuildTemplatePermissions
  deny : GuildTemplatePermissions
}

///|
/// A permission bitset encoded as a JSON number in template snapshots.
#derive(Eq)
pub(all) struct GuildTemplatePermissions(UInt64)

///|
/// The raw bit field.
pub fn GuildTemplatePermissions::bits(
  self : GuildTemplatePermissions,
) -> UInt64 {
  self.0
}

///|
/// Debug output is the raw bit field.
pub impl Debug for GuildTemplatePermissions with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the flags as a JSON number.
pub impl ToJson for GuildTemplatePermissions with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
/// Decodes the flags from a JSON number; unknown bits are kept.
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
