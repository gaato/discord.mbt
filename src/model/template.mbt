///|
/// A reusable Discord guild template and its serialized guild snapshot.
pub(all) struct GuildTemplate {
  code : String
  name : String
  description : Nullable[String]
  usage_count : Int
  creator_id : UserId
  creator : User
  created_at : Timestamp
  updated_at : Timestamp
  source_guild_id : GuildId
  // TODO(partial-guild): Replace the raw source snapshot when its input model is ported.
  serialized_source_guild : Json
  is_dirty : Nullable[Bool]
} derive(ToJson, FromJson, Debug)
