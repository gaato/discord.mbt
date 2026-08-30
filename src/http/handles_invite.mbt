///|
/// An invite code bound to the REST client that operates on it.
pub struct InviteRef {
  priv client : Client
  priv code : String
}

///|
/// Bind an invite code to this client.
pub fn Client::invite_ref(self : Client, code : String) -> InviteRef {
  { client: self, code, }
}

///|
/// Fetch this invite.
pub async fn InviteRef::fetch(
  self : InviteRef,
  with_counts? : Bool,
  guild_scheduled_event_id? : @model.ScheduledEventId,
) -> @model.Invite raise DiscordHttpError {
  self.client.get_invite(self.code, with_counts?, guild_scheduled_event_id?)
}

///|
/// Delete this invite.
pub async fn InviteRef::delete(
  self : InviteRef,
  reason? : String,
) -> @model.Invite raise DiscordHttpError {
  self.client.delete_invite(self.code, audit_reason?=reason)
}

///|
/// Replace this invite's target users from a CSV file.
pub async fn InviteRef::update_target_users(
  self : InviteRef,
  target_users_file : FileUpload,
) -> Unit raise DiscordHttpError {
  self.client.update_invite_target_users(self.code, target_users_file)
}

///|
/// Fetch this invite's latest target-user update job status.
pub async fn InviteRef::target_users_job_status(
  self : InviteRef,
) -> @model.TargetUsersJobStatus raise DiscordHttpError {
  self.client.get_invite_target_users_job_status(self.code)
}
