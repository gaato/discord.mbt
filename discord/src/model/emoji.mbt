///|
/// A Discord custom or reaction emoji.
#derive(ToJson, FromJson, Debug)
pub(all) struct Emoji {
  id : Nullable[EmojiId]?
  name : Nullable[String]
  animated : Bool?
  roles : Array[RoleId]?
  user : User?
  require_colons : Bool?
  managed : Bool?
  available : Bool?
}
