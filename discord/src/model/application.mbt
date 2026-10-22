///|
/// A Discord application record. Fields that are absent from partial
/// application payloads remain optional on receipt.
pub(all) struct Application {
  id : ApplicationId
  name : String
  icon : Nullable[ImageHash]
  description : String
  bot : User?
  owner : User?
  flags : ApplicationFlags?
  /// Full application flag bitfield returned as `flags_new` when Discord uses
  /// bits above 30. Request payloads must continue to use `flags`.
  flags_new : ApplicationFlags?
  approximate_guild_count : Int32?
  approximate_user_install_count : Int32?
  rpc_origins : Array[String]?
  bot_public : Bool?
  bot_require_code_grant : Bool?
  terms_of_service_url : String?
  privacy_policy_url : String?
  verify_key : String?
  team : Nullable[Team]?
  guild_id : GuildId?
  guild : PartialGuild?
  primary_sku_id : SkuId?
  slug : String?
  cover_image : ImageHash?
  approximate_user_authorization_count : Int32?
  redirect_uris : Array[String]?
  interactions_endpoint_url : Nullable[String]?
  role_connections_verification_url : Nullable[String]?
  event_webhooks_url : Nullable[String]?
  event_webhooks_status : ApplicationEventWebhookStatus?
  event_webhooks_types : Array[String]?
  tags : Array[String]?
  install_params : InstallParams?
  integration_types_config : Map[
    String,
    ApplicationIntegrationTypeConfiguration,
  ]?
  custom_install_url : String?
} derive(ToJson, FromJson, Debug)

///|
/// Return Discord's full response bitfield when present, falling back to the
/// legacy numeric `flags` field for older payloads.
pub fn Application::effective_flags(self : Application) -> ApplicationFlags? {
  match self.flags_new {
    Some(flags) => Some(flags)
    None => self.flags
  }
}

///|
/// Default OAuth2 installation scopes and bot permissions for an application.
pub(all) struct InstallParams {
  scopes : Array[String]
  permissions : Permissions
} derive(ToJson, FromJson, Debug)

///|
/// Installation settings for one application integration context.
pub(all) struct ApplicationIntegrationTypeConfiguration {
  oauth2_install_params : InstallParams?
} derive(ToJson, FromJson, Debug)

///|
/// Whether Discord delivers event webhooks to the application;
/// `DisabledByDiscord` means delivery was deactivated for inactivity.
#non_exhaustive
pub(all) enum ApplicationEventWebhookStatus {
  Disabled
  Enabled
  DisabledByDiscord
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `ApplicationEventWebhookStatus`.
pub fn ApplicationEventWebhookStatus::to_int(
  self : ApplicationEventWebhookStatus,
) -> Int32 {
  match self {
    Disabled => 1
    Enabled => 2
    DisabledByDiscord => 3
    Unknown(value) => value
  }
}

///|
/// The `ApplicationEventWebhookStatus` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn ApplicationEventWebhookStatus::from_int(
  value : Int32,
) -> ApplicationEventWebhookStatus {
  match value {
    1 => Disabled
    2 => Enabled
    3 => DisabledByDiscord
    value => Unknown(value)
  }
}

///|
/// Encodes the `ApplicationEventWebhookStatus` as its Discord integer value.
pub impl ToJson for ApplicationEventWebhookStatus with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `ApplicationEventWebhookStatus` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for ApplicationEventWebhookStatus with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => ApplicationEventWebhookStatus::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected application event webhook status (number)"),
      )
  }
}

///|
/// Bit flags describing capabilities and privileged access for an application.
pub(all) struct ApplicationFlags(UInt64) derive(Eq)

///|
/// No flags set.
pub fn ApplicationFlags::none() -> ApplicationFlags {
  ApplicationFlags(0)
}

///|
/// Flags from a raw bit field; unknown bits are kept.
pub fn ApplicationFlags::from_bits(bits : UInt64) -> ApplicationFlags {
  ApplicationFlags(bits)
}

///|
/// The raw bit field.
pub fn ApplicationFlags::bits(self : ApplicationFlags) -> UInt64 {
  self.0
}

