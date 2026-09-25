///|
/// Fetch this channel.
pub async fn ChannelRef::fetch(
  self : ChannelRef,
) -> @model.Channel raise DiscordHttpError {
  self.client.get_channel(self.channel_id)
}

///|
/// Send a message to this channel.
pub async fn ChannelRef::send(
  self : ChannelRef,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  sticker_ids? : Array[@model.StickerId],
  files? : Array[FileUpload],
  reply_to? : @model.MessageId,
  tts? : Bool,
  flags? : @model.MessageFlags,
  allowed_mentions? : @model.AllowedMentions,
  nonce? : @model.Nonce,
  enforce_nonce? : Bool,
  poll? : @model.PollCreateRequest,
  message_reference? : @model.MessageReference,
  shared_client_theme? : @model.SharedClientTheme,
) -> @model.Message raise DiscordHttpError {
  self.client.create_message(
    self.channel_id,
    content?,
    embeds?,
    components?,
    sticker_ids?,
    files?,
    reply_to?,
    tts?,
    flags?,
    allowed_mentions?,
    nonce?,
    enforce_nonce?,
    poll?,
    message_reference?,
    shared_client_theme?,
  )
}

///|
/// Paginate messages in this channel.
pub fn ChannelRef::messages(
  self : ChannelRef,
  before? : @model.MessageId,
  after? : @model.MessageId,
  around? : @model.MessageId,
  page_size? : Int = 100,
) -> Paginator[@model.Message] raise DiscordHttpError {
  self.client.paginate_messages(
    self.channel_id,
    before?,
    after?,
    around?,
    page_size~,
  )
}

///|
/// Trigger the typing indicator in this channel.
pub async fn ChannelRef::typing(
  self : ChannelRef,
) -> Unit raise DiscordHttpError {
  self.client.trigger_typing(self.channel_id)
}

///|
/// Run an asynchronous operation while keeping this channel's typing
/// indicator active.
///
/// A typing request is sent immediately, then refreshed every 8 seconds while
/// `body` runs because Discord's indicator expires after 10 seconds. Failure
/// of the initial request is raised and prevents `body` from running. Failure
/// of a later keepalive request only stops further refreshes. When `body`
/// returns or raises, the keepalive task is cancelled and its result or error
/// is propagated unchanged.
///
/// ```mbt nocheck
/// let answer = channel.with_typing(() => call_llm(prompt))
/// channel.send(content=answer)
/// ```
pub async fn[T] ChannelRef::with_typing(
  self : ChannelRef,
  body : async () -> T,
) -> T {
  self.typing()
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      for ;; {
        @async.sleep(8000)
        self.typing() catch {
          _ => break
        }
      }
    })
    body()
  })
}

///|
/// Bind a message id in this channel to the client.
pub fn ChannelRef::message_ref(
  self : ChannelRef,
  message_id : @model.MessageId,
) -> MessageRef {
  { client: self.client, channel_id: self.channel_id, message_id, }
}

