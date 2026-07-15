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
  approximate_guild_count : Int?
  approximate_user_install_count : Int?
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
  approximate_user_authorization_count : Int?
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
pub(all) enum ApplicationEventWebhookStatus {
  Disabled
  Enabled
  DisabledByDiscord
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ApplicationEventWebhookStatus::to_int(
  self : ApplicationEventWebhookStatus,
) -> Int {
  match self {
    Disabled => 1
    Enabled => 2
    DisabledByDiscord => 3
    Unknown(value) => value
  }
}

///|
pub fn ApplicationEventWebhookStatus::from_int(
  value : Int,
) -> ApplicationEventWebhookStatus {
  match value {
    1 => Disabled
    2 => Enabled
    3 => DisabledByDiscord
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ApplicationEventWebhookStatus with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
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
pub fn ApplicationFlags::none() -> ApplicationFlags {
  ApplicationFlags(0)
}

///|
pub fn ApplicationFlags::from_bits(bits : UInt64) -> ApplicationFlags {
  ApplicationFlags(bits)
}

///|
pub fn ApplicationFlags::bits(self : ApplicationFlags) -> UInt64 {
  self.0
}

///|
pub fn ApplicationFlags::contains(
  self : ApplicationFlags,
  other : ApplicationFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for ApplicationFlags with fn lor(a, b) {
  ApplicationFlags(a.0 | b.0)
}

///|
pub impl BitAnd for ApplicationFlags with fn land(a, b) {
  ApplicationFlags(a.0 & b.0)
}

///|
pub impl Debug for ApplicationFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for ApplicationFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for ApplicationFlags with fn from_json(json, path) {
  match json {
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
pub fn ApplicationFlags::embedded_released() -> ApplicationFlags {
  ApplicationFlags(1UL << 1)
}

///|
pub fn ApplicationFlags::managed_emoji() -> ApplicationFlags {
  ApplicationFlags(1UL << 2)
}

///|
pub fn ApplicationFlags::embedded_iap() -> ApplicationFlags {
  ApplicationFlags(1UL << 3)
}

///|
pub fn ApplicationFlags::group_dm_create() -> ApplicationFlags {
  ApplicationFlags(1UL << 4)
}

///|
pub fn ApplicationFlags::application_auto_moderation_rule_create_badge() -> ApplicationFlags {
  ApplicationFlags(1UL << 6)
}

///|
pub fn ApplicationFlags::rpc_has_connected() -> ApplicationFlags {
  ApplicationFlags(1UL << 11)
}

///|
pub fn ApplicationFlags::gateway_presence() -> ApplicationFlags {
  ApplicationFlags(1UL << 12)
}

///|
pub fn ApplicationFlags::gateway_presence_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 13)
}

///|
pub fn ApplicationFlags::gateway_guild_members() -> ApplicationFlags {
  ApplicationFlags(1UL << 14)
}

///|
pub fn ApplicationFlags::gateway_guild_members_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 15)
}

///|
pub fn ApplicationFlags::verification_pending_guild_limit() -> ApplicationFlags {
  ApplicationFlags(1UL << 16)
}

///|
pub fn ApplicationFlags::embedded() -> ApplicationFlags {
  ApplicationFlags(1UL << 17)
}

///|
pub fn ApplicationFlags::gateway_message_content() -> ApplicationFlags {
  ApplicationFlags(1UL << 18)
}

///|
pub fn ApplicationFlags::gateway_message_content_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 19)
}

///|
pub fn ApplicationFlags::embedded_first_party() -> ApplicationFlags {
  ApplicationFlags(1UL << 20)
}

///|
pub fn ApplicationFlags::application_command_badge() -> ApplicationFlags {
  ApplicationFlags(1UL << 23)
}
