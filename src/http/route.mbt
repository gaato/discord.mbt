///|
/// One variant per Discord REST endpoint. A route knows its HTTP method, its
/// concrete path (including query string), and its rate-limit bucket key
/// (path template with major parameters kept and minor ones squashed).
pub(all) enum Route {
  GetGateway
  GetGatewayBot
  GetCurrentUser
  GetUser(user_id~ : @model.UserId)
  GetChannel(channel_id~ : @model.ChannelId)
  ModifyChannel(channel_id~ : @model.ChannelId)
  DeleteChannel(channel_id~ : @model.ChannelId)
  GetChannelMessages(channel_id~ : @model.ChannelId, query~ : String)
  GetChannelMessage(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId
  )
  CreateMessage(channel_id~ : @model.ChannelId)
  EditMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  DeleteMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  CreateReaction(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId,
    emoji~ : String
  )
  GetGuild(guild_id~ : @model.GuildId)
  GetGuildChannels(guild_id~ : @model.GuildId)
  GetGuildMember(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  CreateInteractionResponse(
    interaction_id~ : @model.InteractionId,
    token~ : String
  )
  GetOriginalInteractionResponse(
    application_id~ : @model.ApplicationId,
    token~ : String
  )
  EditOriginalInteractionResponse(
    application_id~ : @model.ApplicationId,
    token~ : String
  )
  CreateFollowupMessage(application_id~ : @model.ApplicationId, token~ : String)
  GetGlobalCommands(application_id~ : @model.ApplicationId)
  CreateGlobalCommand(application_id~ : @model.ApplicationId)
  BulkOverwriteGlobalCommands(application_id~ : @model.ApplicationId)
  GetGuildCommands(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId
  )
  CreateGuildCommand(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId
  )
  BulkOverwriteGuildCommands(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId
  )
}

///|
pub fn Route::method_(self : Route) -> @ahttp.RequestMethod {
  match self {
    GetGateway
    | GetGatewayBot
    | GetCurrentUser
    | GetUser(..)
    | GetChannel(..)
    | GetChannelMessages(..)
    | GetChannelMessage(..)
    | GetGuild(..)
    | GetGuildChannels(..)
    | GetGuildMember(..)
    | GetOriginalInteractionResponse(..)
    | GetGlobalCommands(..)
    | GetGuildCommands(..) => Get
    CreateMessage(..)
    | CreateInteractionResponse(..)
    | CreateFollowupMessage(..)
    | CreateGlobalCommand(..)
    | CreateGuildCommand(..) => Post
    ModifyChannel(..) | EditMessage(..) | EditOriginalInteractionResponse(..) =>
      Patch
    DeleteChannel(..) | DeleteMessage(..) => Delete
    CreateReaction(..) => Put
    BulkOverwriteGlobalCommands(..) | BulkOverwriteGuildCommands(..) => Put
  }
}

///|
pub fn Route::path(self : Route) -> String {
  match self {
    GetGateway => "/gateway"
    GetGatewayBot => "/gateway/bot"
    GetCurrentUser => "/users/@me"
    GetUser(user_id~) => "/users/\{user_id}"
    GetChannel(channel_id~)
    | ModifyChannel(channel_id~)
    | DeleteChannel(channel_id~) => "/channels/\{channel_id}"
    GetChannelMessages(channel_id~, query~) =>
      "/channels/\{channel_id}/messages\{query}"
    GetChannelMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}"
    CreateMessage(channel_id~) => "/channels/\{channel_id}/messages"
    EditMessage(channel_id~, message_id~)
    | DeleteMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}"
    CreateReaction(channel_id~, message_id~, emoji~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{emoji}/@me"
    GetGuild(guild_id~) => "/guilds/\{guild_id}"
    GetGuildChannels(guild_id~) => "/guilds/\{guild_id}/channels"
    GetGuildMember(guild_id~, user_id~) =>
      "/guilds/\{guild_id}/members/\{user_id}"
    CreateInteractionResponse(interaction_id~, token~) =>
      "/interactions/\{interaction_id}/\{token}/callback"
    GetOriginalInteractionResponse(application_id~, token~)
    | EditOriginalInteractionResponse(application_id~, token~) =>
      "/webhooks/\{application_id}/\{token}/messages/@original"
    CreateFollowupMessage(application_id~, token~) =>
      "/webhooks/\{application_id}/\{token}"
    GetGlobalCommands(application_id~)
    | CreateGlobalCommand(application_id~)
    | BulkOverwriteGlobalCommands(application_id~) =>
      "/applications/\{application_id}/commands"
    GetGuildCommands(application_id~, guild_id~)
    | CreateGuildCommand(application_id~, guild_id~)
    | BulkOverwriteGuildCommands(application_id~, guild_id~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands"
  }
}

///|
/// Rate-limit bucket key: method + path template with major parameters
/// (channel/guild/webhook+token) kept and minor IDs squashed. Message
/// deletion gets its own bucket, matching Discord's split limits.
pub fn Route::bucket(self : Route) -> String {
  match self {
    GetGateway => "GET:/gateway"
    GetGatewayBot => "GET:/gateway/bot"
    GetCurrentUser => "GET:/users/@me"
    GetUser(..) => "GET:/users/{}"
    GetChannel(channel_id~) => "GET:/channels/\{channel_id}"
    ModifyChannel(channel_id~) => "PATCH:/channels/\{channel_id}"
    DeleteChannel(channel_id~) => "DELETE:/channels/\{channel_id}"
    GetChannelMessages(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/messages"
    GetChannelMessage(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/messages/{}"
    CreateMessage(channel_id~) => "POST:/channels/\{channel_id}/messages"
    EditMessage(channel_id~, ..) => "PATCH:/channels/\{channel_id}/messages/{}"
    DeleteMessage(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/messages/{}"
    CreateReaction(channel_id~, ..) =>
      "PUT:/channels/\{channel_id}/messages/{}/reactions/{}/@me"
    GetGuild(guild_id~) => "GET:/guilds/\{guild_id}"
    GetGuildChannels(guild_id~) => "GET:/guilds/\{guild_id}/channels"
    GetGuildMember(guild_id~, ..) => "GET:/guilds/\{guild_id}/members/{}"
    CreateInteractionResponse(..) => "POST:/interactions/{}/{}/callback"
    GetOriginalInteractionResponse(application_id~, token~) =>
      "GET:/webhooks/\{application_id}/\{token}/messages/@original"
    EditOriginalInteractionResponse(application_id~, token~) =>
      "PATCH:/webhooks/\{application_id}/\{token}/messages/@original"
    CreateFollowupMessage(application_id~, token~) =>
      "POST:/webhooks/\{application_id}/\{token}"
    GetGlobalCommands(application_id~) =>
      "GET:/applications/\{application_id}/commands"
    CreateGlobalCommand(application_id~) =>
      "POST:/applications/\{application_id}/commands"
    BulkOverwriteGlobalCommands(application_id~) =>
      "PUT:/applications/\{application_id}/commands"
    GetGuildCommands(application_id~, guild_id~) =>
      "GET:/applications/\{application_id}/guilds/\{guild_id}/commands"
    CreateGuildCommand(application_id~, guild_id~) =>
      "POST:/applications/\{application_id}/guilds/\{guild_id}/commands"
    BulkOverwriteGuildCommands(application_id~, guild_id~) =>
      "PUT:/applications/\{application_id}/guilds/\{guild_id}/commands"
  }
}

///|
/// Interaction/webhook-token endpoints are exempt from the global limit.
pub fn Route::is_interaction(self : Route) -> Bool {
  match self {
    CreateInteractionResponse(..)
    | GetOriginalInteractionResponse(..)
    | EditOriginalInteractionResponse(..)
    | CreateFollowupMessage(..) => true
    _ => false
  }
}

///|
/// Whether the endpoint accepts the `X-Audit-Log-Reason` header.
pub fn Route::supports_reason(self : Route) -> Bool {
  match self {
    ModifyChannel(..) | DeleteChannel(..) | DeleteMessage(..) => true
    _ => false
  }
}

///|
/// Interaction callbacks and webhook-token routes are called without the bot
/// token (the token in the URL authenticates them).
pub fn Route::needs_auth(self : Route) -> Bool {
  match self {
    CreateInteractionResponse(..)
    | GetOriginalInteractionResponse(..)
    | EditOriginalInteractionResponse(..)
    | CreateFollowupMessage(..) => false
    _ => true
  }
}