///|
/// Edit this channel. The `archived`/`auto_archive_duration`/`locked`/
/// `invitable`/`applied_tags` knobs only apply when this channel is a thread.
pub async fn ChannelRef::edit(
  self : ChannelRef,
  name? : String,
  typ? : @model.ChannelType,
  topic? : String,
  clear_topic? : Bool = false,
  nsfw? : Bool,
  parent_id? : @model.ChannelId,
  clear_parent_id? : Bool = false,
  rate_limit_per_user? : Int,
  position? : Int,
  bitrate? : Int,
  user_limit? : Int,
  permission_overwrites? : Array[@model.Overwrite],
  rtc_region? : String,
  clear_rtc_region? : Bool = false,
  video_quality_mode? : @model.VideoQualityMode,
  clear_video_quality_mode? : Bool = false,
  default_auto_archive_duration? : @model.ThreadAutoArchiveDuration,
  available_tags? : Array[@model.ForumTagRequest],
  default_reaction_emoji? : @model.DefaultReaction,
  clear_default_reaction_emoji? : Bool = false,
  default_thread_rate_limit_per_user? : Int,
  default_sort_order? : @model.SortOrderType,
  clear_default_sort_order? : Bool = false,
  default_forum_layout? : @model.ForumLayoutType,
  icon? : String,
  flags? : @model.ChannelFlags,
  archived? : Bool,
  auto_archive_duration? : @model.ThreadAutoArchiveDuration,
  locked? : Bool,
  invitable? : Bool,
  applied_tags? : Array[@model.GenericId],
  reason? : String,
) -> @model.Channel raise DiscordHttpError {
  self.client.modify_channel(
    self.channel_id,
    name?,
    typ?,
    topic?,
    clear_topic~,
    nsfw?,
    parent_id?,
    clear_parent_id~,
    rate_limit_per_user?,
    position?,
    bitrate?,
    user_limit?,
    permission_overwrites?,
    rtc_region?,
    clear_rtc_region~,
    video_quality_mode?,
    clear_video_quality_mode~,
    default_auto_archive_duration?,
    available_tags?,
    default_reaction_emoji?,
    clear_default_reaction_emoji~,
    default_thread_rate_limit_per_user?,
    default_sort_order?,
    clear_default_sort_order~,
    default_forum_layout?,
    icon?,
    flags?,
    archived?,
    auto_archive_duration?,
    locked?,
    invitable?,
    applied_tags?,
    audit_reason?=reason,
  )
}

///|
/// Delete or close this channel.
pub async fn ChannelRef::delete(
  self : ChannelRef,
  reason? : String,
) -> @model.Channel raise DiscordHttpError {
  self.client.delete_channel(self.channel_id, audit_reason?=reason)
}

///|
/// List every pinned message in this channel.
pub async fn ChannelRef::pins(
  self : ChannelRef,
) -> Array[@model.Message] raise DiscordHttpError {
  self.client.get_pinned_messages(self.channel_id)
}

///|
/// Fetch one page from Discord's current paginated channel-pins endpoint.
pub async fn ChannelRef::pins_page(
  self : ChannelRef,
  before? : @model.Timestamp,
  limit? : Int,
) -> @model.ChannelPins raise DiscordHttpError {
  self.client.get_channel_pins(self.channel_id, before?, limit?)
}

///|
/// List invites created for this channel.
pub async fn ChannelRef::invites(
  self : ChannelRef,
) -> Array[@model.Invite] raise DiscordHttpError {
  self.client.get_channel_invites(self.channel_id)
}

///|
/// Create an incoming webhook for this channel.
pub async fn ChannelRef::create_webhook(
  self : ChannelRef,
  name : String,
  avatar? : String,
  reason? : String,
) -> @model.Webhook raise DiscordHttpError {
  self.client.create_webhook(
    self.channel_id,
    name,
    avatar?,
    audit_reason?=reason,
  )
}

///|
/// List webhooks created for this channel.
pub async fn ChannelRef::webhooks(
  self : ChannelRef,
) -> Array[@model.Webhook] raise DiscordHttpError {
  self.client.get_channel_webhooks(self.channel_id)
}

///|
/// Create an invite for this channel.
pub async fn ChannelRef::create_invite(
  self : ChannelRef,
  max_age? : Int,
  max_uses? : Int,
  temporary? : Bool,
  unique? : Bool,
  target_type? : @model.InviteTargetType,
  target_user_id? : @model.UserId,
  target_application_id? : @model.ApplicationId,
  role_ids? : Array[@model.RoleId],
  target_user_ids? : Array[@model.UserId],
  target_users_file? : FileUpload,
  reason? : String,
) -> @model.Invite raise DiscordHttpError {
  self.client.create_channel_invite(
    self.channel_id,
    max_age?,
    max_uses?,
    temporary?,
    unique?,
    target_type?,
    target_user_id?,
    target_application_id?,
    role_ids?,
    target_user_ids?,
    target_users_file?,
    audit_reason?=reason,
  )
}

