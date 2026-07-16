///|
/// Fetch an invite by code, optionally requesting approximate counts,
/// expiration data, or a scheduled-event association.
pub async fn Client::get_invite(
  self : Client,
  code : String,
  with_counts? : Bool,
  with_expiration? : Bool,
  guild_scheduled_event_id? : @model.ScheduledEventId,
) -> @model.Invite raise DiscordHttpError {
  let params : Array[String] = []
  if with_counts is Some(value) {
    params.push("with_counts=\{value}")
  }
  if with_expiration is Some(value) {
    params.push("with_expiration=\{value}")
  }
  if guild_scheduled_event_id is Some(value) {
    params.push("guild_scheduled_event_id=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(GetInvite(code~, query~)))
}

///|
/// Delete an invite by code.
pub async fn Client::delete_invite(
  self : Client,
  code : String,
  audit_reason? : String,
) -> @model.Invite raise DiscordHttpError {
  decode(self.request(DeleteInvite(code~), audit_reason?))
}

///|
/// Replace an invite's target users from a CSV file with one `user_id` column.
/// The caller must be the inviter or have the `MANAGE_GUILD` permission.
pub async fn Client::update_invite_target_users(
  self : Client,
  code : String,
  target_users_file : FileUpload,
) -> Unit raise DiscordHttpError {
  self.request(UpdateInviteTargetUsers(code~), files=[target_users_file])
  |> ignore
}

///|
/// Fetch the status of the latest target-user update for an invite.
/// The caller must be the inviter or have the `MANAGE_GUILD` or
/// `VIEW_AUDIT_LOG` permission.
pub async fn Client::get_invite_target_users_job_status(
  self : Client,
  code : String,
) -> @model.TargetUsersJobStatus raise DiscordHttpError {
  decode(self.request(GetInviteTargetUsersJobStatus(code~)))
}
