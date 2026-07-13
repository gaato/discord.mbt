///|
/// A Discord invite with optional usage metadata.
pub(all) struct Invite {
  typ : InviteType?
  code : String
  // TODO(partial-guild): Port guild with the invite partial guild surface.
  channel : Nullable[Channel]?
  inviter : User?
  target_type : InviteTargetType?
  target_user : User?
  // TODO(application): Port target_application with the application domain.
  approximate_presence_count : Int?
  approximate_member_count : Int?
  expires_at : Nullable[Timestamp]?
  // TODO(stage-instance): Port stage_instance with the stage instance domain.
  // TODO(scheduled-event): Port guild_scheduled_event with that domain.
  // TODO(invite-role): Port the partial roles and invite flags surface together.
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
      raise @json.JsonDecodeError(
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
      raise @json.JsonDecodeError(
        (
          path, "expected the special target carried by a voice channel invite (number)",
        ),
      )
  }
}
