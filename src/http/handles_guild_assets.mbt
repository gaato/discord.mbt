///|
/// An emoji id and its guild id bound to the REST client that operates on it.
pub struct EmojiRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv emoji_id : @model.EmojiId
}

///|
/// A sticker id and its guild id bound to the REST client that operates on it.
pub struct StickerRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv sticker_id : @model.StickerId
}

///|
/// A sound id and its guild id bound to the REST client that operates on it.
pub struct SoundboardSoundRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv sound_id : @model.SoundboardSoundId
}

///|
/// A scheduled event id and its guild id bound to the REST client.
pub struct ScheduledEventRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv event_id : @model.ScheduledEventId
}

///|
/// An auto-moderation rule id and its guild id bound to the REST client.
pub struct AutoModerationRuleRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv rule_id : @model.AutoModerationRuleId
}

///|
/// A template code and its guild id bound to the REST client.
pub struct TemplateRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv code : String
}

///|
/// Bind a guild/emoji id pair to this client.
pub fn Client::emoji_ref(
  self : Client,
  guild_id : @model.GuildId,
  emoji_id : @model.EmojiId,
) -> EmojiRef {
  { client: self, guild_id, emoji_id }
}

///|
/// Bind a guild/sticker id pair to this client.
pub fn Client::sticker_ref(
  self : Client,
  guild_id : @model.GuildId,
  sticker_id : @model.StickerId,
) -> StickerRef {
  { client: self, guild_id, sticker_id }
}

///|
/// Bind a guild/sound id pair to this client.
pub fn Client::soundboard_sound_ref(
  self : Client,
  guild_id : @model.GuildId,
  sound_id : @model.SoundboardSoundId,
) -> SoundboardSoundRef {
  { client: self, guild_id, sound_id }
}

///|
/// Bind a guild/scheduled event id pair to this client.
pub fn Client::scheduled_event_ref(
  self : Client,
  guild_id : @model.GuildId,
  event_id : @model.ScheduledEventId,
) -> ScheduledEventRef {
  { client: self, guild_id, event_id }
}

///|
/// Bind a guild/auto-moderation rule id pair to this client.
pub fn Client::auto_moderation_rule_ref(
  self : Client,
  guild_id : @model.GuildId,
  rule_id : @model.AutoModerationRuleId,
) -> AutoModerationRuleRef {
  { client: self, guild_id, rule_id }
}

///|
/// Bind a guild/template code pair to this client.
pub fn Client::guild_template_ref(
  self : Client,
  guild_id : @model.GuildId,
  code : String,
) -> TemplateRef {
  { client: self, guild_id, code }
}

///|
/// Bind an emoji id in this guild to the client.
pub fn GuildRef::emoji_ref(
  self : GuildRef,
  emoji_id : @model.EmojiId,
) -> EmojiRef {
  { client: self.client, guild_id: self.guild_id, emoji_id }
}

///|
/// Bind a sticker id in this guild to the client.
pub fn GuildRef::sticker_ref(
  self : GuildRef,
  sticker_id : @model.StickerId,
) -> StickerRef {
  { client: self.client, guild_id: self.guild_id, sticker_id }
}

///|
/// Bind a soundboard sound id in this guild to the client.
pub fn GuildRef::soundboard_sound_ref(
  self : GuildRef,
  sound_id : @model.SoundboardSoundId,
) -> SoundboardSoundRef {
  { client: self.client, guild_id: self.guild_id, sound_id }
}

///|
/// Bind a scheduled event id in this guild to the client.
pub fn GuildRef::scheduled_event_ref(
  self : GuildRef,
  event_id : @model.ScheduledEventId,
) -> ScheduledEventRef {
  { client: self.client, guild_id: self.guild_id, event_id }
}

///|
/// Bind an auto-moderation rule id in this guild to the client.
pub fn GuildRef::auto_moderation_rule_ref(
  self : GuildRef,
  rule_id : @model.AutoModerationRuleId,
) -> AutoModerationRuleRef {
  { client: self.client, guild_id: self.guild_id, rule_id }
}

///|
/// Bind a template code in this guild to the client.
pub fn GuildRef::template_ref(self : GuildRef, code : String) -> TemplateRef {
  { client: self.client, guild_id: self.guild_id, code }
}

