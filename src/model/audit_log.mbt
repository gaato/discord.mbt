///|
/// A guild audit log with referenced domain objects.
pub(all) struct AuditLog {
  audit_log_entries : Array[AuditLogEntry]
  users : Array[User]
  webhooks : Array[Webhook]
  integrations : Array[Integration]
  application_commands : Array[ApplicationCommand]
  auto_moderation_rules : Array[AutoModerationRule]
  threads : Array[Channel]
  guild_scheduled_events : Array[GuildScheduledEvent]
} derive(ToJson, FromJson, Debug)

///|
/// One actor action recorded in a guild audit log.
pub(all) struct AuditLogEntry {
  target_id : Nullable[String]
  changes : Array[AuditLogChange]?
  user_id : Nullable[UserId]
  id : AuditLogEntryId
  action_type : AuditLogEvent
  options : Json?
  reason : String?
} derive(ToJson, FromJson, Debug)

///|
/// A raw before-and-after field change recorded in an audit entry.
pub(all) struct AuditLogChange {
  key : String
  new_value : Json?
  old_value : Json?
} derive(ToJson, FromJson, Debug)

///|
/// The action category recorded by a guild audit log.
pub(all) enum AuditLogEvent {
  GuildUpdate
  ChannelCreate
  ChannelUpdate
  ChannelDelete
  ChannelOverwriteCreate
  ChannelOverwriteUpdate
  ChannelOverwriteDelete
  MemberKick
  MemberPrune
  MemberBanAdd
  MemberBanRemove
  MemberUpdate
  MemberRoleUpdate
  MemberMove
  MemberDisconnect
  BotAdd
  RoleCreate
  RoleUpdate
  RoleDelete
  InviteCreate
  InviteUpdate
  InviteDelete
  WebhookCreate
  WebhookUpdate
  WebhookDelete
  EmojiCreate
  EmojiUpdate
  EmojiDelete
  MessageDelete
  MessageBulkDelete
  MessagePin
  MessageUnpin
  IntegrationCreate
  IntegrationUpdate
  IntegrationDelete
  StageInstanceCreate
  StageInstanceUpdate
  StageInstanceDelete
  StickerCreate
  StickerUpdate
  StickerDelete
  GuildScheduledEventCreate
  GuildScheduledEventUpdate
  GuildScheduledEventDelete
  ThreadCreate
  ThreadUpdate
  ThreadDelete
  ApplicationCommandPermissionUpdate
  SoundboardSoundCreate
  SoundboardSoundUpdate
  SoundboardSoundDelete
  AutoModerationRuleCreate
  AutoModerationRuleUpdate
  AutoModerationRuleDelete
  AutoModerationBlockMessage
  AutoModerationFlagToChannel
  AutoModerationUserCommunicationDisabled
  AutoModerationQuarantineUser
  CreatorMonetizationRequestCreated
  CreatorMonetizationTermsAccepted
  OnboardingPromptCreate
  OnboardingPromptUpdate
  OnboardingPromptDelete
  OnboardingCreate
  OnboardingUpdate
  HomeSettingsCreate
  HomeSettingsUpdate
  VoiceChannelStatusCreate
  VoiceChannelStatusDelete
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn AuditLogEvent::to_int(self : AuditLogEvent) -> Int {
  match self {
    GuildUpdate => 1
    ChannelCreate => 10
    ChannelUpdate => 11
    ChannelDelete => 12
    ChannelOverwriteCreate => 13
    ChannelOverwriteUpdate => 14
    ChannelOverwriteDelete => 15
    MemberKick => 20
    MemberPrune => 21
    MemberBanAdd => 22
    MemberBanRemove => 23
    MemberUpdate => 24
    MemberRoleUpdate => 25
    MemberMove => 26
    MemberDisconnect => 27
    BotAdd => 28
    RoleCreate => 30
    RoleUpdate => 31
    RoleDelete => 32
    InviteCreate => 40
    InviteUpdate => 41
    InviteDelete => 42
    WebhookCreate => 50
    WebhookUpdate => 51
    WebhookDelete => 52
    EmojiCreate => 60
    EmojiUpdate => 61
    EmojiDelete => 62
    MessageDelete => 72
    MessageBulkDelete => 73
    MessagePin => 74
    MessageUnpin => 75
    IntegrationCreate => 80
    IntegrationUpdate => 81
    IntegrationDelete => 82
    StageInstanceCreate => 83
    StageInstanceUpdate => 84
    StageInstanceDelete => 85
    StickerCreate => 90
    StickerUpdate => 91
    StickerDelete => 92
    GuildScheduledEventCreate => 100
    GuildScheduledEventUpdate => 101
    GuildScheduledEventDelete => 102
    ThreadCreate => 110
    ThreadUpdate => 111
    ThreadDelete => 112
    ApplicationCommandPermissionUpdate => 121
    SoundboardSoundCreate => 130
    SoundboardSoundUpdate => 131
    SoundboardSoundDelete => 132
    AutoModerationRuleCreate => 140
    AutoModerationRuleUpdate => 141
    AutoModerationRuleDelete => 142
    AutoModerationBlockMessage => 143
    AutoModerationFlagToChannel => 144
    AutoModerationUserCommunicationDisabled => 145
    AutoModerationQuarantineUser => 146
    CreatorMonetizationRequestCreated => 150
    CreatorMonetizationTermsAccepted => 151
    OnboardingPromptCreate => 163
    OnboardingPromptUpdate => 164
    OnboardingPromptDelete => 165
    OnboardingCreate => 166
    OnboardingUpdate => 167
    HomeSettingsCreate => 190
    HomeSettingsUpdate => 191
    VoiceChannelStatusCreate => 192
    VoiceChannelStatusDelete => 193
    Unknown(value) => value
  }
}

///|
pub fn AuditLogEvent::from_int(value : Int) -> AuditLogEvent {
  match value {
    1 => GuildUpdate
    10 => ChannelCreate
    11 => ChannelUpdate
    12 => ChannelDelete
    13 => ChannelOverwriteCreate
    14 => ChannelOverwriteUpdate
    15 => ChannelOverwriteDelete
    20 => MemberKick
    21 => MemberPrune
    22 => MemberBanAdd
    23 => MemberBanRemove
    24 => MemberUpdate
    25 => MemberRoleUpdate
    26 => MemberMove
    27 => MemberDisconnect
    28 => BotAdd
    30 => RoleCreate
    31 => RoleUpdate
    32 => RoleDelete
    40 => InviteCreate
    41 => InviteUpdate
    42 => InviteDelete
    50 => WebhookCreate
    51 => WebhookUpdate
    52 => WebhookDelete
    60 => EmojiCreate
    61 => EmojiUpdate
    62 => EmojiDelete
    72 => MessageDelete
    73 => MessageBulkDelete
    74 => MessagePin
    75 => MessageUnpin
    80 => IntegrationCreate
    81 => IntegrationUpdate
    82 => IntegrationDelete
    83 => StageInstanceCreate
    84 => StageInstanceUpdate
    85 => StageInstanceDelete
    90 => StickerCreate
    91 => StickerUpdate
    92 => StickerDelete
    100 => GuildScheduledEventCreate
    101 => GuildScheduledEventUpdate
    102 => GuildScheduledEventDelete
    110 => ThreadCreate
    111 => ThreadUpdate
    112 => ThreadDelete
    121 => ApplicationCommandPermissionUpdate
    130 => SoundboardSoundCreate
    131 => SoundboardSoundUpdate
    132 => SoundboardSoundDelete
    140 => AutoModerationRuleCreate
    141 => AutoModerationRuleUpdate
    142 => AutoModerationRuleDelete
    143 => AutoModerationBlockMessage
    144 => AutoModerationFlagToChannel
    145 => AutoModerationUserCommunicationDisabled
    146 => AutoModerationQuarantineUser
    150 => CreatorMonetizationRequestCreated
    151 => CreatorMonetizationTermsAccepted
    163 => OnboardingPromptCreate
    164 => OnboardingPromptUpdate
    165 => OnboardingPromptDelete
    166 => OnboardingCreate
    167 => OnboardingUpdate
    190 => HomeSettingsCreate
    191 => HomeSettingsUpdate
    192 => VoiceChannelStatusCreate
    193 => VoiceChannelStatusDelete
    value => Unknown(value)
  }
}

///|
pub impl ToJson for AuditLogEvent with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for AuditLogEvent with fn from_json(json, path) {
  match json {
    Number(value, ..) => AuditLogEvent::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (
          path, "expected the action category recorded by a guild audit log (number)",
        ),
      )
  }
}
