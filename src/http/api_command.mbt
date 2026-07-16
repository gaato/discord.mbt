///|
/// `description` is required for CHAT_INPUT commands (the default type) and
/// must be omitted for the UI-based types.
fn validate_command_text(
  name : String,
  description : String?,
  typ : @model.ApplicationCommandType?,
) -> Unit raise DiscordHttpError {
  validate_length("command name", Some(name), min=1, max=32)
  validate_length("command description", description, max=100)
  if description is None && (typ is None || typ is Some(ChatInput)) {
    raise Validation(message="description is required for CHAT_INPUT commands")
  }
}

///|
fn validate_command_patch(
  name : String?,
  description : String?,
) -> Unit raise DiscordHttpError {
  validate_length("command name", name, min=1, max=32)
  validate_length("command description", description, max=100)
}

///|
/// `integration_types`, `contexts`, and `handler` only exist on global
/// commands; the guild wrappers pass `None`.
fn command_body(
  name : String,
  description : String?,
  options : Array[@model.CommandOption]?,
  typ : @model.ApplicationCommandType?,
  default_member_permissions : @model.Permissions?,
  clear_default_member_permissions : Bool,
  nsfw : Bool?,
  name_localizations : Map[String, String]?,
  description_localizations : Map[String, String]?,
  integration_types : Array[@model.ApplicationIntegrationType]?,
  contexts : Array[@model.InteractionContextType]?,
  handler : @model.EntryPointCommandHandlerType?,
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .field("name", name)
  .opt("name_localizations", name_localizations)
  .opt("description", description)
  .opt("description_localizations", description_localizations)
  .opt("options", options)
  .opt("type", typ)
  .und(
    "default_member_permissions",
    patch_nullable(
      "default_member_permissions", default_member_permissions, clear_default_member_permissions,
    ),
  )
  .opt("nsfw", nsfw)
  .opt("integration_types", integration_types)
  .opt("contexts", contexts)
  .opt("handler", handler)
  .build()
}

///|
fn command_patch_body(
  name : String?,
  description : String?,
  options : Array[@model.CommandOption]?,
  default_member_permissions : @model.Permissions?,
  clear_default_member_permissions : Bool,
  nsfw : Bool?,
  name_localizations : Map[String, String]?,
  clear_name_localizations : Bool,
  description_localizations : Map[String, String]?,
  clear_description_localizations : Bool,
  integration_types : Array[@model.ApplicationIntegrationType]?,
  contexts : Array[@model.InteractionContextType]?,
  handler : @model.EntryPointCommandHandlerType?,
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .opt("name", name)
  .und(
    "name_localizations",
    patch_nullable(
      "name_localizations", name_localizations, clear_name_localizations,
    ),
  )
  .opt("description", description)
  .und(
    "description_localizations",
    patch_nullable(
      "description_localizations", description_localizations, clear_description_localizations,
    ),
  )
  .und("options", patch_value(options))
  .und(
    "default_member_permissions",
    patch_nullable(
      "default_member_permissions", default_member_permissions, clear_default_member_permissions,
    ),
  )
  .opt("nsfw", nsfw)
  .opt("integration_types", integration_types)
  .opt("contexts", contexts)
  .opt("handler", handler)
  .build()
}

///|
fn command_list_query(with_localizations : Bool?) -> String {
  match with_localizations {
    Some(value) => "?with_localizations=\{value}"
    None => ""
  }
}

///|
fn validate_bulk_commands(commands : Json) -> Unit raise DiscordHttpError {
  if !(commands is Array(_)) {
    raise Validation(message="bulk command payload must be a JSON array")
  }
}

///|
fn edit_application_command_permissions_body(
  permissions : Array[@model.ApplicationCommandPermission],
) -> Json raise DiscordHttpError {
  if permissions.length() > 100 {
    raise Validation(
      message="application command permissions exceed 100 entries",
    )
  }
  @model.ObjBuilder().field("permissions", permissions).build()
}

