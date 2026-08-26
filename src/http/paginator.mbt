///|
/// A stateful, asynchronously fetched sequence of REST result pages.
///
/// Call `next_page`, `each`, or `collect` sequentially; all three consume the
/// same cursor state.
pub struct Paginator[T] {
  priv next_ : async () -> Array[T]?
  priv pending_ : Ref[Array[T]?]
}

///|
/// Fetch the next non-empty page, or `None` after the paginator reaches its
/// end. Empty and short REST pages both mark the sequence as finished.
pub async fn[T] Paginator::next_page(self : Paginator[T]) -> Array[T]? {
  match self.pending_.val {
    Some(page) => {
      self.pending_.val = None
      Some(page)
    }
    None => (self.next_)()
  }
}

///|
/// Apply a synchronous callback to every remaining item.
pub async fn[T] Paginator::each(
  self : Paginator[T],
  f : (T) -> Unit raise,
) -> Unit {
  for ;; {
    match self.next_page() {
      Some(page) => page.each(f)
      None => break
    }
  }
}

///|
/// Collect at most `max` remaining items. A non-positive maximum performs no
/// requests and returns an empty array.
pub async fn[T] Paginator::collect(self : Paginator[T], max~ : Int) -> Array[T] {
  let result : Array[T] = []
  if max <= 0 {
    return result
  }
  while result.length() < max {
    guard self.next_page() is Some(page) else { break }
    for index, item in page {
      result.push(item)
      if result.length() == max {
        if index + 1 < page.length() {
          self.pending_.val = Some(page[index + 1:].to_owned())
        }
        break
      }
    }
  }
  result
}

///|
fn validate_page_limit(
  resource : String,
  limit : Int?,
  maximum : Int,
) -> Unit raise DiscordHttpError {
  validate_range("\{resource} limit", limit, min=1, max=maximum)
}

///|
fn[A, B] validate_cursor_pair(
  resource : String,
  before : A?,
  after : B?,
) -> Unit raise DiscordHttpError {
  if before is Some(_) && after is Some(_) {
    raise Validation(
      message="\{resource} pagination cannot use before and after together",
    )
  }
}

///|
fn[T, C : Compare] minimum_cursor(page : Array[T], cursor_of : (T) -> C) -> C? {
  guard page.get(0) is Some(first) else { return None }
  let result = Ref(cursor_of(first))
  for item in page[1:] {
    let cursor = cursor_of(item)
    if cursor < result.val {
      result.val = cursor
    }
  }
  Some(result.val)
}

///|
fn[T, C : Compare] maximum_cursor(page : Array[T], cursor_of : (T) -> C) -> C? {
  guard page.get(0) is Some(first) else { return None }
  let result = Ref(cursor_of(first))
  for item in page[1:] {
    let cursor = cursor_of(item)
    if cursor > result.val {
      result.val = cursor
    }
  }
  Some(result.val)
}

///|
fn[T, C : Compare] maximum_present_cursor(
  page : Array[T],
  cursor_of : (T) -> C?,
) -> C? {
  let result : Ref[C?] = Ref(None)
  for item in page {
    if cursor_of(item) is Some(cursor) {
      match result.val {
        Some(current) if current >= cursor => ()
        _ => result.val = Some(cursor)
      }
    }
  }
  result.val
}

///|
/// Internal constructor shared by real endpoint paginators and fake wbtests.
fn[T, C] paginator_from_cursor(
  page_size : Int,
  initial_cursor : C?,
  fetch : async (C?, Int) -> Array[T],
  next_cursor : (Array[T]) -> C?,
) -> Paginator[T] {
  let cursor = Ref(initial_cursor)
  let finished = Ref(false)
  {
    next_: () => {
      if finished.val {
        return None
      }
      let page = fetch(cursor.val, page_size)
      if page.is_empty() {
        finished.val = true
        return None
      }
      let following = next_cursor(page)
      if page.length() < page_size || following is None {
        finished.val = true
      } else {
        cursor.val = following
      }
      Some(page)
    },
    pending_: Ref(None),
  }
}