///|
/// Create or replace a permission overwrite for this channel.
pub async fn ChannelRef::edit_permissions(
  self : ChannelRef,
  overwrite_id : @model.GenericId,
  typ : @model.OverwriteType,
  allow? : @model.Permissions,
  deny? : @model.Permissions,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.edit_channel_permissions(
    self.channel_id,
    overwrite_id,
    typ,
    allow?,
    deny?,
    audit_reason?=reason,
  )
}

///|
/// Delete a permission overwrite from this channel.
pub async fn ChannelRef::delete_permission(
  self : ChannelRef,
  overwrite_id : @model.GenericId,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_channel_permission(
    self.channel_id,
    overwrite_id,
    audit_reason?=reason,
  )
}

///|
/// Follow this announcement channel. `webhook_channel_id` is the target
/// channel that receives messages and requires `MANAGE_WEBHOOKS` there.
pub async fn ChannelRef::follow(
  self : ChannelRef,
  webhook_channel_id : @model.ChannelId,
  reason? : String,
) -> @model.FollowedChannel raise DiscordHttpError {
  self.client.follow_announcement_channel(
    self.channel_id,
    webhook_channel_id,
    audit_reason?=reason,
  )
}

///|
/// Set this voice channel's status, or clear it by omitting `status`.
pub async fn ChannelRef::set_voice_status(
  self : ChannelRef,
  status? : String,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.set_voice_channel_status(
    self.channel_id,
    status?,
    audit_reason?=reason,
  )
}

///|
/// Add a user to this group DM.
pub async fn ChannelRef::group_dm_add_recipient(
  self : ChannelRef,
  user_id : @model.UserId,
  access_token : String,
  nick? : String,
) -> Unit raise DiscordHttpError {
  self.client.group_dm_add_recipient(
    self.channel_id,
    user_id,
    access_token,
    nick?,
  )
}

///|
/// Remove a user from this group DM.
pub async fn ChannelRef::group_dm_remove_recipient(
  self : ChannelRef,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.client.group_dm_remove_recipient(self.channel_id, user_id)
}

///|
/// Join the current user to this channel. This channel must be a thread.
pub async fn ChannelRef::join_thread(
  self : ChannelRef,
) -> Unit raise DiscordHttpError {
  self.client.join_thread(self.channel_id)
}

///|
/// Remove the current user from this channel. This channel must be a thread.
pub async fn ChannelRef::leave_thread(
  self : ChannelRef,
) -> Unit raise DiscordHttpError {
  self.client.leave_thread(self.channel_id)
}

///|
/// Add a user to this channel. This channel must be a thread.
pub async fn ChannelRef::add_thread_member(
  self : ChannelRef,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.client.add_thread_member(self.channel_id, user_id)
}

///|
/// Remove a user from this channel. This channel must be a thread.
pub async fn ChannelRef::remove_thread_member(
  self : ChannelRef,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.client.remove_thread_member(self.channel_id, user_id)
}

///|
/// Fetch a user's membership record. This channel must be a thread.
pub async fn ChannelRef::thread_member(
  self : ChannelRef,
  user_id : @model.UserId,
  with_member? : Bool,
) -> @model.ThreadMember raise DiscordHttpError {
  self.client.get_thread_member(self.channel_id, user_id, with_member?)
}

///|
/// List this channel's members. This channel must be a thread.
pub async fn ChannelRef::thread_members(
  self : ChannelRef,
  with_member? : Bool,
  after? : @model.UserId,
  limit? : Int,
) -> Array[@model.ThreadMember] raise DiscordHttpError {
  self.client.list_thread_members(self.channel_id, with_member?, after?, limit?)
}

///|
/// List public archived threads in this channel.
pub async fn ChannelRef::public_archived_threads(
  self : ChannelRef,
  before? : @model.Timestamp,
  limit? : Int,
) -> @model.ArchivedThreads raise DiscordHttpError {
  self.client.list_public_archived_threads(self.channel_id, before?, limit?)
}

///|
/// List private archived threads in this channel.
pub async fn ChannelRef::private_archived_threads(
  self : ChannelRef,
  before? : @model.Timestamp,
  limit? : Int,
) -> @model.ArchivedThreads raise DiscordHttpError {
  self.client.list_private_archived_threads(self.channel_id, before?, limit?)
}

