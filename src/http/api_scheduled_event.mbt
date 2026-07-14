///|
fn validate_scheduled_event_text(
  name : String?,
  description : String?,
) -> Unit raise DiscordHttpError {
  if name is Some(value) && (value.length() < 1 || value.length() > 100) {
    raise DiscordHttpError::Validation(
      message="scheduled event name must be 1 through 100 characters",
    )
  }
  if description is Some(value) && value.length() > 1000 {
    raise DiscordHttpError::Validation(
      message="scheduled event description exceeds 1000 characters",
    )
  }
}

///|
fn scheduled_event_create_body(
  channel_id : @model.ChannelId?,
  clear_channel_id : Bool,
  entity_metadata : @model.EntityMetadata?,
  clear_entity_metadata : Bool,
  name : String,
  privacy_level : @model.GuildScheduledEventPrivacyLevel,
  scheduled_start_time : @model.Timestamp,
  scheduled_end_time : @model.Timestamp?,
  clear_scheduled_end_time : Bool,
  description : String?,
  entity_type : @model.GuildScheduledEventEntityType,
  image : String?,
  recurrence_rule : @model.GuildScheduledEventRecurrenceRule?,
) -> Json raise DiscordHttpError {
  validate_scheduled_event_text(Some(name), description)
  @model.ObjBuilder::new()
  .und("channel_id", patch_nullable("channel_id", channel_id, clear_channel_id))
  .und(
    "entity_metadata",
    patch_nullable("entity_metadata", entity_metadata, clear_entity_metadata),
  )
  .field("name", name)
  .field("privacy_level", privacy_level)
  .field("scheduled_start_time", scheduled_start_time)
  .und(
    "scheduled_end_time",
    patch_nullable(
      "scheduled_end_time", scheduled_end_time, clear_scheduled_end_time,
    ),
  )
  .opt("description", description)
  .field("entity_type", entity_type)
  .opt("image", image)
  .opt("recurrence_rule", recurrence_rule)
  .build()
}

///|
fn scheduled_event_modify_body(
  channel_id : @model.ChannelId?,
  clear_channel_id : Bool,
  entity_metadata : @model.EntityMetadata?,
  clear_entity_metadata : Bool,
  name : String?,
  privacy_level : @model.GuildScheduledEventPrivacyLevel?,
  scheduled_start_time : @model.Timestamp?,
  scheduled_end_time : @model.Timestamp?,
  clear_scheduled_end_time : Bool,
  description : String?,
  clear_description : Bool,
  entity_type : @model.GuildScheduledEventEntityType?,
  status : @model.GuildScheduledEventStatus?,
  image : String?,
  clear_image : Bool,
  recurrence_rule : @model.GuildScheduledEventRecurrenceRule?,
  clear_recurrence_rule : Bool,
) -> Json raise DiscordHttpError {
  validate_scheduled_event_text(name, description)
  @model.ObjBuilder::new()
  .und("channel_id", patch_nullable("channel_id", channel_id, clear_channel_id))
  .und(
    "entity_metadata",
    patch_nullable("entity_metadata", entity_metadata, clear_entity_metadata),
  )
  .opt("name", name)
  .opt("privacy_level", privacy_level)
  .opt("scheduled_start_time", scheduled_start_time)
  .und(
    "scheduled_end_time",
    patch_nullable(
      "scheduled_end_time", scheduled_end_time, clear_scheduled_end_time,
    ),
  )
  .und(
    "description",
    patch_nullable("description", description, clear_description),
  )
  .opt("entity_type", entity_type)
  .opt("status", status)
  .und("image", patch_nullable("image", image, clear_image))
  .und(
    "recurrence_rule",
    patch_nullable("recurrence_rule", recurrence_rule, clear_recurrence_rule),
  )
  .build()
}

///|
/// List scheduled events in a guild.
pub async fn Client::list_guild_scheduled_events(
  self : Client,
  guild_id : @model.GuildId,
  with_user_count? : Bool,
) -> Array[@model.GuildScheduledEvent] raise DiscordHttpError {
  let query = match with_user_count {
    Some(value) => "?with_user_count=\{value}"
    None => ""
  }
  decode(self.request(Route::ListGuildScheduledEvents(guild_id~, query~)))
}

