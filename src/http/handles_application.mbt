///|
/// An application id bound to the REST client that operates on it.
pub struct ApplicationRef {
  priv client : Client
  priv application_id : @model.ApplicationId
}

///|
/// An application emoji id and its application id bound to the REST client.
pub struct ApplicationEmojiRef {
  priv client : Client
  priv application_id : @model.ApplicationId
  priv emoji_id : @model.EmojiId
}

///|
/// A global command id and its application id bound to the REST client.
pub struct GlobalCommandRef {
  priv client : Client
  priv application_id : @model.ApplicationId
  priv command_id : @model.CommandId
}

///|
/// A guild command id and its application/guild ids bound to the REST client.
pub struct GuildCommandRef {
  priv client : Client
  priv application_id : @model.ApplicationId
  priv guild_id : @model.GuildId
  priv command_id : @model.CommandId
}

///|
/// An entitlement id and its application id bound to the REST client.
pub struct EntitlementRef {
  priv client : Client
  priv application_id : @model.ApplicationId
  priv entitlement_id : @model.EntitlementId
}

///|
/// A SKU id bound to the REST client that operates on it.
pub struct SkuRef {
  priv client : Client
  priv sku_id : @model.SkuId
}

///|
/// Bind an application id to this client.
pub fn Client::application_ref(
  self : Client,
  application_id : @model.ApplicationId,
) -> ApplicationRef {
  { client: self, application_id }
}

///|
/// Bind an application/emoji id pair to this client.
pub fn Client::application_emoji_ref(
  self : Client,
  application_id : @model.ApplicationId,
  emoji_id : @model.EmojiId,
) -> ApplicationEmojiRef {
  { client: self, application_id, emoji_id }
}

///|
/// Bind an application/global command id pair to this client.
pub fn Client::global_command_ref(
  self : Client,
  application_id : @model.ApplicationId,
  command_id : @model.CommandId,
) -> GlobalCommandRef {
  { client: self, application_id, command_id }
}

///|
/// Bind application, guild, and command ids to this client.
pub fn Client::guild_command_ref(
  self : Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  command_id : @model.CommandId,
) -> GuildCommandRef {
  { client: self, application_id, guild_id, command_id }
}

///|
/// Bind an application/entitlement id pair to this client.
pub fn Client::entitlement_ref(
  self : Client,
  application_id : @model.ApplicationId,
  entitlement_id : @model.EntitlementId,
) -> EntitlementRef {
  { client: self, application_id, entitlement_id }
}

///|
/// Bind a SKU id to this client.
pub fn Client::sku_ref(self : Client, sku_id : @model.SkuId) -> SkuRef {
  { client: self, sku_id }
}

///|
/// Bind an emoji id in this application to the client.
pub fn ApplicationRef::emoji_ref(
  self : ApplicationRef,
  emoji_id : @model.EmojiId,
) -> ApplicationEmojiRef {
  { client: self.client, application_id: self.application_id, emoji_id }
}

///|
/// Bind a global command id in this application to the client.
pub fn ApplicationRef::global_command_ref(
  self : ApplicationRef,
  command_id : @model.CommandId,
) -> GlobalCommandRef {
  { client: self.client, application_id: self.application_id, command_id }
}

///|
/// Bind a guild command in this application to the client.
pub fn ApplicationRef::guild_command_ref(
  self : ApplicationRef,
  guild_id : @model.GuildId,
  command_id : @model.CommandId,
) -> GuildCommandRef {
  {
    client: self.client,
    application_id: self.application_id,
    guild_id,
    command_id,
  }
}

///|
/// Bind an entitlement id in this application to the client.
pub fn ApplicationRef::entitlement_ref(
  self : ApplicationRef,
  entitlement_id : @model.EntitlementId,
) -> EntitlementRef {
  { client: self.client, application_id: self.application_id, entitlement_id }
}

///|
/// Bind a SKU id to the client. This convenience constructor does not use the
/// bound application id.
pub fn ApplicationRef::sku_ref(
  self : ApplicationRef,
  sku_id : @model.SkuId,
) -> SkuRef {
  { client: self.client, sku_id }
}

///|
/// Fetch a live activity instance for this application.
pub async fn ApplicationRef::activity_instance(
  self : ApplicationRef,
  instance_id : String,
) -> @model.ActivityInstance raise DiscordHttpError {
  self.client.get_application_activity_instance(
    self.application_id,
    instance_id,
  )
}

///|
/// Fetch role connection metadata records for this application.
pub async fn ApplicationRef::role_connection_metadata(
  self : ApplicationRef,
) -> Array[@model.ApplicationRoleConnectionMetadata] raise DiscordHttpError {
  self.client.get_application_role_connection_metadata_records(
    self.application_id,
  )
}

