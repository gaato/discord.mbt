///|
/// A message sent to a Discord channel.
pub(all) struct Message {
  id : MessageId
  channel_id : ChannelId
  author : User
  content : String
  timestamp : Timestamp
  edited_timestamp : Nullable[Timestamp]
  tts : Bool
  mention_everyone : Bool
  mentions : Array[User]
  mention_roles : Array[RoleId]
  mention_channels : Array[ChannelMention]?
  attachments : Array[Attachment]
  embeds : Array[Embed]
  reactions : Array[Reaction]?
  nonce : Nonce?
  pinned : Bool
  webhook_id : WebhookId?
  typ : MessageType
  activity : MessageActivity?
  application_id : ApplicationId?
  message_reference : MessageReference?
  flags : MessageFlags?
  referenced_message : Nullable[Message]?
  thread : Channel?
  components : Array[Component]?
  sticker_items : Array[StickerItem]?
  position : Int?
  role_subscription_data : RoleSubscriptionData?
  call : MessageCall?
  // TODO(application): Add the partial application payload with its domain.
  // TODO(interaction): Add interaction and interaction_metadata later.
  // TODO(poll): Add poll payloads with the poll domain.
  // TODO(resolved): Add resolved interaction data with the interaction domain.
  // TODO(message_snapshots): Add forwarded message snapshots later.
  // TODO(soundboard_sounds): Add message soundboard payloads later.
  // TODO(deprecated-stickers): Add only if the deprecated full sticker field is needed.
  // TODO(shared-client-theme): Add the newer shared client theme payload later.
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// A client nonce represented as either its string or integer wire form.
pub(all) enum Nonce {
  Str(String)
  Num(Int64)
} derive(Eq, Debug)

///|
pub impl ToJson for Nonce with fn to_json(self) {
  match self {
    Str(value) => Json::string(value)
    Num(value) => Json::number(value.to_double(), repr=value.to_string())
  }
}

///|
pub impl @json.FromJson for Nonce with fn from_json(json, path) {
  match json {
    String(value) => Str(value)
    Number(_, repr=Some(repr)) =>
      Num(
        @string.parse_int64(repr.to_string()) catch {
          _ =>
            raise @json.JsonDecodeError(
              (path, "expected a message nonce (integer), got \{repr}"),
            )
        },
      )
    Number(value, repr=None) => Num(value.to_int64())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected a message nonce (string or integer)"),
      )
  }
}

