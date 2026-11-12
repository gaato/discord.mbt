///|
/// A flat channel model covering every Discord channel variant.
///
/// A guild channel the bot cannot view arrives over the gateway obfuscated
/// (`Channel::is_obfuscated`): only `id`, `typ`, `position` and `parent_id`
/// are reliable, and Discord nulls or reduces the rest.
#derive(ToJson(fields(typ(rename="type"), thread_member(rename="member"))), Debug)
pub(all) struct Channel {
  id : ChannelId
  typ : ChannelType
  guild_id : GuildId?
  position : Int32?
  permission_overwrites : Array[Overwrite]?
  name : Nullable[String]?
  topic : Nullable[String]?
  nsfw : Bool?
  last_message_id : Nullable[MessageId]?
  bitrate : Int32?
  user_limit : Int32?
  rate_limit_per_user : Int32?
  recipients : Array[User]?
  icon : Nullable[ImageHash]?
  owner_id : UserId?
  application_id : Nullable[ApplicationId]?
  managed : Bool?
  parent_id : Nullable[ChannelId]?
  last_pin_timestamp : Nullable[Timestamp]?
  rtc_region : Nullable[String]?
  video_quality_mode : VideoQualityMode?
  message_count : Int32?
  member_count : Int32?
  thread_metadata : ThreadMetadata?
  thread_member : ThreadMember?
  default_auto_archive_duration : ThreadAutoArchiveDuration?
  permissions : Permissions?
  app_permissions : Permissions?
  flags : ChannelFlags?
  total_message_sent : Int32?
  available_tags : Array[ForumTag]?
  applied_tags : Array[GenericId]?
  default_reaction_emoji : Nullable[DefaultReaction]?
  default_thread_rate_limit_per_user : Int32?
  default_sort_order : Nullable[SortOrderType]?
  default_forum_layout : ForumLayoutType?
}

///|
/// Decodes a channel from its Discord JSON representation.
///
/// Every field is checked against its type, so a malformed channel fails.
/// The exception is a channel whose `flags` carry `CHANNEL_OBFUSCATED`:
/// Discord guarantees only `id`, `type`, `position` and `parent_id` there and
/// nulls or reduces the rest, so those four and `flags` stay strict while any
/// other field that is null or does not decode becomes `None`. One hidden
/// channel then cannot fail the `GUILD_CREATE` that lists it.
pub impl @json.FromJson for Channel with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected channel (object)"))
  }
  let flags : ChannelFlags? = channel_field(
    fields,
    "flags",
    path,
    lenient=false,
  )
  let lenient = flags is Some(flags) &&
    flags.contains(ChannelFlags::channel_obfuscated())
  {
    id: event_field(fields, "id", path),
    typ: event_field(fields, "type", path),
    guild_id: channel_field(fields, "guild_id", path, lenient~),
    position: channel_field(fields, "position", path, lenient=false),
    permission_overwrites: channel_field(
      fields,
      "permission_overwrites",
      path,
      lenient~,
    ),
    name: channel_field(fields, "name", path, lenient~),
    topic: channel_field(fields, "topic", path, lenient~),
    nsfw: channel_field(fields, "nsfw", path, lenient~),
    last_message_id: channel_field(fields, "last_message_id", path, lenient~),
    bitrate: channel_field(fields, "bitrate", path, lenient~),
    user_limit: channel_field(fields, "user_limit", path, lenient~),
    rate_limit_per_user: channel_field(
      fields,
      "rate_limit_per_user",
      path,
      lenient~,
    ),
    recipients: channel_field(fields, "recipients", path, lenient~),
    icon: channel_field(fields, "icon", path, lenient~),
    owner_id: channel_field(fields, "owner_id", path, lenient~),
    application_id: channel_field(fields, "application_id", path, lenient~),
    managed: channel_field(fields, "managed", path, lenient~),
    parent_id: channel_field(fields, "parent_id", path, lenient=false),
    last_pin_timestamp: channel_field(
      fields,
      "last_pin_timestamp",
      path,
      lenient~,
    ),
    rtc_region: channel_field(fields, "rtc_region", path, lenient~),
    video_quality_mode: channel_field(
      fields,
      "video_quality_mode",
      path,
      lenient~,
    ),
    message_count: channel_field(fields, "message_count", path, lenient~),
    member_count: channel_field(fields, "member_count", path, lenient~),
    thread_metadata: channel_field(fields, "thread_metadata", path, lenient~),
    thread_member: channel_field(fields, "member", path, lenient~),
    default_auto_archive_duration: channel_field(
      fields,
      "default_auto_archive_duration",
      path,
      lenient~,
    ),
    permissions: channel_field(fields, "permissions", path, lenient~),
    app_permissions: channel_field(fields, "app_permissions", path, lenient~),
    flags,
    total_message_sent: channel_field(
      fields,
      "total_message_sent",
      path,
      lenient~,
    ),
    available_tags: channel_field(fields, "available_tags", path, lenient~),
    applied_tags: channel_field(fields, "applied_tags", path, lenient~),
    default_reaction_emoji: channel_field(
      fields,
      "default_reaction_emoji",
      path,
      lenient~,
    ),
    default_thread_rate_limit_per_user: channel_field(
      fields,
      "default_thread_rate_limit_per_user",
      path,
      lenient~,
    ),
    default_sort_order: channel_field(
      fields,
      "default_sort_order",
      path,
      lenient~,
    ),
    default_forum_layout: channel_field(
      fields,
      "default_forum_layout",
      path,
      lenient~,
    ),
  }
}

