///|
/// A Discord invite with optional usage metadata.
pub(all) struct Invite {
  typ : InviteType?
  code : String
  guild : PartialGuild?
  channel : Nullable[PartialChannel]?
  inviter : User?
  target_type : InviteTargetType?
  target_user : User?
  target_application : Application?
  approximate_presence_count : Int?
  approximate_member_count : Int?
  expires_at : Nullable[Timestamp]?
  // Not modeled: invite stage_instance is deprecated by Discord.
  guild_scheduled_event : GuildScheduledEvent?
  flags : InviteFlags?
  roles : Array[PartialRole]?
  uses : Int?
  max_uses : Int?
  max_age : Int?
  temporary : Bool?
  created_at : Timestamp?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// Bit flags describing a guild invite.
pub(all) struct InviteFlags(UInt64) derive(Eq)

///|
pub fn InviteFlags::from_bits(bits : UInt64) -> InviteFlags {
  InviteFlags(bits)
}

///|
pub fn InviteFlags::bits(self : InviteFlags) -> UInt64 {
  self.0
}

///|
pub impl Debug for InviteFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
pub impl ToJson for InviteFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for InviteFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      InviteFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ => raise JsonDecodeError((path, "expected invite flags (number)"))
        },
      )
    Number(value, repr=None) => InviteFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected invite flags (number)"))
  }
}

///|
pub fn InviteFlags::is_guest_invite() -> InviteFlags {
  InviteFlags(1UL << 0)
}

///|
/// The destination category of a Discord invite.
pub(all) enum InviteType {
  Guild
  GroupDm
  Friend
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn InviteType::to_int(self : InviteType) -> Int {
  match self {
    Guild => 0
    GroupDm => 1
    Friend => 2
    Unknown(value) => value
  }
}

///|
pub fn InviteType::from_int(value : Int) -> InviteType {
  match value {
    0 => Guild
    1 => GroupDm
    2 => Friend
    value => Unknown(value)
  }
}

///|
pub impl ToJson for InviteType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for InviteType with fn from_json(json, path) {
  match json {
    Number(value, ..) => InviteType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected the destination category of a discord invite (number)"),
      )
  }
}

///|
/// The special target carried by a voice channel invite.
pub(all) enum InviteTargetType {
  Stream
  EmbeddedApplication
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn InviteTargetType::to_int(self : InviteTargetType) -> Int {
  match self {
    Stream => 1
    EmbeddedApplication => 2
    Unknown(value) => value
  }
}

///|
pub fn InviteTargetType::from_int(value : Int) -> InviteTargetType {
  match value {
    1 => Stream
    2 => EmbeddedApplication
    value => Unknown(value)
  }
}

///|
pub impl ToJson for InviteTargetType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for InviteTargetType with fn from_json(json, path) {
  match json {
    Number(value, ..) => InviteTargetType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (
          path, "expected the special target carried by a voice channel invite (number)",
        ),
      )
  }
}

///|
/// Progress and outcome of an invite target-user CSV update.
pub(all) struct TargetUsersJobStatus {
  status : TargetUsersJobStatusCode
  total_users : Int
  processed_users : Int
  created_at : Timestamp
  completed_at : Nullable[Timestamp]
  error_message : String?
} derive(ToJson, FromJson, Debug)

///|
/// State of an invite target-user CSV update job.
pub(all) enum TargetUsersJobStatusCode {
  Unspecified
  Processing
  Completed
  Failed
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn TargetUsersJobStatusCode::to_int(self : TargetUsersJobStatusCode) -> Int {
  match self {
    Unspecified => 0
    Processing => 1
    Completed => 2
    Failed => 3
    Unknown(value) => value
  }
}

///|
pub fn TargetUsersJobStatusCode::from_int(
  value : Int,
) -> TargetUsersJobStatusCode {
  match value {
    0 => Unspecified
    1 => Processing
    2 => Completed
    3 => Failed
    value => Unknown(value)
  }
}

///|
pub impl ToJson for TargetUsersJobStatusCode with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for TargetUsersJobStatusCode with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => TargetUsersJobStatusCode::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected invite target-user job status (number)"),
      )
  }
}
