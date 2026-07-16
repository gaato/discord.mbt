///|
/// A flat channel model covering every Discord channel variant.
pub(all) struct Channel {
  id : ChannelId
  typ : ChannelType
  guild_id : GuildId?
  position : Int?
  permission_overwrites : Array[Overwrite]?
  name : Nullable[String]?
  topic : Nullable[String]?
  nsfw : Bool?
  last_message_id : Nullable[MessageId]?
  bitrate : Int?
  user_limit : Int?
  rate_limit_per_user : Int?
  recipients : Array[User]?
  icon : Nullable[ImageHash]?
  owner_id : UserId?
  application_id : ApplicationId?
  managed : Bool?
  parent_id : Nullable[ChannelId]?
  last_pin_timestamp : Nullable[Timestamp]?
  rtc_region : Nullable[String]?
  video_quality_mode : VideoQualityMode?
  message_count : Int?
  member_count : Int?
  thread_metadata : ThreadMetadata?
  thread_member : ThreadMember?
  default_auto_archive_duration : ThreadAutoArchiveDuration?
  permissions : Permissions?
  flags : ChannelFlags?
  total_message_sent : Int?
  available_tags : Array[ForumTag]?
  applied_tags : Array[GenericId]?
  default_reaction_emoji : Nullable[DefaultReaction]?
  default_thread_rate_limit_per_user : Int?
  default_sort_order : Nullable[SortOrderType]?
  default_forum_layout : ForumLayoutType?
} derive (
  ToJson(fields(typ(rename="type"), thread_member(rename="member"))),
  FromJson(fields(typ(rename="type"), thread_member(rename="member"))),
  Debug,
)