///|
/// List private archived threads in this channel joined by the current user.
pub async fn ChannelRef::joined_private_archived_threads(
  self : ChannelRef,
  before? : @model.ChannelId,
  limit? : Int,
) -> @model.ArchivedThreads raise DiscordHttpError {
  self.client.list_joined_private_archived_threads(
    self.channel_id,
    before?,
    limit?,
  )
}

///|
/// Start a thread in this channel without attaching it to a message.
pub async fn ChannelRef::start_thread(
  self : ChannelRef,
  name : String,
  typ? : @model.ChannelType,
  auto_archive_duration? : @model.ThreadAutoArchiveDuration,
  invitable? : Bool,
  rate_limit_per_user? : Int,
  reason? : String,
) -> @model.Channel raise DiscordHttpError {
  self.client.start_thread_without_message(
    self.channel_id,
    name,
    typ?,
    auto_archive_duration?,
    invitable?,
    rate_limit_per_user?,
    audit_reason?=reason,
  )
}

///|
/// Start a thread with a starter message in this forum or media channel.
pub async fn ChannelRef::start_forum_thread(
  self : ChannelRef,
  name : String,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  sticker_ids? : Array[@model.StickerId],
  files? : Array[FileUpload],
  flags? : @model.MessageFlags,
  allowed_mentions? : @model.AllowedMentions,
  auto_archive_duration? : @model.ThreadAutoArchiveDuration,
  rate_limit_per_user? : Int,
  applied_tags? : Array[@model.GenericId],
  reason? : String,
) -> @model.Channel raise DiscordHttpError {
  self.client.start_thread_in_forum_or_media_channel(
    self.channel_id,
    name,
    content?,
    embeds?,
    components?,
    sticker_ids?,
    files?,
    flags?,
    allowed_mentions?,
    auto_archive_duration?,
    rate_limit_per_user?,
    applied_tags?,
    audit_reason?=reason,
  )
}

///|
/// Delete between 2 and 100 messages from this channel.
pub async fn ChannelRef::bulk_delete(
  self : ChannelRef,
  messages : Array[@model.MessageId],
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.bulk_delete_messages(
    self.channel_id,
    messages,
    audit_reason?=reason,
  )
}

///|
/// Play a soundboard sound in this voice channel.
pub async fn ChannelRef::send_soundboard_sound(
  self : ChannelRef,
  sound_id : @model.SoundboardSoundId,
  source_guild_id? : @model.GuildId,
) -> Unit raise DiscordHttpError {
  self.client.send_soundboard_sound(self.channel_id, sound_id, source_guild_id?)
}

///|
/// Create a stage instance. This channel must be a stage channel.
pub async fn ChannelRef::create_stage_instance(
  self : ChannelRef,
  topic : String,
  privacy_level? : @model.StagePrivacyLevel,
  send_start_notification? : Bool,
  guild_scheduled_event_id? : @model.ScheduledEventId,
  reason? : String,
) -> @model.StageInstance raise DiscordHttpError {
  self.client.create_stage_instance(
    self.channel_id,
    topic,
    privacy_level?,
    send_start_notification?,
    guild_scheduled_event_id?,
    audit_reason?=reason,
  )
}

///|
/// Fetch the stage instance. This channel must be a stage channel.
pub async fn ChannelRef::stage_instance(
  self : ChannelRef,
) -> @model.StageInstance raise DiscordHttpError {
  self.client.get_stage_instance(self.channel_id)
}

///|
/// Edit the stage instance. This channel must be a stage channel.
pub async fn ChannelRef::edit_stage_instance(
  self : ChannelRef,
  topic? : String,
  privacy_level? : @model.StagePrivacyLevel,
  reason? : String,
) -> @model.StageInstance raise DiscordHttpError {
  self.client.modify_stage_instance(
    self.channel_id,
    topic?,
    privacy_level?,
    audit_reason?=reason,
  )
}

///|
/// Delete the stage instance. This channel must be a stage channel.
pub async fn ChannelRef::delete_stage_instance(
  self : ChannelRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_stage_instance(self.channel_id, audit_reason?=reason)
}
