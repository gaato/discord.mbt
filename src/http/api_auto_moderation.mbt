///|
fn validate_auto_moderation_rule(
  name : String?,
  actions : Array[@model.AutoModerationAction]?,
  exempt_roles : Array[@model.RoleId]?,
  exempt_channels : Array[@model.ChannelId]?,
) -> Unit raise DiscordHttpError {
  if name is Some(value) && (value.length() < 1 || value.length() > 100) {
    raise DiscordHttpError::Validation(
      message="auto moderation rule name must be 1 through 100 characters",
    )
  }
  if actions is Some(value) && (value.length() < 1 || value.length() > 3) {
    raise DiscordHttpError::Validation(
      message="auto moderation actions must contain 1 through 3 entries",
    )
  }
  if exempt_roles is Some(value) && value.length() > 20 {
    raise DiscordHttpError::Validation(
      message="auto moderation exempt_roles exceeds 20 entries",
    )
  }
  if exempt_channels is Some(value) && value.length() > 50 {
    raise DiscordHttpError::Validation(
      message="auto moderation exempt_channels exceeds 50 entries",
    )
  }
}

///|
fn auto_moderation_rule_body(
  name : String?,
  event_type : @model.AutoModerationEventType?,
  trigger_type : @model.AutoModerationTriggerType?,
  trigger_metadata : @model.TriggerMetadata?,
  actions : Array[@model.AutoModerationAction]?,
  enabled : Bool?,
  exempt_roles : Array[@model.RoleId]?,
  exempt_channels : Array[@model.ChannelId]?,
) -> Json raise DiscordHttpError {
  validate_auto_moderation_rule(name, actions, exempt_roles, exempt_channels)
  @model.ObjBuilder::new()
  .opt("name", name)
  .opt("event_type", event_type)
  .opt("trigger_type", trigger_type)
  .opt("trigger_metadata", trigger_metadata)
  .opt("actions", actions)
  .opt("enabled", enabled)
  .opt("exempt_roles", exempt_roles)
  .opt("exempt_channels", exempt_channels)
  .build()
}

///|
/// List every auto-moderation rule configured for a guild.
pub async fn Client::list_auto_moderation_rules(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.AutoModerationRule] raise DiscordHttpError {
  decode(self.request(Route::ListAutoModerationRules(guild_id~)))
}

///|
/// Fetch one auto-moderation rule.
pub async fn Client::get_auto_moderation_rule(
  self : Client,
  guild_id : @model.GuildId,
  rule_id : @model.AutoModerationRuleId,
) -> @model.AutoModerationRule raise DiscordHttpError {
  decode(self.request(Route::GetAutoModerationRule(guild_id~, rule_id~)))
}

///|
/// Create an auto-moderation rule.
pub async fn Client::create_auto_moderation_rule(
  self : Client,
  guild_id : @model.GuildId,
  name : String,
  event_type : @model.AutoModerationEventType,
  trigger_type : @model.AutoModerationTriggerType,
  trigger_metadata : @model.TriggerMetadata,
  actions : Array[@model.AutoModerationAction],
  enabled? : Bool,
  exempt_roles? : Array[@model.RoleId],
  exempt_channels? : Array[@model.ChannelId],
  audit_reason? : String,
) -> @model.AutoModerationRule raise DiscordHttpError {
  let body = auto_moderation_rule_body(
    Some(name),
    Some(event_type),
    Some(trigger_type),
    Some(trigger_metadata),
    Some(actions),
    enabled,
    exempt_roles,
    exempt_channels,
  )
  decode(
    self.request(
      Route::CreateAutoModerationRule(guild_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Modify an auto-moderation rule. Empty exempt arrays clear those fields.
pub async fn Client::modify_auto_moderation_rule(
  self : Client,
  guild_id : @model.GuildId,
  rule_id : @model.AutoModerationRuleId,
  name? : String,
  event_type? : @model.AutoModerationEventType,
  trigger_metadata? : @model.TriggerMetadata,
  actions? : Array[@model.AutoModerationAction],
  enabled? : Bool,
  exempt_roles? : Array[@model.RoleId],
  exempt_channels? : Array[@model.ChannelId],
  audit_reason? : String,
) -> @model.AutoModerationRule raise DiscordHttpError {
  let body = auto_moderation_rule_body(
    name,
    event_type,
    None,
    trigger_metadata,
    actions,
    enabled,
    exempt_roles,
    exempt_channels,
  )
  decode(
    self.request(
      Route::ModifyAutoModerationRule(guild_id~, rule_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Delete an auto-moderation rule.
pub async fn Client::delete_auto_moderation_rule(
  self : Client,
  guild_id : @model.GuildId,
  rule_id : @model.AutoModerationRuleId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(
    Route::DeleteAutoModerationRule(guild_id~, rule_id~),
    audit_reason?,
  )
  |> ignore
}