///|
/// List custom emojis in this guild.
pub async fn GuildRef::emojis(
  self : GuildRef,
) -> Array[@model.Emoji] raise DiscordHttpError {
  self.client.list_guild_emojis(self.guild_id)
}

///|
/// Create a custom emoji in this guild.
pub async fn GuildRef::create_emoji(
  self : GuildRef,
  name : String,
  image : String,
  roles? : Array[@model.RoleId],
  reason? : String,
) -> @model.Emoji raise DiscordHttpError {
  self.client.create_guild_emoji(
    self.guild_id,
    name,
    image,
    roles?,
    audit_reason?=reason,
  )
}

///|
/// List custom stickers in this guild.
pub async fn GuildRef::stickers(
  self : GuildRef,
) -> Array[@model.Sticker] raise DiscordHttpError {
  self.client.list_guild_stickers(self.guild_id)
}

///|
/// Create a custom sticker in this guild.
pub async fn GuildRef::create_sticker(
  self : GuildRef,
  file : FileUpload,
  name : String,
  description : String,
  tags : String,
  reason? : String,
) -> @model.Sticker raise DiscordHttpError {
  self.client.create_guild_sticker(
    self.guild_id,
    file,
    name,
    description,
    tags,
    audit_reason?=reason,
  )
}

///|
/// List custom soundboard sounds in this guild.
pub async fn GuildRef::soundboard_sounds(
  self : GuildRef,
) -> Array[@model.SoundboardSound] raise DiscordHttpError {
  self.client.list_guild_soundboard_sounds(self.guild_id)
}

///|
/// Create a soundboard sound in this guild.
pub async fn GuildRef::create_soundboard_sound(
  self : GuildRef,
  name : String,
  sound : String,
  volume? : Double,
  emoji_id? : @model.EmojiId,
  emoji_name? : String,
  reason? : String,
) -> @model.SoundboardSound raise DiscordHttpError {
  self.client.create_guild_soundboard_sound(
    self.guild_id,
    name,
    sound,
    volume?,
    emoji_id?,
    emoji_name?,
    audit_reason?=reason,
  )
}

///|
/// List scheduled events in this guild.
pub async fn GuildRef::scheduled_events(
  self : GuildRef,
  with_user_count? : Bool,
) -> Array[@model.GuildScheduledEvent] raise DiscordHttpError {
  self.client.list_guild_scheduled_events(self.guild_id, with_user_count?)
}

///|
/// Create a scheduled event in this guild.
pub async fn GuildRef::create_scheduled_event(
  self : GuildRef,
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
  reason? : String,
) -> @model.GuildScheduledEvent raise DiscordHttpError {
  self.client.create_guild_scheduled_event(
    self.guild_id,
    name,
    privacy_level,
    scheduled_start_time,
    entity_type,
    channel_id?,
    clear_channel_id~,
    entity_metadata?,
    clear_entity_metadata~,
    scheduled_end_time?,
    clear_scheduled_end_time~,
    description?,
    image?,
    recurrence_rule?,
    audit_reason?=reason,
  )
}

///|
/// List auto-moderation rules in this guild.
pub async fn GuildRef::auto_moderation_rules(
  self : GuildRef,
) -> Array[@model.AutoModerationRule] raise DiscordHttpError {
  self.client.list_auto_moderation_rules(self.guild_id)
}

///|
/// Create an auto-moderation rule in this guild.
pub async fn GuildRef::create_auto_moderation_rule(
  self : GuildRef,
  name : String,
  event_type : @model.AutoModerationEventType,
  trigger_type : @model.AutoModerationTriggerType,
  trigger_metadata : @model.TriggerMetadata,
  actions : Array[@model.AutoModerationAction],
  enabled? : Bool,
  exempt_roles? : Array[@model.RoleId],
  exempt_channels? : Array[@model.ChannelId],
  reason? : String,
) -> @model.AutoModerationRule raise DiscordHttpError {
  self.client.create_auto_moderation_rule(
    self.guild_id,
    name,
    event_type,
    trigger_type,
    trigger_metadata,
    actions,
    enabled?,
    exempt_roles?,
    exempt_channels?,
    audit_reason?=reason,
  )
}

