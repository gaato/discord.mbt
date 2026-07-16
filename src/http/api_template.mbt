///|
fn validate_guild_from_template_name(
  name : String,
) -> Unit raise DiscordHttpError {
  validate_length("guild name", Some(name), min=2, max=100)
}

///|
fn validate_guild_template_fields(
  name : String?,
  description : String?,
) -> Unit raise DiscordHttpError {
  validate_length("guild template name", name, min=1, max=100)
  validate_length("guild template description", description, max=120)
}

///|
fn create_guild_from_template_body(
  name : String,
  icon : String?,
) -> Json raise DiscordHttpError {
  validate_guild_from_template_name(name)
  @model.ObjBuilder().field("name", name).opt("icon", icon).build()
}

///|
fn create_guild_template_body(
  name : String,
  description : String?,
) -> Json raise DiscordHttpError {
  validate_guild_template_fields(Some(name), description)
  @model.ObjBuilder()
  .field("name", name)
  .opt("description", description)
  .build()
}

///|
fn modify_guild_template_body(
  name : String?,
  description : String?,
  clear_description : Bool,
) -> Json raise DiscordHttpError {
  validate_guild_template_fields(name, description)
  @model.ObjBuilder()
  .opt("name", name)
  .und(
    "description",
    patch_nullable("description", description, clear_description),
  )
  .build()
}

///|
/// Fetch a guild template by its code.
///
/// https://discord.com/developers/docs/resources/guild-template#get-guild-template
pub async fn Client::get_guild_template(
  self : Client,
  template_code : String,
) -> @model.GuildTemplate raise DiscordHttpError {
  decode(self.request(GetGuildTemplate(template_code~)))
}

///|
/// Create a guild from a template. This endpoint is only usable by bots in
/// fewer than 10 guilds.
///
/// https://discord.com/developers/docs/resources/guild-template#create-guild-from-guild-template
pub async fn Client::create_guild_from_template(
  self : Client,
  template_code : String,
  name : String,
  icon? : String,
) -> @model.Guild raise DiscordHttpError {
  let body = create_guild_from_template_body(name, icon)
  decode(self.request(CreateGuildFromTemplate(template_code~), body~))
}

///|
/// List the templates for a guild.
///
/// https://discord.com/developers/docs/resources/guild-template#get-guild-templates
pub async fn Client::get_guild_templates(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.GuildTemplate] raise DiscordHttpError {
  decode(self.request(GetGuildTemplates(guild_id~)))
}

///|
/// Create a template for a guild.
///
/// https://discord.com/developers/docs/resources/guild-template#create-guild-template
pub async fn Client::create_guild_template(
  self : Client,
  guild_id : @model.GuildId,
  name : String,
  description? : String,
) -> @model.GuildTemplate raise DiscordHttpError {
  let body = create_guild_template_body(name, description)
  decode(self.request(CreateGuildTemplate(guild_id~), body~))
}

///|
/// Sync a template to the current guild state.
///
/// https://discord.com/developers/docs/resources/guild-template#sync-guild-template
pub async fn Client::sync_guild_template(
  self : Client,
  guild_id : @model.GuildId,
  template_code : String,
) -> @model.GuildTemplate raise DiscordHttpError {
  decode(self.request(SyncGuildTemplate(guild_id~, template_code~)))
}

///|
/// Modify a guild template. Use `clear_description=true` to send JSON null
/// rather than omit the description.
///
/// https://discord.com/developers/docs/resources/guild-template#modify-guild-template
pub async fn Client::modify_guild_template(
  self : Client,
  guild_id : @model.GuildId,
  template_code : String,
  name? : String,
  description? : String,
  clear_description? : Bool = false,
) -> @model.GuildTemplate raise DiscordHttpError {
  let body = modify_guild_template_body(name, description, clear_description)
  decode(self.request(ModifyGuildTemplate(guild_id~, template_code~), body~))
}

///|
/// Delete a guild template and return the deleted template object.
///
/// https://discord.com/developers/docs/resources/guild-template#delete-guild-template
pub async fn Client::delete_guild_template(
  self : Client,
  guild_id : @model.GuildId,
  template_code : String,
) -> @model.GuildTemplate raise DiscordHttpError {
  decode(self.request(DeleteGuildTemplate(guild_id~, template_code~)))
}
