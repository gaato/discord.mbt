///|
/// Phantom marker types for `Id[M]`. These are empty enums: they have no
/// values and exist only at the type level.
pub enum ApplicationMarker {}

///|
/// Marker for IDs of an attachment.
pub enum AttachmentMarker {}

///|
/// Marker for IDs of an audit log entry.
pub enum AuditLogEntryMarker {}

///|
/// Marker for IDs of an auto moderation rule.
pub enum AutoModerationRuleMarker {}

///|
/// Marker for IDs of a channel.
pub enum ChannelMarker {}

///|
/// Marker for IDs of a command.
pub enum CommandMarker {}

///|
/// Marker for IDs of a command version.
pub enum CommandVersionMarker {}

///|
/// Marker for IDs of an emoji.
pub enum EmojiMarker {}

///|
/// Marker for IDs of an entitlement.
pub enum EntitlementMarker {}

///|
/// Marker for IDs of a resource whose kind is not tracked in the type.
pub enum GenericMarker {}

///|
/// Marker for IDs of a guild.
pub enum GuildMarker {}

///|
/// Marker for IDs of an integration.
pub enum IntegrationMarker {}

///|
/// Marker for IDs of an interaction.
pub enum InteractionMarker {}

///|
/// Marker for IDs of a message.
pub enum MessageMarker {}

///|
/// Marker for IDs of a role.
pub enum RoleMarker {}

///|
/// Marker for IDs of a scheduled event.
pub enum ScheduledEventMarker {}

///|
/// Marker for IDs of a SKU.
pub enum SkuMarker {}

///|
/// Marker for IDs of a subscription.
pub enum SubscriptionMarker {}

///|
/// Marker for IDs of a soundboard sound.
pub enum SoundboardSoundMarker {}

///|
/// Marker for IDs of a stage instance.
pub enum StageInstanceMarker {}

///|
/// Marker for IDs of a sticker.
pub enum StickerMarker {}

///|
/// Marker for IDs of a sticker pack.
pub enum StickerPackMarker {}

///|
/// Marker for IDs of a team.
pub enum TeamMarker {}

///|
/// Marker for IDs of a user.
pub enum UserMarker {}

///|
/// Marker for IDs of a webhook.
pub enum WebhookMarker {}