///|
/// Create a scheduled event. Use `clear_channel_id=true` for an external event.
pub async fn Client::create_guild_scheduled_event(
  self : Client,
  guild_id : @model.GuildId,
  name : String,
  privacy_level : @model.GuildScheduledEventPrivacyLevel,
  scheduled_start_time : @model.Timestamp,
  entity_type : @model.GuildScheduledEventEntityType,
  channel_id? : @model.ChannelId,
  clear_channel_id? : Bool = false,
  entity_metadata? : @model.EntityMetadata,
  clear_entity_metadata? : Bool = false,
  scheduled_end_time? : @model.Timestamp,
  clear_scheduled_end_time? : Bool = false,
  description? : String,
  image? : String,
  recurrence_rule? : @model.GuildScheduledEventRecurrenceRule,
  audit_reason? : String,
) -> @model.GuildScheduledEvent raise DiscordHttpError {
  let body = scheduled_event_create_body(
    channel_id, clear_channel_id, entity_metadata, clear_entity_metadata, name, privacy_level,
    scheduled_start_time, scheduled_end_time, clear_scheduled_end_time, description,
    entity_type, image, recurrence_rule,
  )
  decode(
    self.request(
      Route::CreateGuildScheduledEvent(guild_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Fetch one scheduled event.
pub async fn Client::get_guild_scheduled_event(
  self : Client,
  guild_id : @model.GuildId,
  event_id : @model.ScheduledEventId,
  with_user_count? : Bool,
) -> @model.GuildScheduledEvent raise DiscordHttpError {
  let query = match with_user_count {
    Some(value) => "?with_user_count=\{value}"
    None => ""
  }
  decode(
    self.request(Route::GetGuildScheduledEvent(guild_id~, event_id~, query~)),
  )
}

///|
/// Modify a scheduled event.
pub async fn Client::modify_guild_scheduled_event(
  self : Client,
  guild_id : @model.GuildId,
  event_id : @model.ScheduledEventId,
  channel_id? : @model.ChannelId,
  clear_channel_id? : Bool = false,
  entity_metadata? : @model.EntityMetadata,
  clear_entity_metadata? : Bool = false,
  name? : String,
  privacy_level? : @model.GuildScheduledEventPrivacyLevel,
  scheduled_start_time? : @model.Timestamp,
  scheduled_end_time? : @model.Timestamp,
  clear_scheduled_end_time? : Bool = false,
  description? : String,
  clear_description? : Bool = false,
  entity_type? : @model.GuildScheduledEventEntityType,
  status? : @model.GuildScheduledEventStatus,
  image? : String,
  clear_image? : Bool = false,
  recurrence_rule? : @model.GuildScheduledEventRecurrenceRule,
  clear_recurrence_rule? : Bool = false,
  audit_reason? : String,
) -> @model.GuildScheduledEvent raise DiscordHttpError {
  let body = scheduled_event_modify_body(
    channel_id, clear_channel_id, entity_metadata, clear_entity_metadata, name, privacy_level,
    scheduled_start_time, scheduled_end_time, clear_scheduled_end_time, description,
    clear_description, entity_type, status, image, clear_image, recurrence_rule,
    clear_recurrence_rule,
  )
  decode(
    self.request(
      Route::ModifyGuildScheduledEvent(guild_id~, event_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Delete a scheduled event.
pub async fn Client::delete_guild_scheduled_event(
  self : Client,
  guild_id : @model.GuildId,
  event_id : @model.ScheduledEventId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(
    Route::DeleteGuildScheduledEvent(guild_id~, event_id~),
    audit_reason?,
  )
  |> ignore
}

///|
/// List users interested in a scheduled event.
pub async fn Client::list_guild_scheduled_event_users(
  self : Client,
  guild_id : @model.GuildId,
  event_id : @model.ScheduledEventId,
  limit? : Int,
  with_member? : Bool,
  before? : @model.UserId,
  after? : @model.UserId,
) -> Array[@model.GuildScheduledEventUser] raise DiscordHttpError {
  if limit is Some(value) && (value < 1 || value > 100) {
    raise DiscordHttpError::Validation(
      message="scheduled event user limit must be 1 through 100",
    )
  }
  let params : Array[String] = []
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if with_member is Some(value) {
    params.push("with_member=\{value}")
  }
  if before is Some(value) {
    params.push("before=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(
    self.request(
      Route::ListGuildScheduledEventUsers(guild_id~, event_id~, query~),
    ),
  )
}
