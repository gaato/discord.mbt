///|
/// Fetch an invite by code, optionally requesting approximate counts or a
/// scheduled-event association. (`with_expiration` no longer exists in the
/// API; `expires_at` is always part of the invite object.)
pub async fn Client::get_invite(
  self : Client,
  code : String,
  with_counts? : Bool,
  guild_scheduled_event_id? : @model.ScheduledEventId,
) -> @model.Invite raise DiscordHttpError {
  let params : Array[String] = []
  if with_counts is Some(value) {
    params.push("with_counts=\{value}")
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

///|
/// Add one user to an invite's target users. The caller must be the inviter or
/// have the `MANAGE_GUILD` permission.
pub async fn Client::add_invite_target_user(
  self : Client,
  code : String,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.request(AddInviteTargetUser(code~, user_id~)) |> ignore
}

///|
/// Remove one user from an invite's target users. The caller must be the
/// inviter or have the `MANAGE_GUILD` permission.
pub async fn Client::remove_invite_target_user(
  self : Client,
  code : String,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.request(RemoveInviteTargetUser(code~, user_id~)) |> ignore
}

///|
fn invite_target_users_body(
  user_ids : Array[@model.UserId],
) -> Json raise DiscordHttpError {
  if user_ids.length() > 1000 {
    raise Validation(message="invite target users exceed 1000 users")
  }
  @model.ObjBuilder().field("user_ids", user_ids).build()
}

///|
/// Add up to 1000 users to an invite's target users. The caller must be the
/// inviter or have the `MANAGE_GUILD` permission.
pub async fn Client::bulk_add_invite_target_users(
  self : Client,
  code : String,
  user_ids : Array[@model.UserId],
) -> Unit raise DiscordHttpError {
  let body = invite_target_users_body(user_ids)
  self.request(BulkAddInviteTargetUsers(code~), body~) |> ignore
}

///|
/// Remove up to 1000 users from an invite's target users. The caller must be
/// the inviter or have the `MANAGE_GUILD` permission.
pub async fn Client::bulk_delete_invite_target_users(
  self : Client,
  code : String,
  user_ids : Array[@model.UserId],
) -> Unit raise DiscordHttpError {
  let body = invite_target_users_body(user_ids)
  self.request(BulkDeleteInviteTargetUsers(code~), body~) |> ignore
}
