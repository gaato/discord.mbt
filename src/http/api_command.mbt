///|
fn validate_command_text(
  name : String,
  description : String,
) -> Unit raise DiscordHttpError {
  if name.length() < 1 || name.length() > 32 {
    raise Validation(message="command name must be between 1 and 32 characters")
  }
  if description.length() > 100 {
    raise Validation(message="command description exceeds 100 characters")
  }
}

///|
fn validate_command_patch(
  name : String?,
  description : String?,
) -> Unit raise DiscordHttpError {
  if name is Some(value) && (value.length() < 1 || value.length() > 32) {
    raise Validation(message="command name must be between 1 and 32 characters")
  }
  if description is Some(value) && value.length() > 100 {
    raise Validation(message="command description exceeds 100 characters")
  }
}

///|
fn command_body(
  name : String,
  description : String,
  options : Array[@model.CommandOption]?,
  typ : @model.ApplicationCommandType?,
  default_member_permissions : @model.Permissions?,
  clear_default_member_permissions : Bool,
  nsfw : Bool?,
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .field("name", name)
  .field("description", description)
  .opt("options", options)
  .opt("type", typ)
  .und(
    "default_member_permissions",
    patch_nullable(
      "default_member_permissions", default_member_permissions, clear_default_member_permissions,
    ),
  )
  .opt("nsfw", nsfw)
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
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .opt("name", name)
  .opt("description", description)
  .und("options", patch_value(options))
  .und(
    "default_member_permissions",
    patch_nullable(
      "default_member_permissions", default_member_permissions, clear_default_member_permissions,
    ),
  )
  .opt("nsfw", nsfw)
  .build()
}

///|
fn validate_bulk_commands(commands : Json) -> Unit raise DiscordHttpError {
  if !(commands is Array(_)) {
    raise Validation(message="bulk command payload must be a JSON array")
  }
}

///|
/// List global application commands.
pub async fn Client::get_global_commands(
  self : Client,
  application_id : @model.ApplicationId,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  decode(self.request(GetGlobalCommands(application_id~)))
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
/// Create a global application command.
pub async fn Client::create_global_command(
  self : Client,
  application_id : @model.ApplicationId,
  name : String,
  description : String,
  options? : Array[@model.CommandOption],
  typ? : @model.ApplicationCommandType,
  default_member_permissions? : @model.Permissions,
  clear_default_member_permissions? : Bool = false,
  nsfw? : Bool,
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_text(name, description)
  let body = command_body(
    name, description, options, typ, default_member_permissions, clear_default_member_permissions,
    nsfw,
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
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_patch(name, description)
  let body = command_patch_body(
    name, description, options, default_member_permissions, clear_default_member_permissions,
    nsfw,
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
/// List application commands registered in a guild.
pub async fn Client::get_guild_commands(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  decode(self.request(GetGuildCommands(application_id~, guild_id~)))
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
/// Create an application command in a guild.
pub async fn Client::create_guild_command(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  name : String,
  description : String,
  options? : Array[@model.CommandOption],
  typ? : @model.ApplicationCommandType,
  default_member_permissions? : @model.Permissions,
  clear_default_member_permissions? : Bool = false,
  nsfw? : Bool,
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_text(name, description)
  let body = command_body(
    name, description, options, typ, default_member_permissions, clear_default_member_permissions,
    nsfw,
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
) -> @model.ApplicationCommand raise DiscordHttpError {
  validate_command_patch(name, description)
  let body = command_patch_body(
    name, description, options, default_member_permissions, clear_default_member_permissions,
    nsfw,
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