///|
/// Replace role connection metadata records for this application.
pub async fn ApplicationRef::update_role_connection_metadata(
  self : ApplicationRef,
  records : Array[@model.ApplicationRoleConnectionMetadata],
) -> Array[@model.ApplicationRoleConnectionMetadata] raise DiscordHttpError {
  self.client.update_application_role_connection_metadata_records(
    self.application_id,
    records,
  )
}

///|
/// List custom emojis owned by this application.
pub async fn ApplicationRef::emojis(
  self : ApplicationRef,
) -> Array[@model.Emoji] raise DiscordHttpError {
  self.client.list_application_emojis(self.application_id)
}

///|
/// Create a custom emoji owned by this application.
pub async fn ApplicationRef::create_emoji(
  self : ApplicationRef,
  name : String,
  image : String,
) -> @model.Emoji raise DiscordHttpError {
  self.client.create_application_emoji(self.application_id, name, image)
}

///|
/// List global commands for this application. This is a lower-level API behind
/// `src/app`'s diff-based command sync; bots using sync normally need not call it.
pub async fn ApplicationRef::global_commands(
  self : ApplicationRef,
  with_localizations? : Bool,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  self.client.get_global_commands(self.application_id, with_localizations?)
}

///|
/// Create a global command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn ApplicationRef::create_global_command(
  self : ApplicationRef,
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
  self.client.create_global_command(
    self.application_id,
    name,
    description?,
    options?,
    typ?,
    default_member_permissions?,
    clear_default_member_permissions~,
    nsfw?,
    name_localizations?,
    description_localizations?,
    integration_types?,
    contexts?,
    handler?,
  )
}

///|
/// Replace all global commands. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn ApplicationRef::bulk_overwrite_global_commands(
  self : ApplicationRef,
  commands : Json,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  self.client.bulk_overwrite_global_commands(self.application_id, commands)
}

///|
/// List commands in a guild. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn ApplicationRef::guild_commands(
  self : ApplicationRef,
  guild_id : @model.GuildId,
  with_localizations? : Bool,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  self.client.get_guild_commands(
    self.application_id,
    guild_id,
    with_localizations?,
  )
}

///|
/// Create a guild command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn ApplicationRef::create_guild_command(
  self : ApplicationRef,
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
  self.client.create_guild_command(
    self.application_id,
    guild_id,
    name,
    description?,
    options?,
    typ?,
    default_member_permissions?,
    clear_default_member_permissions~,
    nsfw?,
    name_localizations?,
    description_localizations?,
  )
}

///|
/// Replace all commands in a guild. This is a lower-level API behind
/// `src/app`'s diff-based command sync; bots using sync normally need not call it.
pub async fn ApplicationRef::bulk_overwrite_guild_commands(
  self : ApplicationRef,
  guild_id : @model.GuildId,
  commands : Json,
) -> Array[@model.ApplicationCommand] raise DiscordHttpError {
  self.client.bulk_overwrite_guild_commands(
    self.application_id,
    guild_id,
    commands,
  )
}

///|
/// Fetch permission overrides for every command in a guild.
pub async fn ApplicationRef::guild_command_permissions(
  self : ApplicationRef,
  guild_id : @model.GuildId,
) -> Array[@model.GuildApplicationCommandPermissions] raise DiscordHttpError {
  self.client.get_guild_application_command_permissions(
    self.application_id,
    guild_id,
  )
}

///|
/// List entitlements for this application.
pub async fn ApplicationRef::entitlements(
  self : ApplicationRef,
  user_id? : @model.UserId,
  sku_ids? : Array[@model.SkuId],
  before? : @model.EntitlementId,
  after? : @model.EntitlementId,
  limit? : Int,
  guild_id? : @model.GuildId,
  exclude_ended? : Bool,
  exclude_deleted? : Bool,
) -> Array[@model.Entitlement] raise DiscordHttpError {
  self.client.list_entitlements(
    self.application_id,
    user_id?,
    sku_ids?,
    before?,
    after?,
    limit?,
    guild_id?,
    exclude_ended?,
    exclude_deleted?,
  )
}

///|
/// Create a test entitlement for this application.
pub async fn ApplicationRef::create_test_entitlement(
  self : ApplicationRef,
  sku_id : @model.SkuId,
  owner_id : @model.GenericId,
  owner_type : @model.EntitlementOwnerType,
) -> @model.Entitlement raise DiscordHttpError {
  self.client.create_test_entitlement(
    self.application_id,
    sku_id,
    owner_id,
    owner_type,
  )
}

///|
/// List SKUs available for this application.
pub async fn ApplicationRef::skus(
  self : ApplicationRef,
) -> Array[@model.Sku] raise DiscordHttpError {
  self.client.list_skus(self.application_id)
}

