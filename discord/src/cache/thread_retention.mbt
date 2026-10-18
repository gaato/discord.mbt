///|
fn is_thread(channel : @model.Channel) -> Bool {
  match channel.typ {
    AnnouncementThread | PublicThread | PrivateThread => true
    _ => false
  }
}

///|
/// What the cache knows of an active thread, kept whether or not channels are
/// retained, so the thread's messages can be found when it goes.
priv struct ThreadEntry {
  guild_id : @model.GuildId
  parent_id : @model.ChannelId?
  private_ : Bool
}

///|
fn ThreadEntry::of(
  channel : @model.Channel,
  guild_id : @model.GuildId,
) -> ThreadEntry {
  {
    guild_id,
    parent_id: match channel.parent_id {
      Some(Value(parent_id)) => Some(parent_id)
      _ => None
    },
    private_: channel.typ is PrivateThread,
  }
}

///|
/// Whether a stored or updated channel stays in the cache. Discord keeps
/// archived threads but stops sending their events, so an archived thread
/// leaves the cache rather than going stale there; fetch archived threads
/// over REST.
fn keeps_channel(channel : @model.Channel) -> Bool {
  !(is_thread(channel) &&
  channel.thread_metadata is Some(metadata) &&
  metadata.archived)
}

///|
/// Whether a `THREAD_MEMBERS_UPDATE` removed the current user from a private
/// thread, which it can then no longer see. A public thread stays readable.
fn loses_thread(
  removed : Array[@model.UserId]?,
  current_user : @model.UserId?,
  private_ : Bool,
) -> Bool {
  private_ &&
  current_user is Some(user_id) &&
  removed is Some(removed) &&
  removed.contains(user_id)
}

///|
/// Whether a `THREAD_LIST_SYNC` for `guild_id` covering the parents
/// `channel_ids` (the whole guild when absent) replaces `entry`.
fn synced_away(
  entry : ThreadEntry,
  guild_id : @model.GuildId,
  channel_ids : Array[@model.ChannelId]?,
) -> Bool {
  entry.guild_id == guild_id &&
  (match channel_ids {
    None => true
    Some(parent_ids) =>
      entry.parent_id is Some(parent_id) && parent_ids.contains(parent_id)
  })
}
