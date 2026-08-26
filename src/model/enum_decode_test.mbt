///|
fn[T : @json.FromJson] expect_model_decode_error(
  json : Json,
  expected : String,
  _sample : T,
) -> Unit raise {
  try (@json.from_json(json) : T) |> ignore catch {
    JsonDecodeError((_, message)) => assert_eq(message, expected)
  } noraise {
    _ => fail("expected JsonDecodeError: \{expected}")
  }
}

///|
test "activity and application rare enum variants round-trip" {
  let location = @model.ActivityLocationKind::from_string("pc")
  debug_inspect(location, content="PrivateChannel")
  assert_eq(location.to_string(), "pc")
  let status = @model.ApplicationEventWebhookStatus::from_int(2)
  debug_inspect(status, content="Enabled")
  assert_eq(status.to_int(), 2)
  let disabled = @model.ApplicationEventWebhookStatus::from_int(3)
  debug_inspect(disabled, content="DisabledByDiscord")
  assert_eq(disabled.to_int(), 3)
}

///|
test "audit and auto moderation rare enum variants round-trip" {
  let guild_update = @model.AuditLogEvent::from_int(1)
  debug_inspect(guild_update, content="GuildUpdate")
  assert_eq(guild_update.to_int(), 1)
  debug_inspect(@model.AuditLogEvent::from_int(12), content="ChannelDelete")
  let keyword = @model.AutoModerationTriggerType::from_int(4)
  debug_inspect(keyword, content="KeywordPreset")
  assert_eq(keyword.to_int(), 4)
  debug_inspect(@model.AutoModerationTriggerType::from_int(3), content="Spam")
  debug_inspect(
    @model.AutoModerationTriggerType::from_int(6),
    content="MemberProfile",
  )
  let preset : @model.AutoModerationKeywordPresetType = @json.from_json(
    @json.parse("2"),
  )
  debug_inspect(preset, content="SexualContent")
  assert_eq(preset.to_json().stringify(), "2")
  let member_update = @model.AutoModerationEventType::from_int(2)
  debug_inspect(member_update, content="MemberUpdate")
  assert_eq(member_update.to_int(), 2)
  let block = @model.AutoModerationActionType::from_int(4)
  debug_inspect(block, content="BlockMemberInteraction")
  assert_eq(block.to_int(), 4)
}

///|
test "channel rare enum variants and unknown values round-trip" {
  assert_eq(@model.OverwriteType::from_int(73).to_int(), 73)
  let video = @model.VideoQualityMode::from_int(1)
  debug_inspect(video, content="Auto")
  assert_eq(video.to_int(), 1)
  assert_eq(@model.VideoQualityMode::from_int(73).to_int(), 73)
  let sort = @model.SortOrderType::from_int(0)
  debug_inspect(sort, content="LatestActivity")
  assert_eq(sort.to_int(), 0)
  assert_eq(@model.SortOrderType::from_int(73).to_int(), 73)
  let layout = @model.ForumLayoutType::from_int(0)
  debug_inspect(layout, content="NotSet")
  assert_eq(layout.to_int(), 0)
  assert_eq(@model.ForumLayoutType::from_int(73).to_int(), 73)
  let archive = @model.ThreadAutoArchiveDuration::from_int(4320)
  debug_inspect(archive, content="ThreeDays")
  assert_eq(archive.to_int(), 4320)
}

///|
test "all channel type variants used by rare Discord channels round-trip" {
  let cases : Array[(Int, String)] = [
    (2, "GuildVoice"),
    (10, "AnnouncementThread"),
    (12, "PrivateThread"),
    (13, "GuildStageVoice"),
    (16, "GuildMedia"),
  ]
  for item in cases {
    let (wire, expected) = item
    let value = @model.ChannelType::from_int(wire)
    assert_eq(value.to_int(), wire)
    assert_eq(Repr(value).to_string(), expected)
  }
}

