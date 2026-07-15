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
