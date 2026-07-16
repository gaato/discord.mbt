///|
/// Threads: from message, standalone public/private, membership, archived
/// listings, forum/media threads.
async fn sec_threads(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let text = need(p.s.text, "text channel") catch {
    _ => {
      p.push("threads section", Skip, "no text channel")
      return
    }
  }
  p.probe("start_thread_from_message", () => {
    let msg = c.create_message(text, content="thread seed")
    let thread = c.start_thread_from_message(
      text,
      msg.id,
      "probe-thread-msg",
      auto_archive_duration=OneHour,
    )
    let _ = c.delete_channel(thread.id, audit_reason="live probe cleanup")
    "id=\{thread.id}"
  })
  p.probe("MessageRef::start_thread", () => {
    let msg = c.create_message(text, content="thread seed 2")
    let thread = c.message_ref(text, msg.id).start_thread("probe-thread-msg2")
    let _ = c.delete_channel(thread.id)
    "id=\{thread.id}"
  })
  let mut public_thread : @model.ChannelId? = None
  p.probe("start_thread_without_message (public)", () => {
    let thread = c.start_thread_without_message(
      text,
      "probe-thread-pub",
      typ=PublicThread,
      auto_archive_duration=OneDay,
    )
    public_thread = Some(thread.id)
    "id=\{thread.id}"
  })
  p.probe("ChannelRef::start_thread (private)", () => {
    let thread = c
      .channel_ref(text)
      .start_thread("probe-thread-priv", typ=PrivateThread, invitable=true)
    // Exercise membership endpoints on the private thread.
    c.add_thread_member(thread.id, p.owner_id)
    let tm = c.get_thread_member(thread.id, p.owner_id, with_member=true)
    ignore(tm)
    let members = c.list_thread_members(thread.id, with_member=true)
    c.remove_thread_member(thread.id, p.owner_id)
    let _ = c.delete_channel(thread.id)
    "members=\{members.length()}"
  })
  guard public_thread is Some(thread) else { return }
  p.probe("leave_thread / join_thread", () => {
    // The creator is auto-joined; leave then re-join.
    c.leave_thread(thread)
    c.join_thread(thread)
    "ok"
  })
  p.probe("ChannelRef::leave_thread/join_thread", () => {
    let r = c.channel_ref(thread)
    r.leave_thread()
    r.join_thread()
    "ok"
  })
  p.probe("ChannelRef::thread_members/thread_member", () => {
    let r = c.channel_ref(thread)
    let members = r.thread_members()
    let self_member = r.thread_member(p.bot_id)
    ignore(self_member)
    "members=\{members.length()}"
  })
  p.probe("modify_channel (archive thread) + ChannelRef::edit (unarchive)", () => {
    let archived = c.modify_channel(thread, archived=true)
    let back = c
      .channel_ref(thread)
      .edit(archived=false, auto_archive_duration=OneHour, locked=false)
    let again = c.modify_channel(thread, archived=true)
    ignore(back)
    ignore(again)
    "archived=\{archived.thread_metadata is Some(_)}"
  })
  p.probe("list_public_archived_threads", () => {
    let archived = c.list_public_archived_threads(text, limit=5)
    "threads=\{archived.threads.length()} has_more=\{archived.has_more}"
  })
  p.probe("list_private_archived_threads", () => {
    let archived = c.list_private_archived_threads(text, limit=5)
    "threads=\{archived.threads.length()}"
  })
  p.probe("list_joined_private_archived_threads", () => {
    let archived = c.list_joined_private_archived_threads(text, limit=5)
    "threads=\{archived.threads.length()}"
  })
  p.probe("ChannelRef archived thread listings", () => {
    let r = c.channel_ref(text)
    let a = r.public_archived_threads(limit=5)
    let b = r.private_archived_threads(limit=5)
    let d = r.joined_private_archived_threads(limit=5)
    "pub=\{a.threads.length()} priv=\{b.threads.length()} joined=\{d.threads.length()}"
  })
  p.probe("list_active_guild_threads + GuildRef::active_threads", () => {
    let active = c.list_active_guild_threads(g)
    let via_ref = c.guild_ref(g).active_threads()
    ignore(via_ref)
    "threads=\{active.threads.length()}"
  })
  p.probe("delete_channel (archived public thread)", () => {
    let ch = c.delete_channel(thread, audit_reason="live probe cleanup")
    "id=\{ch.id}"
  })
  // Forum / media threads
  p.probe("start_thread_in_forum_or_media_channel", () => {
    let forum = need(p.s.forum, "forum channel")
    let thread = c.start_thread_in_forum_or_media_channel(
      forum,
      "probe forum post",
      content="forum post body",
      auto_archive_duration=OneHour,
    )
    let _ = c.delete_channel(thread.id)
    "id=\{thread.id}"
  })
  p.probe("ChannelRef::start_forum_thread (with file)", () => {
    let forum = need(p.s.forum, "forum channel")
    let file = @dhttp.FileUpload(
      "forum.txt",
      b"forum attachment\n",
      content_type="text/plain",
    )
    let thread = c
      .channel_ref(forum)
      .start_forum_thread("probe forum post 2", content="with file", files=[
        file,
      ])
    let _ = c.delete_channel(thread.id)
    "id=\{thread.id}"
  })
}