///|
/// Page through channel messages. Without a cursor, pagination starts at the
/// newest messages and continues backward. `around` produces one page only.
///
/// Start before or after a known message by supplying one cursor. `before`,
/// `after`, and `around` are mutually exclusive. All paginator methods
/// (`next_page`, `collect`, `each`) consume the same mutable cursor state;
/// do not call them concurrently. Empty pages and pages shorter than the
/// configured page size mark the end.
///
/// ```mbt check
/// test "walk message history newest-first" {
///   async fn print_history(
///     client : @http.Client,
///     channel_id : @model.ChannelId,
///     newest_known : @model.MessageId,
///   ) -> Unit {
///     let pages = client.paginate_messages(channel_id, page_size=100)
///     for ;; {
///       match pages.next_page() {
///         Some(messages) =>
///           for message in messages {
///             println("\{message.id}: \{message.content}")
///           }
///         None => break
///       }
///     }
///     // `collect` bounds the walk instead of draining the full history.
///     let recent = client
///       .paginate_messages(channel_id, before=newest_known, page_size=100)
///       .collect(max=250)
///     ignore(recent)
///   }
///
///   ignore(print_history)
/// }
/// ```
pub fn Client::paginate_messages(
  self : Client,
  channel_id : @model.ChannelId,
  before? : @model.MessageId,
  after? : @model.MessageId,
  around? : @model.MessageId,
  page_size? : Int = 100,
) -> Paginator[@model.Message] raise DiscordHttpError {
  validate_page_limit("message", Some(page_size), 100)
  let cursor_count = (if around is Some(_) { 1 } else { 0 }) +
    (if before is Some(_) { 1 } else { 0 }) +
    (if after is Some(_) { 1 } else { 0 })
  if cursor_count > 1 {
    raise Validation(
      message="message pagination accepts only one of around, before, or after",
    )
  }
  match (around, after) {
    (Some(id), None) =>
      paginator_from_cursor(
        page_size,
        Some(id),
        (cursor, limit) => {
          self.get_channel_messages(channel_id, limit~, around?=cursor)
        },
        _ => None,
      )
    (None, Some(id)) =>
      paginator_from_cursor(
        page_size,
        Some(id),
        (cursor, limit) => {
          self.get_channel_messages(channel_id, limit~, after?=cursor)
        },
        page => maximum_cursor(page, message => message.id),
      )
    (None, None) =>
      paginator_from_cursor(
        page_size,
        before,
        (cursor, limit) => {
          self.get_channel_messages(channel_id, limit~, before?=cursor)
        },
        page => minimum_cursor(page, message => message.id),
      )
    (Some(_), Some(_)) => abort("validated above")
  }
}

///|
/// Page through guild members in ascending user-id order.
///
/// Use `each` when the item callback is synchronous. Available paginator
/// constructors cover messages, guild members, bans, audit-log entries,
/// scheduled-event users, poll-answer voters, and current-user guilds;
/// cursor direction and endpoint maximums are encoded by each constructor.
///
/// ```mbt check
/// test "visit every guild member" {
///   async fn print_members(
///     client : @http.Client,
///     guild_id : @model.GuildId,
///   ) -> Unit {
///     client
///     .paginate_guild_members(guild_id)
///     .each(guild_member => println("\{Repr(guild_member.user)}"))
///   }
///
///   ignore(print_members)
/// }
/// ```
pub fn Client::paginate_guild_members(
  self : Client,
  guild_id : @model.GuildId,
  after? : @model.UserId,
  page_size? : Int = 1000,
) -> Paginator[@model.GuildMember] raise DiscordHttpError {
  validate_page_limit("guild member", Some(page_size), 1000)
  paginator_from_cursor(
    page_size,
    after,
    (cursor, limit) => self.list_guild_members(guild_id, limit~, after?=cursor),
    page => {
      maximum_present_cursor(page, guild_member => {
        guild_member.user.map(user => user.id)
      })
    },
  )
}

