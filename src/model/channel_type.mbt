///|
/// The type of a channel.
///
/// This is the reference implementation of the wire-enum pattern used across
/// the whole model layer: an `Unknown(raw)` catch-all so decoding never fails
/// on values Discord adds later, plus total `to_int`/`from_int` conversions
/// and hand-written JSON impls (the derived enum representation is not
/// Discord's scalar encoding).
pub(all) enum ChannelType {
  GuildText
  Dm
  GuildVoice
  GroupDm
  GuildCategory
  GuildAnnouncement
  AnnouncementThread
  PublicThread
  PrivateThread
  GuildStageVoice
  GuildDirectory
  GuildForum
  GuildMedia
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ChannelType::to_int(self : ChannelType) -> Int {
  match self {
    GuildText => 0
    Dm => 1
    GuildVoice => 2
    GroupDm => 3
    GuildCategory => 4
    GuildAnnouncement => 5
    AnnouncementThread => 10
    PublicThread => 11
    PrivateThread => 12
    GuildStageVoice => 13
    GuildDirectory => 14
    GuildForum => 15
    GuildMedia => 16
    Unknown(v) => v
  }
}

///|
pub fn ChannelType::from_int(value : Int) -> ChannelType {
  match value {
    0 => GuildText
    1 => Dm
    2 => GuildVoice
    3 => GroupDm
    4 => GuildCategory
    5 => GuildAnnouncement
    10 => AnnouncementThread
    11 => PublicThread
    12 => PrivateThread
    13 => GuildStageVoice
    14 => GuildDirectory
    15 => GuildForum
    16 => GuildMedia
    v => Unknown(v)
  }
}

///|
pub impl ToJson for ChannelType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ChannelType with fn from_json(json, path) {
  match json {
    Number(n, ..) => ChannelType::from_int(n.to_int())
    _ => raise @json.JsonDecodeError((path, "expected a channel type (number)"))
  }
}