///|
/// List global application commands. `with_localizations` includes the full
/// localization dictionaries in the returned objects.
pub async fn Client::get_global_commands(
  self : Client,
  application_id : @model.ApplicationId,
  with_localizations? : Bool,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  decode(
    self.request(
      GetGlobalCommands(
        application_id~,
        query=command_list_query(with_localizations),
      ),
    ),
  )
}

///|
/// Fetch one global application command.
pub async fn Client::get_global_command(
  self : Client,
  application_id : @model.ApplicationId,
  command_id : @model.CommandId,
) -> @model.ApplicationCommand raise DiscordHttpError {
  decode(self.request(GetGlobalCommand(application_id~, command_id~)))
}

///|
/// Create a global application command. `description` is required for
/// CHAT_INPUT commands (the default `typ`) and must be omitted for the
/// UI-based types. `handler` only applies to PRIMARY_ENTRY_POINT commands.
pub async fn Client::create_global_command(
  self : Client,
  application_id : @model.ApplicationId,
  name : String,
  description? : String,
  options? : Array[@model.CommandOption],
  typ? : @model.ApplicationCommandType,
  default_member_permissions? : @model.Permissions,
  clear_default_member_permissions? : Bool = false,
  nsfw? : Bool,
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
  handler? : @model.EntryPointCommandHandlerType,
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_text(name, description, typ)
  let body = command_body(
    name, description, options, typ, default_member_permissions, clear_default_member_permissions,
    nsfw, name_localizations, description_localizations, integration_types, contexts,
    handler,
  )
  decode(self.request(CreateGlobalCommand(application_id~), body~))
}

///|
/// Edit a global application command.
pub async fn Client::edit_global_command(
  self : Client,
  application_id : @model.ApplicationId,
  command_id : @model.CommandId,
  name? : String,
  description? : String,
  options? : Array[@model.CommandOption],
  default_member_permissions? : @model.Permissions,
  clear_default_member_permissions? : Bool = false,
  nsfw? : Bool,
  name_localizations? : Map[String, String],
  clear_name_localizations? : Bool = false,
  description_localizations? : Map[String, String],
  clear_description_localizations? : Bool = false,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
  handler? : @model.EntryPointCommandHandlerType,
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_patch(name, description)
  let body = command_patch_body(
    name, description, options, default_member_permissions, clear_default_member_permissions,
    nsfw, name_localizations, clear_name_localizations, description_localizations,
    clear_description_localizations, integration_types, contexts, handler,
  )
  decode(self.request(EditGlobalCommand(application_id~, command_id~), body~))
}

///|
/// Delete a global application command.
pub async fn Client::delete_global_command(
  self : Client,
  application_id : @model.ApplicationId,
  command_id : @model.CommandId,
) -> Unit raise DiscordHttpError {
  self.request(DeleteGlobalCommand(application_id~, command_id~)) |> ignore
}

///|
/// Replace all global commands using a pre-built JSON array.
pub async fn Client::bulk_overwrite_global_commands(
  self : Client,
  application_id : @model.ApplicationId,
  commands : Json,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  validate_bulk_commands(commands)
  decode(
    self.request(BulkOverwriteGlobalCommands(application_id~), body=commands),
  )
}

///|
/// List application commands registered in a guild. `with_localizations`
/// includes the full localization dictionaries in the returned objects.
pub async fn Client::get_guild_commands(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  with_localizations? : Bool,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  decode(
    self.request(
      GetGuildCommands(
        application_id~,
        guild_id~,
        query=command_list_query(with_localizations),
      ),
    ),
  )
}

///|
/// Fetch one application command registered in a guild.
pub async fn Client::get_guild_command(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  command_id : @model.CommandId,
) -> @model.ApplicationCommand raise DiscordHttpError {
  decode(self.request(GetGuildCommand(application_id~, guild_id~, command_id~)))
}