///|
/// Page through guild bans using either a before or after cursor.
pub fn Client::paginate_guild_bans(
  self : Client,
  guild_id : @model.GuildId,
  before? : @model.UserId,
  after? : @model.UserId,
  page_size? : Int = 1000,
) -> Paginator[@model.GuildBan] raise DiscordHttpError {
  validate_page_limit("guild ban", Some(page_size), 1000)
  validate_cursor_pair("guild ban", before, after)
  match after {
    Some(id) =>
      paginator_from_cursor(
        page_size,
        Some(id),
        (cursor, limit) => self.get_guild_bans(guild_id, limit~, after?=cursor),
        page => maximum_cursor(page, ban => ban.user.id),
      )
    None =>
      paginator_from_cursor(
        page_size,
        before,
        (cursor, limit) => self.get_guild_bans(guild_id, limit~, before?=cursor),
        page => minimum_cursor(page, ban => ban.user.id),
      )
  }
}

///|
/// Page backward through audit-log entries. Referenced sidecar objects from
/// each audit-log response are intentionally not included in the item stream.
pub fn Client::paginate_guild_audit_log(
  self : Client,
  guild_id : @model.GuildId,
  user_id? : @model.UserId,
  action_type? : @model.AuditLogEvent,
  before? : @model.AuditLogEntryId,
  page_size? : Int = 100,
) -> Paginator[@model.AuditLogEntry] raise DiscordHttpError {
  validate_page_limit("audit log", Some(page_size), 100)
  paginator_from_cursor(
    page_size,
    before,
    (cursor, limit) => {
      let log = self.get_guild_audit_log(
        guild_id,
        user_id?,
        action_type?,
        before?=cursor,
        limit~,
      )
      log.audit_log_entries
    },
    page => minimum_cursor(page, entry => entry.id),
  )
}

///|
/// Page through users interested in a guild scheduled event.
pub fn Client::paginate_guild_scheduled_event_users(
  self : Client,
  guild_id : @model.GuildId,
  event_id : @model.ScheduledEventId,
  with_member? : Bool,
  before? : @model.UserId,
  after? : @model.UserId,
  page_size? : Int = 100,
) -> Paginator[@model.GuildScheduledEventUser] raise DiscordHttpError {
  validate_page_limit("scheduled event user", Some(page_size), 100)
  validate_cursor_pair("scheduled event user", before, after)
  match after {
    Some(id) =>
      paginator_from_cursor(
        page_size,
        Some(id),
        (cursor, limit) => {
          self.list_guild_scheduled_event_users(
            guild_id,
            event_id,
            limit~,
            with_member?,
            after?=cursor,
          )
        },
        page => maximum_cursor(page, event_user => event_user.user.id),
      )
    None =>
      paginator_from_cursor(
        page_size,
        before,
        (cursor, limit) => {
          self.list_guild_scheduled_event_users(
            guild_id,
            event_id,
            limit~,
            with_member?,
            before?=cursor,
          )
        },
        page => minimum_cursor(page, event_user => event_user.user.id),
      )
  }
}

///|
/// Page forward through users who selected one poll answer.
pub fn Client::paginate_poll_answer_voters(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  answer_id : Int,
  after? : @model.UserId,
  page_size? : Int = 100,
) -> Paginator[@model.User] raise DiscordHttpError {
  validate_page_limit("poll voter", Some(page_size), 100)
  paginator_from_cursor(
    page_size,
    after,
    (cursor, limit) => {
      let response = self.get_poll_answer_voters(
        channel_id,
        message_id,
        answer_id,
        after?=cursor,
        limit~,
      )
      response.users
    },
    page => maximum_cursor(page, user => user.id),
  )
}

///|
/// Page through the current user's partial guild objects.
pub fn Client::paginate_current_user_guilds(
  self : Client,
  before? : @model.GuildId,
  after? : @model.GuildId,
  with_counts? : Bool,
  page_size? : Int = 200,
) -> Paginator[@model.CurrentUserGuild] raise DiscordHttpError {
  validate_page_limit("current user guild", Some(page_size), 200)
  validate_cursor_pair("current user guild", before, after)
  match after {
    Some(id) =>
      paginator_from_cursor(
        page_size,
        Some(id),
        (cursor, limit) => {
          self.get_current_user_guilds(limit~, after?=cursor, with_counts?)
        },
        page => maximum_cursor(page, guild => guild.id),
      )
    None =>
      paginator_from_cursor(
        page_size,
        before,
        (cursor, limit) => {
          self.get_current_user_guilds(limit~, before?=cursor, with_counts?)
        },
        page => minimum_cursor(page, guild => guild.id),
      )
  }
}