///|
/// Whether every flag in `other` is set.
pub fn ApplicationFlags::contains(
  self : ApplicationFlags,
  other : ApplicationFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Combines flags: every flag set in either operand is set.
pub impl BitOr for ApplicationFlags with fn lor(a, b) {
  ApplicationFlags(a.0 | b.0)
}

///|
/// Keeps the flags set in both operands.
pub impl BitAnd for ApplicationFlags with fn land(a, b) {
  ApplicationFlags(a.0 & b.0)
}

///|
/// Debug output is the raw bit field.
pub impl Debug for ApplicationFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the flags as a JSON number.
pub impl ToJson for ApplicationFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
/// Decodes the flags from a JSON number; unknown bits are kept.
pub impl @json.FromJson for ApplicationFlags with fn from_json(json, path) {
  match json {
    String(repr) =>
      ApplicationFlags(
        @string.parse_uint64(repr) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected application flags (integer string), got \{repr}"),
            )
        },
      )
    Number(_, repr=Some(repr)) =>
      ApplicationFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected application flags (number), got \\{repr}"),
            )
        },
      )
    Number(value, repr=None) => ApplicationFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected application flags (number)"))
  }
}

///|
/// Bit `1 << 1`, which Discord sets but does not document.
pub fn ApplicationFlags::embedded_released() -> ApplicationFlags {
  ApplicationFlags(1UL << 1)
}

///|
/// Bit `1 << 2`, which Discord sets but does not document.
pub fn ApplicationFlags::managed_emoji() -> ApplicationFlags {
  ApplicationFlags(1UL << 2)
}

///|
/// Bit `1 << 3`, which Discord sets but does not document.
pub fn ApplicationFlags::embedded_iap() -> ApplicationFlags {
  ApplicationFlags(1UL << 3)
}

///|
/// Bit `1 << 4`, which Discord sets but does not document.
pub fn ApplicationFlags::group_dm_create() -> ApplicationFlags {
  ApplicationFlags(1UL << 4)
}

///|
/// App uses the Auto Moderation API.
pub fn ApplicationFlags::application_auto_moderation_rule_create_badge() -> ApplicationFlags {
  ApplicationFlags(1UL << 6)
}

///|
/// Bit `1 << 11`, which Discord sets but does not document.
pub fn ApplicationFlags::rpc_has_connected() -> ApplicationFlags {
  ApplicationFlags(1UL << 11)
}

///|
/// Presence intent for bots in 100 or more servers.
pub fn ApplicationFlags::gateway_presence() -> ApplicationFlags {
  ApplicationFlags(1UL << 12)
}

///|
/// Presence intent for bots in fewer than 100 servers.
pub fn ApplicationFlags::gateway_presence_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 13)
}

///|
/// Server members intent for bots in 100 or more servers.
pub fn ApplicationFlags::gateway_guild_members() -> ApplicationFlags {
  ApplicationFlags(1UL << 14)
}

///|
/// Server members intent for bots in fewer than 100 servers.
pub fn ApplicationFlags::gateway_guild_members_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 15)
}

///|
/// Unusual growth of the app is preventing verification.
pub fn ApplicationFlags::verification_pending_guild_limit() -> ApplicationFlags {
  ApplicationFlags(1UL << 16)
}

///|
/// App is embedded within the Discord client.
pub fn ApplicationFlags::embedded() -> ApplicationFlags {
  ApplicationFlags(1UL << 17)
}

///|
/// Message content intent for bots in 100 or more servers.
pub fn ApplicationFlags::gateway_message_content() -> ApplicationFlags {
  ApplicationFlags(1UL << 18)
}

///|
/// Message content intent for bots in fewer than 100 servers.
pub fn ApplicationFlags::gateway_message_content_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 19)
}

///|
/// Bit `1 << 20`, which Discord sets but does not document.
pub fn ApplicationFlags::embedded_first_party() -> ApplicationFlags {
  ApplicationFlags(1UL << 20)
}

///|
/// App has registered global application commands.
pub fn ApplicationFlags::application_command_badge() -> ApplicationFlags {
  ApplicationFlags(1UL << 23)
}
