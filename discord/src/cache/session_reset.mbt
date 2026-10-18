///|
/// Whether a `READY` for `shard` (`[shard_id, shard_count]`, absent when the
/// session is unsharded) speaks for `guild_id`. A `READY` lists every guild
/// of its shard, so a guild it speaks for but does not list was left while
/// the bot was disconnected, and no `GUILD_DELETE` will come for it. A
/// malformed shard speaks for no guild.
fn ready_covers(guild_id : @model.GuildId, shard : Array[Int32]?) -> Bool {
  match shard {
    None => true
    Some([shard_id, shard_count]) if shard_count > 0 =>
      ((guild_id.value() >> 22) % shard_count.to_uint64()).to_int() == shard_id
    Some(_) => false
  }
}