///|
test "command, component, and interaction rare enum variants round-trip" {
  let handler = @model.EntryPointCommandHandlerType::from_int(2)
  debug_inspect(handler, content="DiscordLaunchActivity")
  assert_eq(handler.to_int(), 2)
  assert_eq(@model.EntryPointCommandHandlerType::from_int(71).to_int(), 71)
  let command = @model.ApplicationCommandType::from_int(4)
  debug_inspect(command, content="PrimaryEntryPoint")
  assert_eq(command.to_int(), 4)
  assert_eq(@model.ApplicationCommandType::from_int(71).to_int(), 71)
  let secondary = @model.ButtonStyle::from_int(2)
  debug_inspect(secondary, content="Secondary")
  assert_eq(secondary.to_int(), 2)
  let premium = @model.ButtonStyle::from_int(6)
  debug_inspect(premium, content="Premium")
  assert_eq(premium.to_int(), 6)
  assert_eq(@model.TextInputStyle::from_int(71).to_int(), 71)
  let ping = @model.InteractionType::from_int(1)
  debug_inspect(ping, content="Ping")
  assert_eq(ping.to_int(), 1)
  let component = @model.InteractionType::from_int(3)
  debug_inspect(component, content="MessageComponent")
  assert_eq(component.to_int(), 3)
  let deferred = @model.InteractionResponseType::from_int(5)
  debug_inspect(deferred, content="DeferredChannelMessageWithSource")
  assert_eq(deferred.to_int(), 5)
  let autocomplete = @model.InteractionResponseType::from_int(8)
  debug_inspect(autocomplete, content="Autocomplete")
  assert_eq(autocomplete.to_int(), 8)
  let premium_required = @model.InteractionResponseType::from_int(10)
  debug_inspect(premium_required, content="PremiumRequired")
  assert_eq(premium_required.to_int(), 10)
  debug_inspect(@model.InteractionResponseType::from_int(1), content="Pong")
}

///|
test "embed and presence rare string and numeric variants round-trip" {
  let rich = @model.EmbedType::from_string("rich")
  debug_inspect(rich, content="Rich")
  assert_eq(rich.to_string(), "rich")
  debug_inspect(@model.EmbedType::from_string("image"), content="Image")
  debug_inspect(@model.EmbedType::from_string("article"), content="Article")
  let idle = @model.PresenceStatus::from_string("idle")
  debug_inspect(idle, content="Idle")
  assert_eq(idle.to_string(), "idle")
  let offline = @model.PresenceStatus::from_string("offline")
  debug_inspect(offline, content="Offline")
  assert_eq(offline.to_string(), "offline")
  debug_inspect(@model.PresenceStatus::from_string("dnd"), content="Dnd")
  let streaming = @model.ActivityType::from_int(1)
  debug_inspect(streaming, content="Streaming")
  assert_eq(streaming.to_int(), 1)
  assert_eq(streaming.to_json().stringify(), "1")
}

///|
test "guild rare enum and feature variants round-trip" {
  let low = @model.VerificationLevel::from_int(1)
  debug_inspect(low, content="Low")
  assert_eq(low.to_int(), 1)
  let very_high = @model.VerificationLevel::from_int(4)
  debug_inspect(very_high, content="VeryHigh")
  assert_eq(very_high.to_int(), 4)
  let filter = @model.ExplicitContentFilter::from_int(1)
  debug_inspect(filter, content="MembersWithoutRoles")
  assert_eq(filter.to_int(), 1)
  let tier = @model.PremiumTier::from_int(1)
  debug_inspect(tier, content="Tier1")
  assert_eq(tier.to_int(), 1)
  let nsfw = @model.NsfwLevel::from_int(1)
  debug_inspect(nsfw, content="Explicit")
  assert_eq(nsfw.to_int(), 1)
  let feature_names = [
    "ANIMATED_BANNER", "APPLICATION_COMMAND_PERMISSIONS_V2", "CREATOR_MONETIZABLE_PROVISIONAL",
    "FEATURABLE", "LINKED_TO_HUB", "PARTNERED", "ROLE_SUBSCRIPTIONS_AVAILABLE_FOR_PURCHASE",
    "WELCOME_SCREEN_ENABLED",
  ]
  for name in feature_names {
    assert_eq(@model.GuildFeature::from_string(name).to_string(), name)
  }
}

