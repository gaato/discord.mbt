///|
/// A change to the number of cached entries holding one user.
priv enum UserStep {
  Hold
  Release
}

///|
/// What a `UserStep` does to the user's record.
priv enum UserMove {
  /// The first holder: the record moves from the recent users to the held
  /// ones.
  Promote
  /// Another holder, or one of several letting go: the record stays held.
  Keep
  /// The last holder let go: the record leaves the cache.
  Drop
  /// A release with no holder recorded. Never happens while every holder
  /// releases exactly what it held; ignored rather than driven negative.
  Stray
}

///|
fn user_move(count : Int32, step : UserStep) -> UserMove {
  match (step, count) {
    (Hold, 0) => Promote
    (Hold, _) => Keep
    (Release, 0) => Stray
    (Release, 1) => Drop
    (Release, _) => Keep
  }
}

///|
/// Cached users, kept only while something holds them.
///
/// A user is *held* by each cached entry that refers to it — a member entry,
/// a cached message (its author), and the current user — and leaves the
/// cache when the last holder goes, whatever removed it. `counts_` is the
/// exact holder count; the held records sit in `held_` under the `users`
/// limit, which may drop a record early but never changes a count. Users
/// seen without a holder (a ban, a departed member's last view, the author of
/// a message the cache does not keep, an interaction's user) go to `recent_`
/// instead, under the `recent_users` limit. A user is in at most one of the
/// two maps.
priv struct UserStore {
  enabled_ : Bool
  held_ : TimedMap[@model.UserId, @model.User]
  counts_ : Map[@model.UserId, Int32]
  recent_ : TimedMap[@model.UserId, @model.User]
}

///|
fn UserStore::new(
  enabled~ : Bool,
  held~ : CacheLimit,
  recent~ : CacheLimit,
  now~ : () -> Int64,
) -> UserStore {
  {
    enabled_: enabled,
    held_: TimedMap::new(held, now),
    counts_: Map([]),
    recent_: TimedMap::new(recent, now),
  }
}

///|
/// A cached entry starts holding `user`, whose view becomes the current one.
fn UserStore::hold(self : UserStore, user : @model.User) -> Unit {
  guard self.enabled_ else { return }
  let count = self.counts_.get(user.id).unwrap_or(0)
  if user_move(count, Hold) is Promote {
    self.recent_.remove(user.id) |> ignore
  }
  self.counts_[user.id] = count + 1
  self.held_.put(user.id, user) |> ignore
}

///|
/// A cached entry holding user `id` left the cache.
fn UserStore::release(self : UserStore, id : @model.UserId) -> Unit {
  guard self.enabled_ else { return }
  let count = self.counts_.get(id).unwrap_or(0)
  match user_move(count, Release) {
    Drop => {
      self.counts_.remove(id)
      self.held_.remove(id) |> ignore
    }
    Keep => self.counts_[id] = count - 1
    // `Stray`; `Promote` only answers a hold.
    _ => ()
  }
}

///|
/// `user` was seen in an event: a held record takes the newer view, and an
/// unheld user becomes the most recent of the recent users.
fn UserStore::see(self : UserStore, user : @model.User) -> Unit {
  guard self.enabled_ else { return }
  if self.counts_.contains(user.id) {
    self.held_.put(user.id, user) |> ignore
  } else {
    self.recent_.put(user.id, user) |> ignore
  }
}

///|
fn UserStore::get(self : UserStore, id : @model.UserId) -> @model.User? {
  match self.held_.get(id) {
    Some(user) => Some(user)
    None => self.recent_.get(id)
  }
}

///|
fn UserStore::values(self : UserStore) -> Array[@model.User] {
  let users = self.held_.values()
  users.append(self.recent_.values())
  users
}