///|
/// An optional channel field: absent is `None`; otherwise it must decode,
/// unless `lenient`, where a value that does not decode (including a null
/// for a non-nullable field) is `None` as well.
fn[T : @json.FromJson] channel_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
  lenient~ : Bool,
) -> T? raise @json.JsonDecodeError {
  match fields.get(key) {
    None => None
    Some(value) if lenient =>
      Some(@json.from_json(value, path=path.add_key(key))) catch {
        _ => None
      }
    Some(value) => Some(@json.from_json(value, path=path.add_key(key)))
  }
}

///|
/// A role or member permission override on a channel.
#derive(ToJson(fields(typ(rename="type"))), FromJson(fields(typ(rename="type"))), Debug)
pub(all) struct Overwrite {
  id : GenericId
  typ : OverwriteType
  allow : Permissions
  deny : Permissions
}

///|
/// The target category of a permission overwrite.
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum OverwriteType {
  Role
  Member
  Unknown(Int32)
}

///|
/// The Discord integer value of this `OverwriteType`.
pub fn OverwriteType::to_int(self : OverwriteType) -> Int32 {
  match self {
    Role => 0
    Member => 1
    Unknown(value) => value
  }
}

///|
/// The `OverwriteType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn OverwriteType::from_int(value : Int32) -> OverwriteType {
  match value {
    0 => Role
    1 => Member
    value => Unknown(value)
  }
}

///|
/// Encodes the `OverwriteType` as its Discord integer value.
pub impl ToJson for OverwriteType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `OverwriteType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for OverwriteType with fn from_json(json, path) {
  match json {
    Number(value, ..) => OverwriteType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected an overwrite type (number)"))
  }
}

///|
/// The camera quality mode used by a voice channel.
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum VideoQualityMode {
  Auto
  Full
  Unknown(Int32)
}

///|
/// The Discord integer value of this `VideoQualityMode`.
pub fn VideoQualityMode::to_int(self : VideoQualityMode) -> Int32 {
  match self {
    Auto => 1
    Full => 2
    Unknown(value) => value
  }
}

///|
/// The `VideoQualityMode` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn VideoQualityMode::from_int(value : Int32) -> VideoQualityMode {
  match value {
    1 => Auto
    2 => Full
    value => Unknown(value)
  }
}

///|
/// Encodes the `VideoQualityMode` as its Discord integer value.
pub impl ToJson for VideoQualityMode with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `VideoQualityMode` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for VideoQualityMode with fn from_json(json, path) {
  match json {
    Number(value, ..) => VideoQualityMode::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a video quality mode (number)"))
  }
}

///|
/// The ordering used for posts in a forum or media channel.
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum SortOrderType {
  LatestActivity
  CreationDate
  Unknown(Int32)
}

///|
/// The Discord integer value of this `SortOrderType`.
pub fn SortOrderType::to_int(self : SortOrderType) -> Int32 {
  match self {
    LatestActivity => 0
    CreationDate => 1
    Unknown(value) => value
  }
}

///|
/// The `SortOrderType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn SortOrderType::from_int(value : Int32) -> SortOrderType {
  match value {
    0 => LatestActivity
    1 => CreationDate
    value => Unknown(value)
  }
}

