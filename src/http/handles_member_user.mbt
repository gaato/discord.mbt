///|
/// Fetch this guild member.
pub async fn MemberRef::fetch(
  self : MemberRef,
) -> @model.GuildMember raise DiscordHttpError {
  self.client.get_guild_member(self.guild_id, self.user_id)
}

///|
/// Ban this member from the guild.
pub async fn MemberRef::ban(
  self : MemberRef,
  delete_message_seconds? : Int,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.create_guild_ban(
    self.guild_id,
    self.user_id,
    delete_message_seconds?,
    audit_reason?=reason,
  )
}

///|
/// Remove this member from the guild.
pub async fn MemberRef::kick(
  self : MemberRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.remove_guild_member(
    self.guild_id,
    self.user_id,
    audit_reason?=reason,
  )
}

///|
/// Add a role to this member.
pub async fn MemberRef::add_role(
  self : MemberRef,
  role_id : @model.RoleId,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.add_member_role(
    self.guild_id,
    self.user_id,
    role_id,
    audit_reason?=reason,
  )
}

///|
/// Remove a role from this member.
pub async fn MemberRef::remove_role(
  self : MemberRef,
  role_id : @model.RoleId,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.remove_member_role(
    self.guild_id,
    self.user_id,
    role_id,
    audit_reason?=reason,
  )
}

///|
/// Set this member's communication timeout, or clear it when `until` is
/// `None`.
pub async fn MemberRef::timeout(
  self : MemberRef,
  until : @model.Timestamp?,
  reason? : String,
) -> @model.GuildMember raise DiscordHttpError {
  self.client.modify_guild_member(
    self.guild_id,
    self.user_id,
    communication_disabled_until?=until,
    clear_communication_disabled_until=until is None,
    audit_reason?=reason,
  )
}

///|
/// Edit this guild member.
pub async fn MemberRef::edit(
  self : MemberRef,
  nick? : String,
  clear_nick? : Bool = false,
  roles? : Array[@model.RoleId],
  mute? : Bool,
  deaf? : Bool,
  channel_id? : @model.ChannelId,
  clear_channel_id? : Bool = false,
  communication_disabled_until? : @model.Timestamp,
  clear_communication_disabled_until? : Bool = false,
  flags? : @model.GuildMemberFlags,
  reason? : String,
) -> @model.GuildMember raise DiscordHttpError {
  self.client.modify_guild_member(
    self.guild_id,
    self.user_id,
    nick?,
    clear_nick~,
    roles?,
    mute?,
    deaf?,
    channel_id?,
    clear_channel_id~,
    communication_disabled_until?,
    clear_communication_disabled_until~,
    flags?,
    audit_reason?=reason,
  )
}

///|
/// Remove this user's ban; the target does not need to be a current member.
pub async fn MemberRef::unban(
  self : MemberRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.remove_guild_ban(
    self.guild_id,
    self.user_id,
    audit_reason?=reason,
  )
}

///|
/// Fetch this user's voice state in the guild.
pub async fn MemberRef::voice_state(
  self : MemberRef,
) -> @model.VoiceState raise DiscordHttpError {
  self.client.get_user_voice_state(self.guild_id, self.user_id)
}

///|
/// Edit this user's voice state in the guild.
pub async fn MemberRef::edit_voice_state(
  self : MemberRef,
  channel_id : @model.ChannelId,
  suppress? : Bool,
) -> Unit raise DiscordHttpError {
  self.client.modify_user_voice_state(
    self.guild_id,
    self.user_id,
    channel_id,
    suppress?,
  )
}

///|
/// Fetch this user.
pub async fn UserRef::fetch(
  self : UserRef,
) -> @model.User raise DiscordHttpError {
  self.client.get_user(self.user_id)
}

///|
/// List this user's external identities for an application.
pub async fn UserRef::application_identities(
  self : UserRef,
  application_id~ : @model.ApplicationId,
) -> Array[@model.ApplicationIdentity] raise DiscordHttpError {
  self.client.get_application_identities_by_user_id(
    user_id=self.user_id,
    application_id~,
  )
}

///|
/// Bind one application identity belonging to this user.
pub fn UserRef::application_identity_ref(
  self : UserRef,
  application_id~ : @model.ApplicationId,
  provider_type~ : String,
  provider_issued_user_id~ : String,
) -> ApplicationIdentityRef {
  self.client.application_identity_ref(
    application_id~,
    user_id=self.user_id,
    provider_type~,
    provider_issued_user_id~,
  )
}

///|
/// Open or reuse a DM channel with this user and bind it to the client.
pub async fn UserRef::dm(self : UserRef) -> ChannelRef raise DiscordHttpError {
  let channel = self.client.create_dm(self.user_id)
  self.client.channel_ref(channel.id)
}
