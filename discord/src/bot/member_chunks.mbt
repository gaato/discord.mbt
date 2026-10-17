///|
/// The chunks of one member request received so far. The first valid chunk
/// fixes the chunk count; a chunk that disagrees with it is ignored.
priv struct MemberChunks {
  received : Map[Int32, @model.GuildMembersChunkEvent]
  mut count : Int32?
}

///|
fn MemberChunks::new() -> MemberChunks {
  { received: Map([]), count: None, }
}

///|
/// Record a chunk and return the assembled members once every index in
/// `0..<chunk_count` has arrived. Chunks with an impossible index or count are
/// ignored, and a repeated index replaces the earlier chunk.
fn MemberChunks::add(
  self : MemberChunks,
  chunk : @model.GuildMembersChunkEvent,
) -> FetchedMembers? {
  if chunk.chunk_count <= 0 ||
    chunk.chunk_index < 0 ||
    chunk.chunk_index >= chunk.chunk_count {
    return None
  }
  if self.count is None {
    self.count = Some(chunk.chunk_count)
  }
  if self.count != Some(chunk.chunk_count) {
    return None
  }
  self.received[chunk.chunk_index] = chunk
  guard self.received.length() == chunk.chunk_count else { return None }
  let members = []
  let presences = []
  let not_found = []
  for index in 0..<chunk.chunk_count {
    let part = self.received[index]
    members.append(part.members)
    if part.presences is Some(values) {
      presences.append(values)
    }
    if part.not_found is Some(values) {
      not_found.append(values)
    }
  }
  Some({ members, presences, not_found, })
}