///|
/// Create an application command in a guild. `description` is required for
/// CHAT_INPUT commands (the default `typ`) and must be omitted for the
/// UI-based types.
pub async fn Client::create_guild_command(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  name : String,
  description? : String,
  options? : Array[@model.CommandOption],
  typ? : @model.ApplicationCommandType,
  default_member_permissions? : @model.Permissions,
  clear_default_member_permissions? : Bool = false,
  nsfw? : Bool,
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_text(name, description, typ)
  let body = command_body(
    name,
    description,
    options,
    typ,
    default_member_permissions,
    clear_default_member_permissions,
    nsfw,
    name_localizations,
    description_localizations,
    None,
    None,
    None,
  )
  decode(self.request(CreateGuildCommand(application_id~, guild_id~), body~))
}

///|
/// Edit an application command registered in a guild.
pub async fn Client::edit_guild_command(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  command_id : @model.CommandId,
  name? : String,
  description? : String,
  options? : Array[@model.CommandOption],
  default_member_permissions? : @model.Permissions,
  clear_default_member_permissions? : Bool = false,
  nsfw? : Bool,
  name_localizations? : Map[String, String],
  clear_name_localizations? : Bool = false,
  description_localizations? : Map[String, String],
  clear_description_localizations? : Bool = false,
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_patch(name, description)
  let body = command_patch_body(
    name,
    description,
    options,
    default_member_permissions,
    clear_default_member_permissions,
    nsfw,
    name_localizations,
    clear_name_localizations,
    description_localizations,
    clear_description_localizations,
    None,
    None,
    None,
  )
  decode(
    self.request(
      EditGuildCommand(application_id~, guild_id~, command_id~),
      body~,
    ),
  )
}

///|
/// Delete an application command registered in a guild.
pub async fn Client::delete_guild_command(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  command_id : @model.CommandId,
) -> Unit raise DiscordHttpError {
  self.request(DeleteGuildCommand(application_id~, guild_id~, command_id~))
  |> ignore
}

///|
/// Replace all guild commands using a pre-built JSON array.
pub async fn Client::bulk_overwrite_guild_commands(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  commands : Json,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  validate_bulk_commands(commands)
  decode(
    self.request(
      BulkOverwriteGuildCommands(application_id~, guild_id~),
      body=commands,
    ),
  )
}

///|
/// Fetch permission overrides for every application command in a guild.
///
/// https://discord.com/developers/docs/interactions/application-commands#get-guild-application-command-permissions
pub async fn Client::get_guild_application_command_permissions(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
) -> Array[@model.GuildApplicationCommandPermissions] raise DiscordHttpError {
  decode(
    self.request(
      GetGuildApplicationCommandPermissions(application_id~, guild_id~),
    ),
  )
}

///|
/// Fetch permission overrides for one application command in a guild.
///
/// https://discord.com/developers/docs/interactions/application-commands#get-application-command-permissions
pub async fn Client::get_application_command_permissions(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  command_id : @model.CommandId,
) -> @model.GuildApplicationCommandPermissions raise DiscordHttpError {
  decode(
    self.request(
      GetApplicationCommandPermissions(application_id~, guild_id~, command_id~),
    ),
  )
}

///|
/// Replace permission overrides for one application command in a guild.
///
/// Requires an OAuth2 bearer token with the
/// `applications.commands.permissions.update` scope.
///
/// https://discord.com/developers/docs/interactions/application-commands#edit-application-command-permissions
pub async fn Client::edit_application_command_permissions(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  command_id : @model.CommandId,
  permissions : Array[@model.ApplicationCommandPermission],
  bearer_token~ : String,
) -> @model.GuildApplicationCommandPermissions raise DiscordHttpError {
  let body = edit_application_command_permissions_body(permissions)
  decode(
    self.request(
      EditApplicationCommandPermissions(application_id~, guild_id~, command_id~),
      body~,
      headers=bearer_headers(bearer_token),
    ),
  )
}