///|
/// List templates for this guild.
pub async fn GuildRef::templates(
  self : GuildRef,
) -> Array[@model.GuildTemplate] raise DiscordHttpError {
  self.client.get_guild_templates(self.guild_id)
}

///|
/// Create a template for this guild.
pub async fn GuildRef::create_template(
  self : GuildRef,
  name : String,
  description? : String,
) -> @model.GuildTemplate raise DiscordHttpError {
  self.client.create_guild_template(self.guild_id, name, description?)
}

///|
/// Fetch this custom guild emoji.
pub async fn EmojiRef::fetch(
  self : EmojiRef,
) -> @model.Emoji raise DiscordHttpError {
  self.client.get_guild_emoji(self.guild_id, self.emoji_id)
}

///|
/// Edit this custom guild emoji.
pub async fn EmojiRef::edit(
  self : EmojiRef,
  name? : String,
  roles? : Array[@model.RoleId],
  reason? : String,
) -> @model.Emoji raise DiscordHttpError {
  self.client.modify_guild_emoji(
    self.guild_id,
    self.emoji_id,
    name?,
    roles?,
    audit_reason?=reason,
  )
}

///|
/// Delete this custom guild emoji.
pub async fn EmojiRef::delete(
  self : EmojiRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_guild_emoji(
    self.guild_id,
    self.emoji_id,
    audit_reason?=reason,
  )
}

///|
/// Fetch this custom guild sticker.
pub async fn StickerRef::fetch(
  self : StickerRef,
) -> @model.Sticker raise DiscordHttpError {
  self.client.get_guild_sticker(self.guild_id, self.sticker_id)
}

///|
/// Edit this custom guild sticker.
pub async fn StickerRef::edit(
  self : StickerRef,
  name? : String,
  description? : String,
  clear_description? : Bool = false,
  tags? : String,
  reason? : String,
) -> @model.Sticker raise DiscordHttpError {
  self.client.modify_guild_sticker(
    self.guild_id,
    self.sticker_id,
    name?,
    description?,
    clear_description~,
    tags?,
    audit_reason?=reason,
  )
}

///|
/// Delete this custom guild sticker.
pub async fn StickerRef::delete(
  self : StickerRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_guild_sticker(
    self.guild_id,
    self.sticker_id,
    audit_reason?=reason,
  )
}

///|
/// Fetch this guild soundboard sound.
pub async fn SoundboardSoundRef::fetch(
  self : SoundboardSoundRef,
) -> @model.SoundboardSound raise DiscordHttpError {
  self.client.get_guild_soundboard_sound(self.guild_id, self.sound_id)
}

///|
/// Edit this guild soundboard sound.
pub async fn SoundboardSoundRef::edit(
  self : SoundboardSoundRef,
  name? : String,
  volume? : Double,
  emoji_id? : @model.EmojiId,
  clear_emoji_id? : Bool = false,
  emoji_name? : String,
  clear_emoji_name? : Bool = false,
  reason? : String,
) -> @model.SoundboardSound raise DiscordHttpError {
  self.client.modify_guild_soundboard_sound(
    self.guild_id,
    self.sound_id,
    name?,
    volume?,
    emoji_id?,
    clear_emoji_id~,
    emoji_name?,
    clear_emoji_name~,
    audit_reason?=reason,
  )
}

///|
/// Delete this guild soundboard sound.
pub async fn SoundboardSoundRef::delete(
  self : SoundboardSoundRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_guild_soundboard_sound(
    self.guild_id,
    self.sound_id,
    audit_reason?=reason,
  )
}

///|
/// Fetch this scheduled event.
pub async fn ScheduledEventRef::fetch(
  self : ScheduledEventRef,
  with_user_count? : Bool,
) -> @model.GuildScheduledEvent raise DiscordHttpError {
  self.client.get_guild_scheduled_event(
    self.guild_id,
    self.event_id,
    with_user_count?,
  )
}

