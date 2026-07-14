///|
/// A mention category Discord may derive directly from message content.
pub(all) enum AllowedMentionType {
  Roles
  Users
  Everyone
} derive(Eq, Debug)

///|
pub impl ToJson for AllowedMentionType with fn to_json(self) {
  Json::string(
    match self {
      Roles => "roles"
      Users => "users"
      Everyone => "everyone"
    },
  )
}

///|
/// An invalid allowed-mentions configuration rejected during construction.
pub(all) suberror AllowedMentionsError {
  ParseAndExplicit(typ~ : AllowedMentionType)
  TooManyRoles(count~ : Int)
  TooManyUsers(count~ : Int)
} derive(Eq, Debug)

///|
/// Controls which mentions Discord resolves and notifies for an outgoing
/// message.
///
/// Use `AllowedMentions::new` so parse categories and explicit ID lists cannot
/// conflict. The stored arrays are copied during construction to preserve that
/// invariant if callers later mutate their input arrays.
pub struct AllowedMentions {
  priv parse : Array[AllowedMentionType]?
  priv roles : Array[RoleId]?
  priv users : Array[UserId]?
  priv replied_user : Bool?
} derive(Debug)

///|
/// Construct a validated allowed-mentions object.
pub fn AllowedMentions::new(
  parse? : Array[AllowedMentionType],
  roles? : Array[RoleId],
  users? : Array[UserId],
  replied_user? : Bool,
) -> AllowedMentions raise AllowedMentionsError {
  if roles is Some(ids) && ids.length() > 100 {
    raise AllowedMentionsError::TooManyRoles(count=ids.length())
  }
  if users is Some(ids) && ids.length() > 100 {
    raise AllowedMentionsError::TooManyUsers(count=ids.length())
  }
  if parse is Some(types) {
    if roles is Some(_) && types.contains(Roles) {
      raise AllowedMentionsError::ParseAndExplicit(typ=Roles)
    }
    if users is Some(_) && types.contains(Users) {
      raise AllowedMentionsError::ParseAndExplicit(typ=Users)
    }
  }
  {
    parse: parse.map(types => types.copy()),
    roles: roles.map(ids => ids.copy()),
    users: users.map(ids => ids.copy()),
    replied_user,
  }
}

///|
/// Suppress every mention parsed from message content.
pub fn AllowedMentions::none() -> AllowedMentions {
  { parse: Some([]), roles: None, users: None, replied_user: None }
}

///|
/// Allow user and role mentions while suppressing `@everyone` and `@here`.
/// This is the HTTP client's default for ordinary channel messages.
pub fn AllowedMentions::safe_default() -> AllowedMentions {
  { parse: Some([Users, Roles]), roles: None, users: None, replied_user: None }
}

///|
pub impl ToJson for AllowedMentions with fn to_json(self) {
  let fields : Map[String, Json] = {}
  if self.parse is Some(parse) {
    fields["parse"] = parse.to_json()
  }
  if self.roles is Some(roles) {
    fields["roles"] = roles.to_json()
  }
  if self.users is Some(users) {
    fields["users"] = users.to_json()
  }
  if self.replied_user is Some(replied_user) {
    fields["replied_user"] = replied_user.to_json()
  }
  Json::object(fields)
}
