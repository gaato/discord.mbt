///|
test "ready_covers speaks for the guilds of its shard" {
  // (id >> 22) % 2: 1 << 22 is on shard 1, 2 << 22 on shard 0.
  let on_shard_1 : @model.GuildId = @model.Id::parse((1UL << 22).to_string())
  let on_shard_0 : @model.GuildId = @model.Id::parse((2UL << 22).to_string())
  let cases : Array[(String, @model.GuildId, Array[Int32]?, Bool)] = [
    ("unsharded", on_shard_1, None, true),
    ("its shard", on_shard_1, Some([1, 2]), true),
    ("another shard", on_shard_0, Some([1, 2]), false),
    ("shard 0", on_shard_0, Some([0, 2]), true),
    ("zero shard count", on_shard_0, Some([0, 0]), false),
    ("malformed", on_shard_0, Some([0]), false),
  ]
  for case in cases {
    let (name, guild_id, shard, expected) = case
    assert_eq((name, ready_covers(guild_id, shard)), (name, expected))
  }
}