///|
/// A role or member permission override on a channel.
pub(all) struct Overwrite {
  id : GenericId
  typ : OverwriteType
  allow : Permissions
  deny : Permissions
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The target category of a permission overwrite.
pub(all) enum OverwriteType {
  Role
  Member
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn OverwriteType::to_int(self : OverwriteType) -> Int {
  match self {
    Role => 0
    Member => 1
    Unknown(value) => value
  }
}

///|
pub fn OverwriteType::from_int(value : Int) -> OverwriteType {
  match value {
    0 => Role
    1 => Member
    value => Unknown(value)
  }
}

///|
pub impl ToJson for OverwriteType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for OverwriteType with fn from_json(json, path) {
  match json {
    Number(value, ..) => OverwriteType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected an overwrite type (number)"))
  }
}

///|
/// The camera quality mode used by a voice channel.
pub(all) enum VideoQualityMode {
  Auto
  Full
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn VideoQualityMode::to_int(self : VideoQualityMode) -> Int {
  match self {
    Auto => 1
    Full => 2
    Unknown(value) => value
  }
}

///|
pub fn VideoQualityMode::from_int(value : Int) -> VideoQualityMode {
  match value {
    1 => Auto
    2 => Full
    value => Unknown(value)
  }
}

///|
pub impl ToJson for VideoQualityMode with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for VideoQualityMode with fn from_json(json, path) {
  match json {
    Number(value, ..) => VideoQualityMode::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a video quality mode (number)"))
  }
}

///|
/// The ordering used for posts in a forum or media channel.
pub(all) enum SortOrderType {
  LatestActivity
  CreationDate
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn SortOrderType::to_int(self : SortOrderType) -> Int {
  match self {
    LatestActivity => 0
    CreationDate => 1
    Unknown(value) => value
  }
}

///|
pub fn SortOrderType::from_int(value : Int) -> SortOrderType {
  match value {
    0 => LatestActivity
    1 => CreationDate
    value => Unknown(value)
  }
}

///|
pub impl ToJson for SortOrderType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for SortOrderType with fn from_json(json, path) {
  match json {
    Number(value, ..) => SortOrderType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a sort order type (number)"))
  }
}

///|
/// The presentation layout used by a forum channel.
pub(all) enum ForumLayoutType {
  NotSet
  ListView
  GalleryView
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ForumLayoutType::to_int(self : ForumLayoutType) -> Int {
  match self {
    NotSet => 0
    ListView => 1
    GalleryView => 2
    Unknown(value) => value
  }
}

///|
pub fn ForumLayoutType::from_int(value : Int) -> ForumLayoutType {
  match value {
    0 => NotSet
    1 => ListView
    2 => GalleryView
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ForumLayoutType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ForumLayoutType with fn from_json(json, path) {
  match json {
    Number(value, ..) => ForumLayoutType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a forum layout type (number)"))
  }
}

///|
/// The inactivity duration in minutes before a thread is archived.
pub(all) enum ThreadAutoArchiveDuration {
  OneHour
  OneDay
  ThreeDays
  OneWeek
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ThreadAutoArchiveDuration::to_int(
  self : ThreadAutoArchiveDuration,
) -> Int {
  match self {
    OneHour => 60
    OneDay => 1440
    ThreeDays => 4320
    OneWeek => 10080
    Unknown(value) => value
  }
}

///|
pub fn ThreadAutoArchiveDuration::from_int(
  value : Int,
) -> ThreadAutoArchiveDuration {
  match value {
    60 => OneHour
    1440 => OneDay
    4320 => ThreeDays
    10080 => OneWeek
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ThreadAutoArchiveDuration with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ThreadAutoArchiveDuration with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => ThreadAutoArchiveDuration::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected a thread auto-archive duration (number)"),
      )
  }
}

///|
/// Metadata controlling a thread's archive and lock state.
pub(all) struct ThreadMetadata {
  archived : Bool
  auto_archive_duration : ThreadAutoArchiveDuration
  archive_timestamp : Timestamp
  locked : Bool
  invitable : Bool?
  create_timestamp : Timestamp?
} derive(ToJson, FromJson, Debug)

///|
/// A user's membership state in a thread.
pub(all) struct ThreadMember {
  id : ChannelId?
  user_id : UserId?
  join_timestamp : Timestamp
  flags : Int
  guild_member : GuildMember?
} derive (
  ToJson(fields(guild_member(rename="member"))),
  FromJson(fields(guild_member(rename="member"))),
  Debug,
)

///|
/// Archived thread channels and their membership records.
pub(all) struct ArchivedThreads {
  threads : Array[Channel]
  members : Array[ThreadMember]
  has_more : Bool
} derive(ToJson, FromJson, Debug)

///|
/// Active thread channels in a guild and their membership records.
pub(all) struct ActiveGuildThreads {
  threads : Array[Channel]
  members : Array[ThreadMember]
} derive(ToJson, FromJson, Debug)

///|
/// A tag available for categorizing threads in a forum or media channel.
pub(all) struct ForumTag {
  id : GenericId
  name : String
  moderated : Bool
  emoji_id : Nullable[EmojiId]
  emoji_name : Nullable[String]
} derive(ToJson, FromJson, Debug)

///|
/// The default custom or Unicode reaction for a forum or media channel.
pub(all) struct DefaultReaction {
  emoji_id : Nullable[EmojiId]
  emoji_name : Nullable[String]
} derive(ToJson, FromJson, Debug)

///|
/// Bit flags describing special behavior assigned to a channel.
pub(all) struct ChannelFlags(UInt64) derive(Eq)

///|
pub fn ChannelFlags::none() -> ChannelFlags {
  ChannelFlags(0)
}

///|
pub fn ChannelFlags::from_bits(bits : UInt64) -> ChannelFlags {
  ChannelFlags(bits)
}

///|
pub fn ChannelFlags::bits(self : ChannelFlags) -> UInt64 {
  self.0
}

///|
pub fn ChannelFlags::contains(
  self : ChannelFlags,
  other : ChannelFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for ChannelFlags with fn lor(a, b) {
  ChannelFlags(a.0 | b.0)
}

///|
pub impl BitAnd for ChannelFlags with fn land(a, b) {
  ChannelFlags(a.0 & b.0)
}

///|
pub impl Debug for ChannelFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for ChannelFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for ChannelFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      ChannelFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected channel flags (number), got \{repr}"),
            )
        },
      )
    Number(value, repr=None) => ChannelFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected channel flags (number)"))
  }
}

///|
pub fn ChannelFlags::guild_feed_removed() -> ChannelFlags {
  ChannelFlags(1UL << 0)
}

///|
pub fn ChannelFlags::pinned() -> ChannelFlags {
  ChannelFlags(1UL << 1)
}

///|
pub fn ChannelFlags::active_channels_removed() -> ChannelFlags {
  ChannelFlags(1UL << 2)
}

///|
pub fn ChannelFlags::require_tag() -> ChannelFlags {
  ChannelFlags(1UL << 4)
}

///|
pub fn ChannelFlags::is_spam() -> ChannelFlags {
  ChannelFlags(1UL << 5)
}

///|
pub fn ChannelFlags::is_guild_resource_channel() -> ChannelFlags {
  ChannelFlags(1UL << 7)
}

///|
pub fn ChannelFlags::clyde_ai() -> ChannelFlags {
  ChannelFlags(1UL << 8)
}

///|
pub fn ChannelFlags::is_scheduled_for_deletion() -> ChannelFlags {
  ChannelFlags(1UL << 9)
}

///|
pub fn ChannelFlags::hide_media_download_options() -> ChannelFlags {
  ChannelFlags(1UL << 15)
}
