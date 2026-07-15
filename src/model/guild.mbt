///|
/// A Discord guild and its configured capabilities.
pub(all) struct Guild {
  id : GuildId
  name : String
  icon : Nullable[ImageHash]
  icon_hash : Nullable[ImageHash]?
  splash : Nullable[ImageHash]
  discovery_splash : Nullable[ImageHash]
  owner : Bool?
  owner_id : UserId
  permissions : Permissions?
  afk_channel_id : Nullable[ChannelId]
  afk_timeout : Int
  widget_enabled : Bool?
  widget_channel_id : Nullable[ChannelId]?
  verification_level : VerificationLevel
  default_message_notifications : DefaultMessageNotifications
  explicit_content_filter : ExplicitContentFilter
  roles : Array[Role]
  emojis : Array[Emoji]
  features : Array[GuildFeature]
  mfa_level : MfaLevel
  application_id : Nullable[ApplicationId]
  system_channel_id : Nullable[ChannelId]
  system_channel_flags : SystemChannelFlags
  rules_channel_id : Nullable[ChannelId]
  max_presences : Nullable[Int]?
  max_members : Int?
  vanity_url_code : Nullable[String]
  description : Nullable[String]
  banner : Nullable[ImageHash]
  premium_tier : PremiumTier
  premium_subscription_count : Int?
  preferred_locale : String
  public_updates_channel_id : Nullable[ChannelId]
  max_video_channel_users : Int?
  max_stage_video_channel_users : Int?
  approximate_member_count : Int?
  approximate_presence_count : Int?
  welcome_screen : WelcomeScreen?
  nsfw_level : NsfwLevel?
  stickers : Array[Sticker]?
  premium_progress_bar_enabled : Bool?
  safety_alerts_channel_id : Nullable[ChannelId]
  incidents_data : Nullable[IncidentsData]?
} derive(ToJson, FromJson, Debug)

///|
/// Temporary safety restrictions and detection timestamps for a guild.
pub(all) struct IncidentsData {
  invites_disabled_until : Nullable[Timestamp]?
  dms_disabled_until : Nullable[Timestamp]?
  dm_spam_detected_at : Nullable[Timestamp]?
  raid_detected_at : Nullable[Timestamp]?
} derive(ToJson, FromJson, Debug)

///|
/// The partial guild representation returned for the current user's guilds.
pub(all) struct CurrentUserGuild {
  id : GuildId
  name : String
  icon : Nullable[ImageHash]
  banner : Nullable[ImageHash]
  owner : Bool
  permissions : Permissions
  features : Array[GuildFeature]
  approximate_member_count : Int?
  approximate_presence_count : Int?
} derive(ToJson, FromJson, Debug)

///|
/// Discord's guild verification level.
pub(all) enum VerificationLevel {
  None
  Low
  Medium
  High
  VeryHigh
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn VerificationLevel::to_int(self : VerificationLevel) -> Int {
  match self {
    None => 0
    Low => 1
    Medium => 2
    High => 3
    VeryHigh => 4
    Unknown(value) => value
  }
}

///|
pub fn VerificationLevel::from_int(value : Int) -> VerificationLevel {
  match value {
    0 => None
    1 => Low
    2 => Medium
    3 => High
    4 => VeryHigh
    value => Unknown(value)
  }
}

///|
pub impl ToJson for VerificationLevel with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for VerificationLevel with fn from_json(json, path) {
  match json {
    Number(value, ..) => VerificationLevel::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected guild verification level (number)"),
      )
  }
}

///|
/// Discord's default message notification level.
pub(all) enum DefaultMessageNotifications {
  AllMessages
  OnlyMentions
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn DefaultMessageNotifications::to_int(
  self : DefaultMessageNotifications,
) -> Int {
  match self {
    AllMessages => 0
    OnlyMentions => 1
    Unknown(value) => value
  }
}

///|
pub fn DefaultMessageNotifications::from_int(
  value : Int,
) -> DefaultMessageNotifications {
  match value {
    0 => AllMessages
    1 => OnlyMentions
    value => Unknown(value)
  }
}

///|
pub impl ToJson for DefaultMessageNotifications with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for DefaultMessageNotifications with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => DefaultMessageNotifications::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected default message notification level (number)"),
      )
  }
}