///|
test "invite, integration, and onboarding rare variants round-trip" {
  let group_dm = @model.InviteType::from_int(1)
  debug_inspect(group_dm, content="GroupDm")
  assert_eq(group_dm.to_int(), 1)
  let embedded = @model.InviteTargetType::from_int(2)
  debug_inspect(embedded, content="EmbeddedApplication")
  assert_eq(embedded.to_int(), 2)
  let unspecified = @model.TargetUsersJobStatusCode::from_int(0)
  debug_inspect(unspecified, content="Unspecified")
  assert_eq(unspecified.to_int(), 0)
  assert_eq(@model.IntegrationExpireBehavior::from_int(57).to_int(), 57)
  let prompt = @model.OnboardingPromptType::from_int(0)
  debug_inspect(prompt, content="MultipleChoice")
  assert_eq(prompt.to_int(), 0)
  let mode = @model.OnboardingMode::from_int(0)
  debug_inspect(mode, content="Default")
  assert_eq(mode.to_int(), 0)
}

///|
test "message rare variants and nonce forms round-trip" {
  let unset = @model.BaseTheme::from_int(0)
  debug_inspect(unset, content="Unset")
  assert_eq(unset.to_int(), 0)
  let light = @model.BaseTheme::from_int(2)
  debug_inspect(light, content="Light")
  assert_eq(light.to_int(), 2)
  let string_nonce : @model.Nonce = @json.from_json(
    Json::string("client-generated"),
  )
  assert_eq(string_nonce.to_json().stringify(), "\"client-generated\"")
  let numeric_nonce : @model.Nonce = @json.from_json(@json.parse("42"))
  assert_eq(numeric_nonce.to_json().stringify(), "42")
  assert_eq(@model.ReactionType::from_int(91).to_int(), 91)
  let recipient = @model.MessageType::from_int(1)
  debug_inspect(recipient, content="RecipientAdd")
  assert_eq(recipient.to_int(), 1)
  debug_inspect(@model.MessageType::from_int(20), content="ChatInputCommand")
  let spectate = @model.MessageActivityType::from_int(2)
  debug_inspect(spectate, content="Spectate")
  assert_eq(spectate.to_int(), 2)
  assert_eq(spectate.to_json().stringify(), "2")
  let forward = @model.MessageReferenceType::from_int(1)
  debug_inspect(forward, content="Forward")
  assert_eq(forward.to_int(), 1)
  assert_eq(@model.MessageReferenceType::from_int(91).to_int(), 91)
}

///|
test "monetization and user rare enum variants round-trip" {
  let purchase = @model.EntitlementType::from_int(1)
  debug_inspect(purchase, content="Purchase")
  assert_eq(purchase.to_int(), 1)
  debug_inspect(
    @model.EntitlementType::from_int(2),
    content="PremiumSubscription",
  )
  debug_inspect(@model.EntitlementType::from_int(5), content="FreePurchase")
  let durable = @model.SkuType::from_int(2)
  debug_inspect(durable, content="Durable")
  assert_eq(durable.to_int(), 2)
  assert_eq(@model.SubscriptionStatus::from_int(91).to_int(), 91)
  let classic = @model.PremiumType::from_int(1)
  debug_inspect(classic, content="NitroClassic")
  assert_eq(classic.to_int(), 1)
  let basic = @model.PremiumType::from_int(3)
  debug_inspect(basic, content="NitroBasic")
  assert_eq(basic.to_int(), 3)
}

