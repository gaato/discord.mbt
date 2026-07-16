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
/// Fetch this user.
pub async fn UserRef::fetch(
  self : UserRef,
) -> @model.User raise DiscordHttpError {
  self.client.get_user(self.user_id)
}

///|
/// Open or reuse a DM channel with this user and bind it to the client.
pub async fn UserRef::dm(self : UserRef) -> ChannelRef raise DiscordHttpError {
  let channel = self.client.create_dm(self.user_id)
  self.client.channel_ref(channel.id)
}