///|
/// A channel referenced directly in message content.
pub(all) struct ChannelMention {
  id : ChannelId
  guild_id : GuildId
  typ : ChannelType
  name : String
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// Aggregate reaction state for one emoji on a message.
pub(all) struct Reaction {
  count : Int
  count_details : ReactionCountDetails
  me : Bool
  me_burst : Bool
  emoji : Emoji
  burst_colors : Array[String]
} derive(ToJson, FromJson, Debug)

///|
/// Normal and burst reaction counts for a reaction.
pub(all) struct ReactionCountDetails {
  burst : Int
  normal : Int
} derive(ToJson, FromJson, Debug)

///|
/// Rich Presence activity metadata attached to a message.
pub(all) struct MessageActivity {
  typ : MessageActivityType
  party_id : String?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// Origin identifiers and delivery behavior for a message reference.
pub(all) struct MessageReference {
  typ : MessageReferenceType?
  message_id : MessageId?
  channel_id : ChannelId?
  guild_id : GuildId?
  fail_if_not_exists : Bool?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// Participant and end-time data for a call message.
pub(all) struct MessageCall {
  participants : Array[UserId]
  ended_timestamp : Nullable[Timestamp]?
} derive(ToJson, FromJson, Debug)

///|
/// Subscription tier data attached to a role purchase message.
pub(all) struct RoleSubscriptionData {
  role_subscription_listing_id : SkuId
  tier_name : String
  total_months_subscribed : Int
  is_renewal : Bool
} derive(ToJson, FromJson, Debug)

///|
/// The system or user event category represented by a message.
pub(all) enum MessageType {
  Default
  RecipientAdd
  RecipientRemove
  Call
  ChannelNameChange
  ChannelIconChange
  ChannelPinnedMessage
  UserJoin
  GuildBoost
  GuildBoostTier1
  GuildBoostTier2
  GuildBoostTier3
  ChannelFollowAdd
  GuildDiscoveryDisqualified
  GuildDiscoveryRequalified
  GuildDiscoveryGracePeriodInitialWarning
  GuildDiscoveryGracePeriodFinalWarning
  ThreadCreated
  Reply
  ChatInputCommand
  ThreadStarterMessage
  GuildInviteReminder
  ContextMenuCommand
  AutoModerationAction
  RoleSubscriptionPurchase
  InteractionPremiumUpsell
  StageStart
  StageEnd
  StageSpeaker
  StageRaiseHand
  StageTopic
  GuildApplicationPremiumSubscription
  GuildIncidentAlertModeEnabled
  GuildIncidentAlertModeDisabled
  GuildIncidentReportRaid
  GuildIncidentReportFalseAlarm
  PurchaseNotification
  PollResult
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn MessageType::to_int(self : MessageType) -> Int {
  match self {
    Default => 0
    RecipientAdd => 1
    RecipientRemove => 2
    Call => 3
    ChannelNameChange => 4
    ChannelIconChange => 5
    ChannelPinnedMessage => 6
    UserJoin => 7
    GuildBoost => 8
    GuildBoostTier1 => 9
    GuildBoostTier2 => 10
    GuildBoostTier3 => 11
    ChannelFollowAdd => 12
    GuildDiscoveryDisqualified => 14
    GuildDiscoveryRequalified => 15
    GuildDiscoveryGracePeriodInitialWarning => 16
    GuildDiscoveryGracePeriodFinalWarning => 17
    ThreadCreated => 18
    Reply => 19
    ChatInputCommand => 20
    ThreadStarterMessage => 21
    GuildInviteReminder => 22
    ContextMenuCommand => 23
    AutoModerationAction => 24
    RoleSubscriptionPurchase => 25
    InteractionPremiumUpsell => 26
    StageStart => 27
    StageEnd => 28
    StageSpeaker => 29
    StageRaiseHand => 30
    StageTopic => 31
    GuildApplicationPremiumSubscription => 32
    GuildIncidentAlertModeEnabled => 36
    GuildIncidentAlertModeDisabled => 37
    GuildIncidentReportRaid => 38
    GuildIncidentReportFalseAlarm => 39
    PurchaseNotification => 44
    PollResult => 46
    Unknown(value) => value
  }
}

///|
pub fn MessageType::from_int(value : Int) -> MessageType {
  match value {
    0 => Default
    1 => RecipientAdd
    2 => RecipientRemove
    3 => Call
    4 => ChannelNameChange
    5 => ChannelIconChange
    6 => ChannelPinnedMessage
    7 => UserJoin
    8 => GuildBoost
    9 => GuildBoostTier1
    10 => GuildBoostTier2
    11 => GuildBoostTier3
    12 => ChannelFollowAdd
    14 => GuildDiscoveryDisqualified
    15 => GuildDiscoveryRequalified
    16 => GuildDiscoveryGracePeriodInitialWarning
    17 => GuildDiscoveryGracePeriodFinalWarning
    18 => ThreadCreated
    19 => Reply
    20 => ChatInputCommand
    21 => ThreadStarterMessage
    22 => GuildInviteReminder
    23 => ContextMenuCommand
    24 => AutoModerationAction
    25 => RoleSubscriptionPurchase
    26 => InteractionPremiumUpsell
    27 => StageStart
    28 => StageEnd
    29 => StageSpeaker
    30 => StageRaiseHand
    31 => StageTopic
    32 => GuildApplicationPremiumSubscription
    36 => GuildIncidentAlertModeEnabled
    37 => GuildIncidentAlertModeDisabled
    38 => GuildIncidentReportRaid
    39 => GuildIncidentReportFalseAlarm
    44 => PurchaseNotification
    46 => PollResult
    value => Unknown(value)
  }
}

///|
pub impl ToJson for MessageType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for MessageType with fn from_json(json, path) {
  match json {
    Number(value, ..) => MessageType::from_int(value.to_int())
    _ => raise @json.JsonDecodeError((path, "expected a message type (number)"))
  }
}

///|
/// The Rich Presence action represented by a message activity.
pub(all) enum MessageActivityType {
  Join
  Spectate
  Listen
  JoinRequest
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn MessageActivityType::to_int(self : MessageActivityType) -> Int {
  match self {
    Join => 1
    Spectate => 2
    Listen => 3
    JoinRequest => 5
    Unknown(value) => value
  }
}

///|
pub fn MessageActivityType::from_int(value : Int) -> MessageActivityType {
  match value {
    1 => Join
    2 => Spectate
    3 => Listen
    5 => JoinRequest
    value => Unknown(value)
  }
}

///|
pub impl ToJson for MessageActivityType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for MessageActivityType with fn from_json(json, path) {
  match json {
    Number(value, ..) => MessageActivityType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected a message activity (number)"),
      )
  }
}

///|
/// The reference mode used for a reply or forwarded message.
pub(all) enum MessageReferenceType {
  Default
  Forward
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn MessageReferenceType::to_int(self : MessageReferenceType) -> Int {
  match self {
    Default => 0
    Forward => 1
    Unknown(value) => value
  }
}

///|
pub fn MessageReferenceType::from_int(value : Int) -> MessageReferenceType {
  match value {
    0 => Default
    1 => Forward
    value => Unknown(value)
  }
}

///|
pub impl ToJson for MessageReferenceType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for MessageReferenceType with fn from_json(json, path) {
  match json {
    Number(value, ..) => MessageReferenceType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected a message reference (number)"),
      )
  }
}

///|
/// Bit flags describing delivery and presentation behavior of a message.
pub(all) struct MessageFlags(UInt64) derive(Eq)

///|
pub fn MessageFlags::none() -> MessageFlags {
  MessageFlags(0)
}

///|
pub fn MessageFlags::from_bits(bits : UInt64) -> MessageFlags {
  MessageFlags(bits)
}

///|
pub fn MessageFlags::bits(self : MessageFlags) -> UInt64 {
  self.0
}

///|
pub fn MessageFlags::contains(
  self : MessageFlags,
  other : MessageFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for MessageFlags with fn lor(a, b) {
  MessageFlags(a.0 | b.0)
}

///|
pub impl BitAnd for MessageFlags with fn land(a, b) {
  MessageFlags(a.0 & b.0)
}

///|
pub impl Debug for MessageFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for MessageFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for MessageFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      MessageFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise @json.JsonDecodeError(
              (path, "expected message flags (number), got \{repr}"),
            )
        },
      )
    Number(value, repr=None) => MessageFlags(value.to_uint64())
    _ => raise @json.JsonDecodeError((path, "expected message flags (number)"))
  }
}

///|
pub fn MessageFlags::crossposted() -> MessageFlags {
  MessageFlags(1UL << 0)
}

///|
pub fn MessageFlags::is_crosspost() -> MessageFlags {
  MessageFlags(1UL << 1)
}

///|
pub fn MessageFlags::suppress_embeds() -> MessageFlags {
  MessageFlags(1UL << 2)
}

///|
pub fn MessageFlags::source_message_deleted() -> MessageFlags {
  MessageFlags(1UL << 3)
}

///|
pub fn MessageFlags::urgent() -> MessageFlags {
  MessageFlags(1UL << 4)
}

///|
pub fn MessageFlags::has_thread() -> MessageFlags {
  MessageFlags(1UL << 5)
}

///|
pub fn MessageFlags::ephemeral() -> MessageFlags {
  MessageFlags(1UL << 6)
}

///|
pub fn MessageFlags::loading() -> MessageFlags {
  MessageFlags(1UL << 7)
}

///|
pub fn MessageFlags::failed_to_mention_some_roles_in_thread() -> MessageFlags {
  MessageFlags(1UL << 8)
}

///|
pub fn MessageFlags::should_show_link_not_discord_warning() -> MessageFlags {
  MessageFlags(1UL << 10)
}

///|
pub fn MessageFlags::suppress_notifications() -> MessageFlags {
  MessageFlags(1UL << 12)
}

///|
pub fn MessageFlags::is_voice_message() -> MessageFlags {
  MessageFlags(1UL << 13)
}

///|
pub fn MessageFlags::has_snapshot() -> MessageFlags {
  MessageFlags(1UL << 14)
}

///|
pub fn MessageFlags::is_components_v2() -> MessageFlags {
  MessageFlags(1UL << 15)
}