///|
test "scheduled event, stage, sticker, and team rare variants round-trip" {
  let yearly = @model.GuildScheduledEventRecurrenceRuleFrequency::from_int(0)
  debug_inspect(yearly, content="Yearly")
  assert_eq(yearly.to_int(), 0)
  let daily = @model.GuildScheduledEventRecurrenceRuleFrequency::from_int(3)
  debug_inspect(daily, content="Daily")
  assert_eq(daily.to_int(), 3)
  let tuesday = @model.GuildScheduledEventRecurrenceRuleWeekday::from_int(1)
  debug_inspect(tuesday, content="Tuesday")
  assert_eq(tuesday.to_int(), 1)
  let thursday = @model.GuildScheduledEventRecurrenceRuleWeekday::from_int(3)
  debug_inspect(thursday, content="Thursday")
  assert_eq(thursday.to_int(), 3)
  let january = @model.GuildScheduledEventRecurrenceRuleMonth::from_int(1)
  debug_inspect(january, content="January")
  assert_eq(january.to_int(), 1)
  let september = @model.GuildScheduledEventRecurrenceRuleMonth::from_int(9)
  debug_inspect(september, content="September")
  assert_eq(september.to_int(), 9)
  let scheduled = @model.GuildScheduledEventStatus::from_int(1)
  debug_inspect(scheduled, content="Scheduled")
  assert_eq(scheduled.to_int(), 1)
  debug_inspect(@model.GuildScheduledEventStatus::from_int(2), content="Active")
  let stage_event = @model.GuildScheduledEventEntityType::from_int(1)
  debug_inspect(stage_event, content="StageInstance")
  assert_eq(stage_event.to_int(), 1)
  assert_eq(@model.StagePrivacyLevel::from_int(2).to_int(), 2)
  let apng = @model.StickerFormatType::from_int(2)
  debug_inspect(apng, content="Apng")
  assert_eq(apng.to_int(), 2)
  let gif = @model.StickerFormatType::from_int(4)
  debug_inspect(gif, content="Gif")
  assert_eq(gif.to_int(), 4)
  let invited = @model.TeamMembershipState::from_int(1)
  debug_inspect(invited, content="Invited")
  assert_eq(invited.to_int(), 1)
}

///|
test "simple model enum decoders reject the wrong JSON shape" {
  let wrong = Json::boolean(true)
  expect_model_decode_error(
    wrong,
    "expected activity location kind (string)",
    @model.ActivityLocationKind::from_string("gc"),
  )
  expect_model_decode_error(
    wrong,
    "expected application event webhook status (number)",
    @model.ApplicationEventWebhookStatus::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the action category recorded by a guild audit log (number)",
    @model.AuditLogEvent::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the condition category that activates an auto-moderation rule (number)",
    @model.AutoModerationTriggerType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected a built-in keyword set used by auto moderation (number)",
    @model.AutoModerationKeywordPresetType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the guild event evaluated by an auto-moderation rule (number)",
    @model.AutoModerationEventType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the operation performed by auto moderation (number)",
    @model.AutoModerationActionType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected an overwrite type (number)",
    @model.OverwriteType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a video quality mode (number)",
    @model.VideoQualityMode::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected a sort order type (number)",
    @model.SortOrderType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a forum layout type (number)",
    @model.ForumLayoutType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a thread auto-archive duration (number)",
    @model.ThreadAutoArchiveDuration::from_int(60),
  )
  expect_model_decode_error(
    wrong,
    "expected a channel type (number)",
    @model.ChannelType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected entry-point command handler type (number)",
    @model.EntryPointCommandHandlerType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the invocation category of an application command (number)",
    @model.ApplicationCommandType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected a button style (number)",
    @model.ButtonStyle::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected a text input style (number)",
    @model.TextInputStyle::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected an embed type (string)",
    @model.EmbedType::from_string("rich"),
  )
  expect_model_decode_error(
    wrong,
    "expected activity type (number)",
    @model.ActivityType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected guild feature (string)",
    @model.GuildFeature::from_string("COMMUNITY"),
  )
  expect_model_decode_error(
    wrong,
    "expected the destination category of a discord invite (number)",
    @model.InviteType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a premium type (number)",
    @model.PremiumType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a sticker format (number)",
    @model.StickerFormatType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected a user's invitation state within a developer team (number)",
    @model.TeamMembershipState::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the behavior category of a discord webhook (number)",
    @model.WebhookType::from_int(1),
  )
}