///|
/// Edit this scheduled event.
pub async fn ScheduledEventRef::edit(
  self : ScheduledEventRef,
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
  reason? : String,
) -> @model.GuildScheduledEvent raise DiscordHttpError {
  self.client.modify_guild_scheduled_event(
    self.guild_id,
    self.event_id,
    channel_id?,
    clear_channel_id~,
    entity_metadata?,
    clear_entity_metadata~,
    name?,
    privacy_level?,
    scheduled_start_time?,
    scheduled_end_time?,
    clear_scheduled_end_time~,
    description?,
    clear_description~,
    entity_type?,
    status?,
    image?,
    clear_image~,
    recurrence_rule?,
    clear_recurrence_rule~,
    audit_reason?=reason,
  )
}

///|
/// Delete this scheduled event.
pub async fn ScheduledEventRef::delete(
  self : ScheduledEventRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_guild_scheduled_event(
    self.guild_id,
    self.event_id,
    audit_reason?=reason,
  )
}

///|
/// Paginate users interested in this scheduled event.
pub fn ScheduledEventRef::users(
  self : ScheduledEventRef,
  with_member? : Bool,
  before? : @model.UserId,
  after? : @model.UserId,
  page_size? : Int = 100,
) -> Paginator[@model.GuildScheduledEventUser] raise DiscordHttpError {
  self.client.paginate_guild_scheduled_event_users(
    self.guild_id,
    self.event_id,
    with_member?,
    before?,
    after?,
    page_size~,
  )
}

///|
/// Fetch this auto-moderation rule.
pub async fn AutoModerationRuleRef::fetch(
  self : AutoModerationRuleRef,
) -> @model.AutoModerationRule raise DiscordHttpError {
  self.client.get_auto_moderation_rule(self.guild_id, self.rule_id)
}

///|
/// Edit this auto-moderation rule.
pub async fn AutoModerationRuleRef::edit(
  self : AutoModerationRuleRef,
  name? : String,
  event_type? : @model.AutoModerationEventType,
  trigger_metadata? : @model.TriggerMetadata,
  actions? : Array[@model.AutoModerationAction],
  enabled? : Bool,
  exempt_roles? : Array[@model.RoleId],
  exempt_channels? : Array[@model.ChannelId],
  reason? : String,
) -> @model.AutoModerationRule raise DiscordHttpError {
  self.client.modify_auto_moderation_rule(
    self.guild_id,
    self.rule_id,
    name?,
    event_type?,
    trigger_metadata?,
    actions?,
    enabled?,
    exempt_roles?,
    exempt_channels?,
    audit_reason?=reason,
  )
}

///|
/// Delete this auto-moderation rule.
pub async fn AutoModerationRuleRef::delete(
  self : AutoModerationRuleRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_auto_moderation_rule(
    self.guild_id,
    self.rule_id,
    audit_reason?=reason,
  )
}

///|
/// Fetch this template. This resolves by code only and does not use the bound
/// guild id.
pub async fn TemplateRef::fetch(
  self : TemplateRef,
) -> @model.GuildTemplate raise DiscordHttpError {
  self.client.get_guild_template(self.code)
}

///|
/// Create a guild from this template. This resolves by code only and does not
/// use the bound guild id.
pub async fn TemplateRef::create_guild(
  self : TemplateRef,
  name : String,
  icon? : String,
) -> @model.Guild raise DiscordHttpError {
  self.client.create_guild_from_template(self.code, name, icon?)
}

///|
/// Sync this template to the bound guild's current state.
pub async fn TemplateRef::sync(
  self : TemplateRef,
) -> @model.GuildTemplate raise DiscordHttpError {
  self.client.sync_guild_template(self.guild_id, self.code)
}

///|
/// Edit this guild template.
pub async fn TemplateRef::edit(
  self : TemplateRef,
  name? : String,
  description? : String,
  clear_description? : Bool = false,
) -> @model.GuildTemplate raise DiscordHttpError {
  self.client.modify_guild_template(
    self.guild_id,
    self.code,
    name?,
    description?,
    clear_description~,
  )
}

///|
/// Delete this guild template.
pub async fn TemplateRef::delete(
  self : TemplateRef,
) -> @model.GuildTemplate raise DiscordHttpError {
  self.client.delete_guild_template(self.guild_id, self.code)
}
