///|
test "route regression table covers every previously uncovered metadata arm" {
  let application_id : @model.ApplicationId = Id(10UL)
  let guild_id : @model.GuildId = Id(20UL)
  let channel_id : @model.ChannelId = Id(30UL)
  let message_id : @model.MessageId = Id(40UL)
  let user_id : @model.UserId = Id(50UL)
  let role_id : @model.RoleId = Id(60UL)
  let command_id : @model.CommandId = Id(70UL)
  let cases : Array[(Route, String, String, String)] = [
    (GetGatewayBot, "Get", "/gateway/bot", "GET:/gateway/bot"),
    (GetCurrentUser, "Get", "/users/@me", "GET:/users/@me"),
    (GetUser(user_id~), "Get", "/users/50", "GET:/users/{}"),
    (
      GetChannelMessages(channel_id~, query="?limit=2"),
      "Get",
      "/channels/30/messages?limit=2",
      "GET:/channels/30/messages",
    ),
    (
      GetChannelMessage(channel_id~, message_id~),
      "Get",
      "/channels/30/messages/40",
      "GET:/channels/30/messages/{}",
    ),
    (
      DeleteChannel(channel_id~),
      "Delete",
      "/channels/30",
      "DELETE:/channels/30",
    ),
    (
      CreateReaction(channel_id~, message_id~, emoji="wave%3A80"),
      "Put",
      "/channels/30/messages/40/reactions/wave%3A80/@me",
      "PUT:/channels/30/messages/{}/reactions/{}",
    ),
    (
      DeleteAllReactions(channel_id~, message_id~),
      "Delete",
      "/channels/30/messages/40/reactions",
      "DELETE:/channels/30/messages/{}/reactions",
    ),
    (
      UnpinMessage(channel_id~, message_id~),
      "Delete",
      "/channels/30/pins/40",
      "DELETE:/channels/30/pins/{}",
    ),
    (
      StartThreadFromMessage(channel_id~, message_id~),
      "Post",
      "/channels/30/messages/40/threads",
      "POST:/channels/30/messages/{}/threads",
    ),
    (
      StartThreadWithoutMessage(channel_id~),
      "Post",
      "/channels/30/threads",
      "POST:/channels/30/threads",
    ),
    (
      LeaveThread(channel_id~),
      "Delete",
      "/channels/30/thread-members/@me",
      "DELETE:/channels/30/thread-members/@me",
    ),
    (GetGuild(guild_id~), "Get", "/guilds/20", "GET:/guilds/20"),
    (
      GetGuildWithCounts(guild_id~, query="?with_counts=true"),
      "Get",
      "/guilds/20?with_counts=true",
      "GET:/guilds/20",
    ),
    (
      GetGuildChannels(guild_id~),
      "Get",
      "/guilds/20/channels",
      "GET:/guilds/20/channels",
    ),
    (
      ModifyGuildChannelPositions(guild_id~),
      "Patch",
      "/guilds/20/channels",
      "PATCH:/guilds/20/channels",
    ),
    (
      ListGuildMembers(guild_id~, query="?limit=3"),
      "Get",
      "/guilds/20/members?limit=3",
      "GET:/guilds/20/members",
    ),
    (
      SearchGuildMembers(guild_id~, query="?query=neko"),
      "Get",
      "/guilds/20/members/search?query=neko",
      "GET:/guilds/20/members/search",
    ),
    (
      ModifyCurrentMember(guild_id~),
      "Patch",
      "/guilds/20/members/@me",
      "PATCH:/guilds/20/members/@me",
    ),
    (
      DeleteGuildRole(guild_id~, role_id~),
      "Delete",
      "/guilds/20/roles/60",
      "DELETE:/guilds/20/roles/{}",
    ),
    (
      AddGuildMemberRole(guild_id~, user_id~, role_id~),
      "Put",
      "/guilds/20/members/50/roles/60",
      "PUT:/guilds/20/members/{}/roles/{}",
    ),
    (
      RemoveGuildMemberRole(guild_id~, user_id~, role_id~),
      "Delete",
      "/guilds/20/members/50/roles/60",
      "DELETE:/guilds/20/members/{}/roles/{}",
    ),
    (
      GetGuildBans(guild_id~, query="?limit=4"),
      "Get",
      "/guilds/20/bans?limit=4",
      "GET:/guilds/20/bans",
    ),
    (
      GetGuildAuditLog(guild_id~, query="?limit=5"),
      "Get",
      "/guilds/20/audit-logs?limit=5",
      "GET:/guilds/20/audit-logs",
    ),
    (
      GetOriginalInteractionResponse(application_id~, token="tok"),
      "Get",
      "/webhooks/10/tok/messages/@original",
      "GET:/webhooks/10/tok/messages/@original",
    ),
    (
      DeleteOriginalInteractionResponse(application_id~, token="tok"),
      "Delete",
      "/webhooks/10/tok/messages/@original",
      "DELETE:/webhooks/10/tok/messages/@original",
    ),
    (
      DeleteFollowupMessage(application_id~, token="tok", message_id~),
      "Delete",
      "/webhooks/10/tok/messages/40",
      "DELETE:/webhooks/10/tok/messages/{}",
    ),
    (
      GetGlobalCommand(application_id~, command_id~),
      "Get",
      "/applications/10/commands/70",
      "GET:/applications/10/commands/{}",
    ),
    (
      DeleteGlobalCommand(application_id~, command_id~),
      "Delete",
      "/applications/10/commands/70",
      "DELETE:/applications/10/commands/{}",
    ),
    (
      BulkOverwriteGlobalCommands(application_id~),
      "Put",
      "/applications/10/commands",
      "PUT:/applications/10/commands",
    ),
    (
      GetGuildCommands(
        application_id~,
        guild_id~,
        query="?with_localizations=true",
      ),
      "Get",
      "/applications/10/guilds/20/commands?with_localizations=true",
      "GET:/applications/10/guilds/20/commands",
    ),
    (
      CreateGuildCommand(application_id~, guild_id~),
      "Post",
      "/applications/10/guilds/20/commands",
      "POST:/applications/10/guilds/20/commands",
    ),
    (
      GetGuildCommand(application_id~, guild_id~, command_id~),
      "Get",
      "/applications/10/guilds/20/commands/70",
      "GET:/applications/10/guilds/20/commands/{}",
    ),
    (
      EditGuildCommand(application_id~, guild_id~, command_id~),
      "Patch",
      "/applications/10/guilds/20/commands/70",
      "PATCH:/applications/10/guilds/20/commands/{}",
    ),
    (
      DeleteGuildCommand(application_id~, guild_id~, command_id~),
      "Delete",
      "/applications/10/guilds/20/commands/70",
      "DELETE:/applications/10/guilds/20/commands/{}",
    ),
    (
      BulkOverwriteGuildCommands(application_id~, guild_id~),
      "Put",
      "/applications/10/guilds/20/commands",
      "PUT:/applications/10/guilds/20/commands",
    ),
  ]
  for index, item in cases {
    let (route, expected_method, expected_path, expected_bucket) = item
    let actual_method = @debug.to_string(route.method_())
    if actual_method != expected_method ||
      route.path() != expected_path ||
      route.bucket() != expected_bucket {
      fail(
        "route case \{index}: expected (\{expected_method}, \{expected_path}, \{expected_bucket}), got (\{actual_method}, \{route.path()}, \{route.bucket()})",
      )
    }
  }
}
