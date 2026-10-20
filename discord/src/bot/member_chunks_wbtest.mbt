///|
/// Chunk `index` of `count`, with one member, one presence, and one
/// not-found id derived from the index.
fn members_chunk(
  index : Int32,
  count~ : Int32 = 3,
) -> @model.GuildMembersChunkEvent {
  let user : Json = {
    "id": Json("\{index + 10}"),
    "username": "member",
    "discriminator": "0",
    "global_name": null,
    "avatar": null,
  }
  let data : Json = {
    "guild_id": "1",
    "members": [
      {
        "user": user,
        "roles": [],
        "joined_at": "2026-10-15T00:00:00Z",
        "deaf": false,
        "mute": false,
      },
    ],
    "presences": [
      { "user": { "id": Json("\{index + 10}") }, "status": "online" },
    ],
    "not_found": [Json("\{index + 20}")],
    "chunk_index": Json(index),
    "chunk_count": Json(count),
  }
  try! @json.from_json(data)
}

///|
fn member_ids(fetched : FetchedMembers) -> Array[String] {
  fetched.members.map(fetched_member => {
    fetched_member.user.unwrap().id.to_string()
  })
}

///|
test "a single chunk completes at once" {
  let chunks = MemberChunks::new()
  guard chunks.add(members_chunk(0, count=1)) is Some(fetched) else {
    fail("expected the fetch to complete")
  }
  assert_eq(fetched.members.length(), 1)
  json_inspect(fetched.not_found, content=["20"])
}

///|
test "out-of-order chunks complete on the last and assemble in index order" {
  let chunks = MemberChunks::new()
  assert_true(chunks.add(members_chunk(2)) is None)
  assert_true(chunks.add(members_chunk(0)) is None)
  guard chunks.add(members_chunk(1)) is Some(fetched) else {
    fail("expected the fetch to complete")
  }
  json_inspect(member_ids(fetched), content=["10", "11", "12"])
  json_inspect(
    fetched.presences.map(presence => presence.user.unwrap().id.unwrap()),
    content=["10", "11", "12"],
  )
  json_inspect(fetched.not_found, content=["20", "21", "22"])
}

///|
test "impossible and mismatched chunks are ignored" {
  let chunks = MemberChunks::new()
  assert_true(chunks.add(members_chunk(3)) is None)
  assert_true(chunks.add(members_chunk(-1)) is None)
  assert_true(chunks.add(members_chunk(0, count=0)) is None)
  assert_true(chunks.count is None)
  assert_true(chunks.add(members_chunk(0, count=2)) is None)
  // the first valid chunk fixed the count at 2
  assert_true(chunks.add(members_chunk(1, count=3)) is None)
  assert_true(chunks.add(members_chunk(2, count=3)) is None)
  assert_true(chunks.add(members_chunk(1, count=2)) is Some(_))
}

///|
test "a repeated index does not complete the fetch early" {
  let chunks = MemberChunks::new()
  assert_true(chunks.add(members_chunk(0, count=2)) is None)
  assert_true(chunks.add(members_chunk(0, count=2)) is None)
  assert_true(chunks.add(members_chunk(1, count=2)) is Some(_))
}