///|
/// Encodes the `SortOrderType` as its Discord integer value.
pub impl ToJson for SortOrderType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `SortOrderType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for SortOrderType with fn from_json(json, path) {
  match json {
    Number(value, ..) => SortOrderType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a sort order type (number)"))
  }
}

///|
/// The presentation layout used by a forum channel.
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum ForumLayoutType {
  NotSet
  ListView
  GalleryView
  Unknown(Int32)
}

///|
/// The Discord integer value of this `ForumLayoutType`.
pub fn ForumLayoutType::to_int(self : ForumLayoutType) -> Int32 {
  match self {
    NotSet => 0
    ListView => 1
    GalleryView => 2
    Unknown(value) => value
  }
}

///|
/// The `ForumLayoutType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn ForumLayoutType::from_int(value : Int32) -> ForumLayoutType {
  match value {
    0 => NotSet
    1 => ListView
    2 => GalleryView
    value => Unknown(value)
  }
}

///|
/// Encodes the `ForumLayoutType` as its Discord integer value.
pub impl ToJson for ForumLayoutType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `ForumLayoutType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for ForumLayoutType with fn from_json(json, path) {
  match json {
    Number(value, ..) => ForumLayoutType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a forum layout type (number)"))
  }
}

///|
/// The inactivity duration in minutes before a thread is archived.
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum ThreadAutoArchiveDuration {
  OneHour
  OneDay
  ThreeDays
  OneWeek
  Unknown(Int32)
}

///|
/// The Discord integer value of this `ThreadAutoArchiveDuration`, in minutes.
pub fn ThreadAutoArchiveDuration::to_int(
  self : ThreadAutoArchiveDuration,
) -> Int32 {
  match self {
    OneHour => 60
    OneDay => 1440
    ThreeDays => 4320
    OneWeek => 10080
    Unknown(value) => value
  }
}

///|
/// The `ThreadAutoArchiveDuration` for its Discord integer value (minutes); unknown values become `Unknown(n)`.
pub fn ThreadAutoArchiveDuration::from_int(
  value : Int32,
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
/// Encodes the `ThreadAutoArchiveDuration` as its Discord integer value.
pub impl ToJson for ThreadAutoArchiveDuration with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `ThreadAutoArchiveDuration` from a JSON number; unknown values become `Unknown(n)`.
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
#derive(ToJson, FromJson, Debug)
pub(all) struct ThreadMetadata {
  archived : Bool
  auto_archive_duration : ThreadAutoArchiveDuration
  archive_timestamp : Timestamp
  locked : Bool
  invitable : Bool?
  create_timestamp : Nullable[Timestamp]?
}

///|
/// A user's membership state in a thread.
#derive(ToJson(fields(guild_member(rename="member"))), FromJson(fields(guild_member(rename="member"))), Debug)
pub(all) struct ThreadMember {
  id : ChannelId?
  user_id : UserId?
  join_timestamp : Timestamp
  flags : Int32
  guild_member : GuildMember?
}

///|
/// Archived thread channels and their membership records.
#derive(ToJson, FromJson, Debug)
pub(all) struct ArchivedThreads {
  threads : Array[Channel]
  members : Array[ThreadMember]
  has_more : Bool
}

///|
/// Active thread channels in a guild and their membership records.
#derive(ToJson, FromJson, Debug)
pub(all) struct ActiveGuildThreads {
  threads : Array[Channel]
  members : Array[ThreadMember]
}

///|
/// The announcement channel and webhook created by following a channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct FollowedChannel {
  channel_id : ChannelId
  webhook_id : WebhookId
}

///|
/// A tag available for categorizing threads in a forum or media channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct ForumTag {
  id : GenericId
  name : String
  moderated : Bool
  emoji_id : Nullable[EmojiId]
  emoji_name : Nullable[String]
}

///|
/// A forum tag as sent in `available_tags` when creating or modifying a
/// forum or media channel. Only `name` is required; omit `id` to create a
/// new tag, keep an existing tag's `id` to update it in place. At most one
/// of `emoji_id` and `emoji_name` may be set.
#derive(Debug)
pub(all) struct ForumTagRequest {
  id : GenericId?
  name : String
  moderated : Bool?
  emoji_id : EmojiId?
  emoji_name : String?
}

///|
/// Encodes the forum tag request as its Discord JSON representation.
pub impl ToJson for ForumTagRequest with fn to_json(self) {
  @sdkjson.ObjBuilder::new()
  .opt("id", self.id)
  .field("name", self.name)
  .opt("moderated", self.moderated)
  .opt("emoji_id", self.emoji_id)
  .opt("emoji_name", self.emoji_name)
  .build()
}

///|
/// The default custom or Unicode reaction for a forum or media channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct DefaultReaction {
  emoji_id : Nullable[EmojiId]
  emoji_name : Nullable[String]
}

///|
/// Bit flags describing special behavior assigned to a channel.
#derive(Eq)
pub(all) struct ChannelFlags(UInt64)

///|
/// No flags set.
pub fn ChannelFlags::none() -> ChannelFlags {
  ChannelFlags(0)
}

///|
/// Flags from a raw bit field; unknown bits are kept.
pub fn ChannelFlags::from_bits(bits : UInt64) -> ChannelFlags {
  ChannelFlags(bits)
}

///|
/// The raw bit field.
pub fn ChannelFlags::bits(self : ChannelFlags) -> UInt64 {
  self.0
}

///|
/// Whether every flag in `other` is set.
pub fn ChannelFlags::contains(
  self : ChannelFlags,
  other : ChannelFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Combines flags: every flag set in either operand is set.
pub impl BitOr for ChannelFlags with fn lor(a, b) {
  ChannelFlags(a.0 | b.0)
}

///|
/// Keeps the flags set in both operands.
pub impl BitAnd for ChannelFlags with fn land(a, b) {
  ChannelFlags(a.0 & b.0)
}

///|
/// Debug output is the raw bit field.
pub impl Debug for ChannelFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the flags as a JSON number.
pub impl ToJson for ChannelFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
/// Decodes the flags from a JSON number; unknown bits are kept.
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
/// Bit `1 << 0`, which Discord sets but does not document.
pub fn ChannelFlags::guild_feed_removed() -> ChannelFlags {
  ChannelFlags(1UL << 0)
}

///|
/// The thread is pinned to the top of its parent forum or media channel.
pub fn ChannelFlags::pinned() -> ChannelFlags {
  ChannelFlags(1UL << 1)
}

///|
/// Bit `1 << 2`, which Discord sets but does not document.
pub fn ChannelFlags::active_channels_removed() -> ChannelFlags {
  ChannelFlags(1UL << 2)
}

///|
/// A tag must be applied when creating a post in a forum or media channel.
pub fn ChannelFlags::require_tag() -> ChannelFlags {
  ChannelFlags(1UL << 4)
}

///|
/// Bit `1 << 5`, which Discord sets but does not document.
pub fn ChannelFlags::is_spam() -> ChannelFlags {
  ChannelFlags(1UL << 5)
}

///|
/// Bit `1 << 7`, which Discord sets but does not document.
pub fn ChannelFlags::is_guild_resource_channel() -> ChannelFlags {
  ChannelFlags(1UL << 7)
}

///|
/// Bit `1 << 8`, which Discord sets but does not document.
pub fn ChannelFlags::clyde_ai() -> ChannelFlags {
  ChannelFlags(1UL << 8)
}

///|
/// Bit `1 << 9`, which Discord sets but does not document.
pub fn ChannelFlags::is_scheduled_for_deletion() -> ChannelFlags {
  ChannelFlags(1UL << 9)
}

///|
/// Hides the media download options; only available in media channels.
pub fn ChannelFlags::hide_media_download_options() -> ChannelFlags {
  ChannelFlags(1UL << 15)
}

///|
/// Set on channels received over the gateway whose metadata Discord has
/// obfuscated because the bot cannot view them. Only `id`, `type`, `position`
/// and `parent_id` are reliable on such a channel; the HTTP API omits these
/// channels instead of setting this flag.
pub fn ChannelFlags::channel_obfuscated() -> ChannelFlags {
  ChannelFlags(1UL << 17)
}

///|
/// A Spoiler Channel: users must opt in to view its contents.
pub fn ChannelFlags::is_spoiler_channel() -> ChannelFlags {
  ChannelFlags(1UL << 21)
}

///|
/// Whether Discord obfuscated this channel's metadata because the bot cannot
/// view it (`CHANNEL_OBFUSCATED` flag). Only `id`, `typ`, `position` and
/// `parent_id` are reliable on an obfuscated channel; a `CHANNEL_UPDATE` with
/// the full data follows once the bot gains access.
pub fn Channel::is_obfuscated(self : Channel) -> Bool {
  self.flags is Some(flags) &&
  flags.contains(ChannelFlags::channel_obfuscated())
}