///|
/// Fetch this application emoji.
pub async fn ApplicationEmojiRef::fetch(
  self : ApplicationEmojiRef,
) -> @model.Emoji raise DiscordHttpError {
  self.client.get_application_emoji(self.application_id, self.emoji_id)
}

///|
/// Rename this application emoji.
pub async fn ApplicationEmojiRef::edit(
  self : ApplicationEmojiRef,
  name : String,
) -> @model.Emoji raise DiscordHttpError {
  self.client.modify_application_emoji(self.application_id, self.emoji_id, name)
}

///|
/// Delete this application emoji.
pub async fn ApplicationEmojiRef::delete(
  self : ApplicationEmojiRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_application_emoji(self.application_id, self.emoji_id)
}

///|
/// Fetch this global command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn GlobalCommandRef::fetch(
  self : GlobalCommandRef,
) -> @model.ApplicationCommand raise DiscordHttpError {
  self.client.get_global_command(self.application_id, self.command_id)
}

///|
/// Edit this global command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn GlobalCommandRef::edit(
  self : GlobalCommandRef,
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
  self.client.edit_global_command(
    self.application_id,
    self.command_id,
    name?,
    description?,
    options?,
    default_member_permissions?,
    clear_default_member_permissions~,
    nsfw?,
    name_localizations?,
    clear_name_localizations~,
    description_localizations?,
    clear_description_localizations~,
    integration_types?,
    contexts?,
    handler?,
  )
}

///|
/// Delete this global command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn GlobalCommandRef::delete(
  self : GlobalCommandRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_global_command(self.application_id, self.command_id)
}

///|
/// Fetch this guild command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn GuildCommandRef::fetch(
  self : GuildCommandRef,
) -> @model.ApplicationCommand raise DiscordHttpError {
  self.client.get_guild_command(
    self.application_id,
    self.guild_id,
    self.command_id,
  )
}

///|
/// Edit this guild command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn GuildCommandRef::edit(
  self : GuildCommandRef,
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
  self.client.edit_guild_command(
    self.application_id,
    self.guild_id,
    self.command_id,
    name?,
    description?,
    options?,
    default_member_permissions?,
    clear_default_member_permissions~,
    nsfw?,
    name_localizations?,
    clear_name_localizations~,
    description_localizations?,
    clear_description_localizations~,
  )
}

///|
/// Delete this guild command. This is a lower-level API behind `src/app`'s
/// diff-based command sync; bots using sync normally need not call it.
pub async fn GuildCommandRef::delete(
  self : GuildCommandRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_guild_command(
    self.application_id,
    self.guild_id,
    self.command_id,
  )
}

///|
/// Fetch permission overrides for this guild command.
pub async fn GuildCommandRef::permissions(
  self : GuildCommandRef,
) -> @model.GuildApplicationCommandPermissions raise DiscordHttpError {
  self.client.get_application_command_permissions(
    self.application_id,
    self.guild_id,
    self.command_id,
  )
}

///|
/// Replace permission overrides for this guild command.
pub async fn GuildCommandRef::edit_permissions(
  self : GuildCommandRef,
  permissions : Array[@model.ApplicationCommandPermission],
  bearer_token~ : String,
) -> @model.GuildApplicationCommandPermissions raise DiscordHttpError {
  self.client.edit_application_command_permissions(
    self.application_id,
    self.guild_id,
    self.command_id,
    permissions,
    bearer_token~,
  )
}

///|
/// Fetch this entitlement.
pub async fn EntitlementRef::fetch(
  self : EntitlementRef,
) -> @model.Entitlement raise DiscordHttpError {
  self.client.get_entitlement(self.application_id, self.entitlement_id)
}

///|
/// Mark this entitlement as consumed.
pub async fn EntitlementRef::consume(
  self : EntitlementRef,
) -> Unit raise DiscordHttpError {
  self.client.consume_entitlement(self.application_id, self.entitlement_id)
}

///|
/// Delete this test entitlement.
pub async fn EntitlementRef::delete_test(
  self : EntitlementRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_test_entitlement(self.application_id, self.entitlement_id)
}

///|
/// List subscriptions for this SKU. No SubscriptionRef is provided because
/// subscriptions expose only a single fetch operation.
pub async fn SkuRef::subscriptions(
  self : SkuRef,
  before? : @model.SubscriptionId,
  after? : @model.SubscriptionId,
  limit? : Int,
  user_id? : @model.UserId,
) -> Array[@model.Subscription] raise DiscordHttpError {
  self.client.list_sku_subscriptions(
    self.sku_id,
    before?,
    after?,
    limit?,
    user_id?,
  )
}

///|
/// Fetch one subscription for this SKU.
pub async fn SkuRef::subscription(
  self : SkuRef,
  subscription_id : @model.SubscriptionId,
) -> @model.Subscription raise DiscordHttpError {
  self.client.get_sku_subscription(self.sku_id, subscription_id)
}
