///|
/// A Discord custom or reaction emoji.
pub(all) struct Emoji {
  id : Nullable[EmojiId]?
  name : Nullable[String]
  animated : Bool?
  roles : Array[RoleId]?
  user : User?
  require_colons : Bool?
  managed : Bool?
  available : Bool?
} derive(ToJson, FromJson, Debug)