///|
/// Discord's explicit content filter level.
pub(all) enum ExplicitContentFilter {
  Disabled
  MembersWithoutRoles
  AllMembers
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ExplicitContentFilter::to_int(self : ExplicitContentFilter) -> Int {
  match self {
    Disabled => 0
    MembersWithoutRoles => 1
    AllMembers => 2
    Unknown(value) => value
  }
}

///|
pub fn ExplicitContentFilter::from_int(value : Int) -> ExplicitContentFilter {
  match value {
    0 => Disabled
    1 => MembersWithoutRoles
    2 => AllMembers
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ExplicitContentFilter with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ExplicitContentFilter with fn from_json(json, path) {
  match json {
    Number(value, ..) => ExplicitContentFilter::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected explicit content filter level (number)"),
      )
  }
}

///|
/// Discord's guild MFA level.
pub(all) enum MfaLevel {
  None
  Elevated
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn MfaLevel::to_int(self : MfaLevel) -> Int {
  match self {
    None => 0
    Elevated => 1
    Unknown(value) => value
  }
}

///|
pub fn MfaLevel::from_int(value : Int) -> MfaLevel {
  match value {
    0 => None
    1 => Elevated
    value => Unknown(value)
  }
}

///|
pub impl ToJson for MfaLevel with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for MfaLevel with fn from_json(json, path) {
  match json {
    Number(value, ..) => MfaLevel::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected guild MFA level (number)"))
  }
}

///|
/// Discord's guild premium tier.
pub(all) enum PremiumTier {
  None
  Tier1
  Tier2
  Tier3
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn PremiumTier::to_int(self : PremiumTier) -> Int {
  match self {
    None => 0
    Tier1 => 1
    Tier2 => 2
    Tier3 => 3
    Unknown(value) => value
  }
}

///|
pub fn PremiumTier::from_int(value : Int) -> PremiumTier {
  match value {
    0 => None
    1 => Tier1
    2 => Tier2
    3 => Tier3
    value => Unknown(value)
  }
}

///|
pub impl ToJson for PremiumTier with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for PremiumTier with fn from_json(json, path) {
  match json {
    Number(value, ..) => PremiumTier::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected guild premium tier (number)"))
  }
}

///|
/// Discord's guild NSFW level.
pub(all) enum NsfwLevel {
  Default
  Explicit
  Safe
  AgeRestricted
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn NsfwLevel::to_int(self : NsfwLevel) -> Int {
  match self {
    Default => 0
    Explicit => 1
    Safe => 2
    AgeRestricted => 3
    Unknown(value) => value
  }
}

///|
pub fn NsfwLevel::from_int(value : Int) -> NsfwLevel {
  match value {
    0 => Default
    1 => Explicit
    2 => Safe
    3 => AgeRestricted
    value => Unknown(value)
  }
}

///|
pub impl ToJson for NsfwLevel with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for NsfwLevel with fn from_json(json, path) {
  match json {
    Number(value, ..) => NsfwLevel::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected guild NSFW level (number)"))
  }
}

///|
/// A capability enabled for a Discord guild.
pub(all) enum GuildFeature {
  AnimatedBanner
  AnimatedIcon
  ApplicationCommandPermissionsV2
  AutoModeration
  Banner
  Community
  CreatorMonetizableProvisional
  CreatorStorePage
  DeveloperSupportServer
  Discoverable
  Featurable
  HasDirectoryEntry
  Hub
  InvitesDisabled
  InviteSplash
  LinkedToHub
  MemberVerificationGateEnabled
  MoreSoundboard
  MonetizationEnabled
  MoreStickers
  News
  Partnered
  PreviewEnabled
  PrivateThreads
  RaidAlertsDisabled
  RelayEnabled
  RoleIcons
  RoleSubscriptionsAvailableForPurchase
  RoleSubscriptionsEnabled
  Soundboard
  TicketedEventsEnabled
  VanityUrl
  Verified
  VipRegions
  WelcomeScreenEnabled
  GuildTags
  EnhancedRoleColors
  GuestsEnabled
  PinPermissionMigrationComplete
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn GuildFeature::to_string(self : GuildFeature) -> String {
  match self {
    AnimatedBanner => "ANIMATED_BANNER"
    AnimatedIcon => "ANIMATED_ICON"
    ApplicationCommandPermissionsV2 => "APPLICATION_COMMAND_PERMISSIONS_V2"
    AutoModeration => "AUTO_MODERATION"
    Banner => "BANNER"
    Community => "COMMUNITY"
    CreatorMonetizableProvisional => "CREATOR_MONETIZABLE_PROVISIONAL"
    CreatorStorePage => "CREATOR_STORE_PAGE"
    DeveloperSupportServer => "DEVELOPER_SUPPORT_SERVER"
    Discoverable => "DISCOVERABLE"
    Featurable => "FEATURABLE"
    HasDirectoryEntry => "HAS_DIRECTORY_ENTRY"
    Hub => "HUB"
    InvitesDisabled => "INVITES_DISABLED"
    InviteSplash => "INVITE_SPLASH"
    LinkedToHub => "LINKED_TO_HUB"
    MemberVerificationGateEnabled => "MEMBER_VERIFICATION_GATE_ENABLED"
    MoreSoundboard => "MORE_SOUNDBOARD"
    MonetizationEnabled => "MONETIZATION_ENABLED"
    MoreStickers => "MORE_STICKERS"
    News => "NEWS"
    Partnered => "PARTNERED"
    PreviewEnabled => "PREVIEW_ENABLED"
    PrivateThreads => "PRIVATE_THREADS"
    RaidAlertsDisabled => "RAID_ALERTS_DISABLED"
    RelayEnabled => "RELAY_ENABLED"
    RoleIcons => "ROLE_ICONS"
    RoleSubscriptionsAvailableForPurchase =>
      "ROLE_SUBSCRIPTIONS_AVAILABLE_FOR_PURCHASE"
    RoleSubscriptionsEnabled => "ROLE_SUBSCRIPTIONS_ENABLED"
    Soundboard => "SOUNDBOARD"
    TicketedEventsEnabled => "TICKETED_EVENTS_ENABLED"
    VanityUrl => "VANITY_URL"
    Verified => "VERIFIED"
    VipRegions => "VIP_REGIONS"
    WelcomeScreenEnabled => "WELCOME_SCREEN_ENABLED"
    GuildTags => "GUILD_TAGS"
    EnhancedRoleColors => "ENHANCED_ROLE_COLORS"
    GuestsEnabled => "GUESTS_ENABLED"
    PinPermissionMigrationComplete => "PIN_PERMISSION_MIGRATION_COMPLETE"
    Unknown(value) => value
  }
}

///|
pub fn GuildFeature::from_string(value : String) -> GuildFeature {
  match value {
    "ANIMATED_BANNER" => AnimatedBanner
    "ANIMATED_ICON" => AnimatedIcon
    "APPLICATION_COMMAND_PERMISSIONS_V2" => ApplicationCommandPermissionsV2
    "AUTO_MODERATION" => AutoModeration
    "BANNER" => Banner
    "COMMUNITY" => Community
    "CREATOR_MONETIZABLE_PROVISIONAL" => CreatorMonetizableProvisional
    "CREATOR_STORE_PAGE" => CreatorStorePage
    "DEVELOPER_SUPPORT_SERVER" => DeveloperSupportServer
    "DISCOVERABLE" => Discoverable
    "FEATURABLE" => Featurable
    "HAS_DIRECTORY_ENTRY" => HasDirectoryEntry
    "HUB" => Hub
    "INVITES_DISABLED" => InvitesDisabled
    "INVITE_SPLASH" => InviteSplash
    "LINKED_TO_HUB" => LinkedToHub
    "MEMBER_VERIFICATION_GATE_ENABLED" => MemberVerificationGateEnabled
    "MORE_SOUNDBOARD" => MoreSoundboard
    "MONETIZATION_ENABLED" => MonetizationEnabled
    "MORE_STICKERS" => MoreStickers
    "NEWS" => News
    "PARTNERED" => Partnered
    "PREVIEW_ENABLED" => PreviewEnabled
    "PRIVATE_THREADS" => PrivateThreads
    "RAID_ALERTS_DISABLED" => RaidAlertsDisabled
    "RELAY_ENABLED" => RelayEnabled
    "ROLE_ICONS" => RoleIcons
    "ROLE_SUBSCRIPTIONS_AVAILABLE_FOR_PURCHASE" =>
      RoleSubscriptionsAvailableForPurchase
    "ROLE_SUBSCRIPTIONS_ENABLED" => RoleSubscriptionsEnabled
    "SOUNDBOARD" => Soundboard
    "TICKETED_EVENTS_ENABLED" => TicketedEventsEnabled
    "VANITY_URL" => VanityUrl
    "VERIFIED" => Verified
    "VIP_REGIONS" => VipRegions
    "WELCOME_SCREEN_ENABLED" => WelcomeScreenEnabled
    "GUILD_TAGS" => GuildTags
    "ENHANCED_ROLE_COLORS" => EnhancedRoleColors
    "GUESTS_ENABLED" => GuestsEnabled
    "PIN_PERMISSION_MIGRATION_COMPLETE" => PinPermissionMigrationComplete
    value => Unknown(value)
  }
}

///|
pub impl ToJson for GuildFeature with fn to_json(self) {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for GuildFeature with fn from_json(json, path) {
  match json {
    String(value) => GuildFeature::from_string(value.to_string())
    _ => raise JsonDecodeError((path, "expected guild feature (string)"))
  }
}

///|
/// Bit flags controlling messages sent to a guild system channel.
pub(all) struct SystemChannelFlags(UInt64) derive(Eq)

///|
pub fn SystemChannelFlags::none() -> SystemChannelFlags {
  SystemChannelFlags(0)
}

///|
pub fn SystemChannelFlags::from_bits(bits : UInt64) -> SystemChannelFlags {
  SystemChannelFlags(bits)
}

///|
pub fn SystemChannelFlags::bits(self : SystemChannelFlags) -> UInt64 {
  self.0
}

///|
pub fn SystemChannelFlags::contains(
  self : SystemChannelFlags,
  other : SystemChannelFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for SystemChannelFlags with fn lor(a, b) {
  SystemChannelFlags(a.0 | b.0)
}

///|
pub impl BitAnd for SystemChannelFlags with fn land(a, b) {
  SystemChannelFlags(a.0 & b.0)
}

///|
pub impl Debug for SystemChannelFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for SystemChannelFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for SystemChannelFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      SystemChannelFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected system channel flags (number), got \{repr}"),
            )
        },
      )
    Number(value, repr=None) => SystemChannelFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected system channel flags (number)"))
  }
}

///|
pub fn SystemChannelFlags::suppress_join_notifications() -> SystemChannelFlags {
  SystemChannelFlags(1UL << 0)
}

///|
pub fn SystemChannelFlags::suppress_premium_subscriptions() -> SystemChannelFlags {
  SystemChannelFlags(1UL << 1)
}

///|
pub fn SystemChannelFlags::suppress_guild_reminder_notifications() -> SystemChannelFlags {
  SystemChannelFlags(1UL << 2)
}

///|
pub fn SystemChannelFlags::suppress_join_notification_replies() -> SystemChannelFlags {
  SystemChannelFlags(1UL << 3)
}

///|
pub fn SystemChannelFlags::suppress_role_subscription_purchase_notifications() -> SystemChannelFlags {
  SystemChannelFlags(1UL << 4)
}

///|
pub fn SystemChannelFlags::suppress_role_subscription_purchase_notification_replies() -> SystemChannelFlags {
  SystemChannelFlags(1UL << 5)
}

///|
/// The welcome screen shown to new members of a community guild.
pub(all) struct WelcomeScreen {
  description : Nullable[String]
  welcome_channels : Array[WelcomeScreenChannel]
} derive(ToJson, FromJson, Debug)

///|
/// A channel suggested on a guild welcome screen.
pub(all) struct WelcomeScreenChannel {
  channel_id : ChannelId
  description : String
  emoji_id : Nullable[EmojiId]
  emoji_name : Nullable[String]
} derive(ToJson, FromJson, Debug)

///|
/// A guild that is temporarily unavailable to the client.
pub(all) struct UnavailableGuild {
  id : GuildId
  unavailable : Bool
} derive(ToJson, FromJson, Debug)

///|
/// A ban record pairing a user with an optional reason.
pub(all) struct GuildBan {
  reason : Nullable[String]
  user : User
} derive(ToJson, FromJson, Debug)
