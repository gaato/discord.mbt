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
/// Use `AllowedMentions(...)` so parse categories and explicit ID lists cannot
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
///
/// ```mbt check
/// test "allow selected users without parsing every user mention" {
///   let user_id : @model.UserId = Id(42UL)
///   let mentions = @model.AllowedMentions(
///     parse=[Roles],
///     users=[user_id],
///     replied_user=false,
///   )
///   json_inspect(mentions, content={
///     "parse": ["roles"],
///     "users": ["42"],
///     "replied_user": false,
///   })
/// }
/// ```
pub fn AllowedMentions::AllowedMentions(
  parse? : Array[AllowedMentionType],
  roles? : Array[RoleId],
  users? : Array[UserId],
  replied_user? : Bool,
) -> AllowedMentions raise AllowedMentionsError {
  if roles is Some(ids) && ids.length() > 100 {
    raise TooManyRoles(count=ids.length())
  }
  if users is Some(ids) && ids.length() > 100 {
    raise TooManyUsers(count=ids.length())
  }
  if parse is Some(types) {
    if roles is Some(_) && types.contains(Roles) {
      raise ParseAndExplicit(typ=Roles)
    }
    if users is Some(_) && types.contains(Users) {
      raise ParseAndExplicit(typ=Users)
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
  { parse: Some([]), roles: None, users: None, replied_user: None, }
}

///|
/// Allow user and role mentions while suppressing `@everyone` and `@here`.
/// This is the HTTP client's default for ordinary channel messages.
pub fn AllowedMentions::safe_default() -> AllowedMentions {
  { parse: Some([Users, Roles]), roles: None, users: None, replied_user: None, }
}

///|
pub impl ToJson for AllowedMentions with fn to_json(self) {
  let fields : Map[String, Json] = Map([])
  if self.parse is Some(parse) {
    fields["parse"] = Json(parse)
  }
  if self.roles is Some(roles) {
    fields["roles"] = Json(roles)
  }
  if self.users is Some(users) {
    fields["users"] = Json(users)
  }
  if self.replied_user is Some(replied_user) {
    fields["replied_user"] = Json(replied_user)
  }
  Json::object(fields)
}
