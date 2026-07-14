///|
/// A Discord developer team and its members.
pub(all) struct Team {
  icon : Nullable[ImageHash]
  id : TeamId
  members : Array[TeamMember]
  name : String
  owner_user_id : UserId
} derive(ToJson, FromJson, Debug)

///|
/// A user's membership record within a developer team.
pub(all) struct TeamMember {
  membership_state : TeamMembershipState
  team_id : TeamId
  user : User
  role : String?
} derive(ToJson, FromJson, Debug)

///|
/// A user's invitation state within a developer team.
pub(all) enum TeamMembershipState {
  Invited
  Accepted
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn TeamMembershipState::to_int(self : TeamMembershipState) -> Int {
  match self {
    Invited => 1
    Accepted => 2
    Unknown(value) => value
  }
}

///|
pub fn TeamMembershipState::from_int(value : Int) -> TeamMembershipState {
  match value {
    1 => Invited
    2 => Accepted
    value => Unknown(value)
  }
}

///|
pub impl ToJson for TeamMembershipState with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for TeamMembershipState with fn from_json(json, path) {
  match json {
    Number(value, ..) => TeamMembershipState::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "expected a user's invitation state within a developer team (number)",
        ),
      )
  }
}
