///|
test "all documented audit-log event wire values round-trip" {
  let wire_values = [
    1, 10, 11, 12, 13, 14, 15, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 40,
    41, 42, 50, 51, 52, 60, 61, 62, 72, 73, 74, 75, 80, 81, 82, 83, 84, 85, 90, 91,
    92, 100, 101, 102, 110, 111, 112, 121, 130, 131, 132, 140, 141, 142, 143, 144,
    145, 146, 150, 151, 163, 164, 165, 166, 167, 190, 191, 192, 193,
  ]
  for wire in wire_values {
    let event = @model.AuditLogEvent::from_int(wire)
    let decoded : @model.AuditLogEvent = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, event)
    assert_eq(event.to_int(), wire)
    assert_eq(event.to_json().stringify(), wire.to_string())
  }
}

///|
test "all documented message enum wire values round-trip" {
  for wire in [0, 1, 2, 3, 4] {
    let theme = @model.BaseTheme::from_int(wire)
    let decoded : @model.BaseTheme = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, theme)
    assert_eq(theme.to_int(), wire)
    assert_eq(theme.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1] {
    let reaction = @model.ReactionType::from_int(wire)
    let decoded : @model.ReactionType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, reaction)
    assert_eq(reaction.to_int(), wire)
    assert_eq(reaction.to_json().stringify(), wire.to_string())
  }
  let message_types = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22,
    23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 36, 37, 38, 39, 44, 46,
  ]
  for wire in message_types {
    let typ = @model.MessageType::from_int(wire)
    let decoded : @model.MessageType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, typ)
    assert_eq(typ.to_int(), wire)
    assert_eq(typ.to_json().stringify(), wire.to_string())
  }
  for wire in [1, 2, 3, 5] {
    let activity = @model.MessageActivityType::from_int(wire)
    let decoded : @model.MessageActivityType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, activity)
    assert_eq(activity.to_int(), wire)
    assert_eq(activity.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1] {
    let reference = @model.MessageReferenceType::from_int(wire)
    let decoded : @model.MessageReferenceType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, reference)
    assert_eq(reference.to_int(), wire)
    assert_eq(reference.to_json().stringify(), wire.to_string())
  }
}

///|
test "all documented guild feature names round-trip" {
  let feature_names = [
    "ANIMATED_BANNER", "ANIMATED_ICON", "APPLICATION_COMMAND_PERMISSIONS_V2", "AUTO_MODERATION",
    "BANNER", "COMMUNITY", "CREATOR_MONETIZABLE_PROVISIONAL", "CREATOR_STORE_PAGE",
    "DEVELOPER_SUPPORT_SERVER", "DISCOVERABLE", "FEATURABLE", "HAS_DIRECTORY_ENTRY",
    "HUB", "INVITES_DISABLED", "INVITE_SPLASH", "LINKED_TO_HUB", "MEMBER_VERIFICATION_GATE_ENABLED",
    "MORE_SOUNDBOARD", "MONETIZATION_ENABLED", "MORE_STICKERS", "NEWS", "PARTNERED",
    "PREVIEW_ENABLED", "PRIVATE_THREADS", "RAID_ALERTS_DISABLED", "RELAY_ENABLED",
    "ROLE_ICONS", "ROLE_SUBSCRIPTIONS_AVAILABLE_FOR_PURCHASE", "ROLE_SUBSCRIPTIONS_ENABLED",
    "SOUNDBOARD", "TICKETED_EVENTS_ENABLED", "VANITY_URL", "VERIFIED", "VIP_REGIONS",
    "WELCOME_SCREEN_ENABLED", "GUILD_TAGS", "ENHANCED_ROLE_COLORS", "GUESTS_ENABLED",
    "PIN_PERMISSION_MIGRATION_COMPLETE",
  ]
  for name in feature_names {
    let feature = @model.GuildFeature::from_string(name)
    let decoded : @model.GuildFeature = @json.from_json(Json::string(name))
    assert_eq(decoded, feature)
    assert_eq(feature.to_string(), name)
    assert_eq(feature.to_json().stringify(), Json::string(name).stringify())
  }
}

///|
test "all documented OAuth connection service names round-trip" {
  let service_names = [
    "amazon-music", "battlenet", "bluesky", "bungie", "crunchyroll", "domain", "ebay",
    "epicgames", "facebook", "github", "instagram", "leagueoflegends", "mastodon",
    "paypal", "playstation", "reddit", "riotgames", "roblox", "spotify", "skype",
    "steam", "tiktok", "twitch", "twitter", "xbox", "youtube",
  ]
  for name in service_names {
    let service = @model.ConnectionService::from_string(name)
    let decoded : @model.ConnectionService = @json.from_json(Json::string(name))
    assert_eq(decoded, service)
    assert_eq(service.to_string(), name)
    assert_eq(service.to_json().stringify(), Json::string(name).stringify())
  }
}

///|
test "all documented scheduled-event recurrence values round-trip" {
  for wire in [0, 1, 2, 3] {
    let frequency = @model.GuildScheduledEventRecurrenceRuleFrequency::from_int(
      wire,
    )
    let decoded : @model.GuildScheduledEventRecurrenceRuleFrequency = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, frequency)
    assert_eq(frequency.to_int(), wire)
    assert_eq(frequency.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1, 2, 3, 4, 5, 6] {
    let weekday = @model.GuildScheduledEventRecurrenceRuleWeekday::from_int(
      wire,
    )
    let decoded : @model.GuildScheduledEventRecurrenceRuleWeekday = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, weekday)
    assert_eq(weekday.to_int(), wire)
    assert_eq(weekday.to_json().stringify(), wire.to_string())
  }
  for wire in 1..<=12 {
    let month = @model.GuildScheduledEventRecurrenceRuleMonth::from_int(wire)
    let decoded : @model.GuildScheduledEventRecurrenceRuleMonth = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, month)
    assert_eq(month.to_int(), wire)
    assert_eq(month.to_json().stringify(), wire.to_string())
  }
  for wire in [1, 2, 3, 4] {
    let status = @model.GuildScheduledEventStatus::from_int(wire)
    let decoded : @model.GuildScheduledEventStatus = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, status)
    assert_eq(status.to_int(), wire)
    assert_eq(status.to_json().stringify(), wire.to_string())
  }
  for wire in [1, 2, 3] {
    let entity = @model.GuildScheduledEventEntityType::from_int(wire)
    let decoded : @model.GuildScheduledEventEntityType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, entity)
    assert_eq(entity.to_int(), wire)
    assert_eq(entity.to_json().stringify(), wire.to_string())
  }
}

///|
test "remaining documented scalar enum values round-trip" {
  for wire in [0, 1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15, 16] {
    let channel = @model.ChannelType::from_int(wire)
    let decoded : @model.ChannelType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, channel)
    assert_eq(channel.to_int(), wire)
    assert_eq(channel.to_json().stringify(), wire.to_string())
  }
  for wire in [1, 2, 3, 4, 5] {
    let interaction = @model.InteractionType::from_int(wire)
    let decoded : @model.InteractionType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, interaction)
    assert_eq(interaction.to_int(), wire)
    assert_eq(interaction.to_json().stringify(), wire.to_string())
  }
  for wire in [1, 4, 5, 6, 7, 8, 9, 10, 12] {
    let response = @model.InteractionResponseType::from_int(wire)
    let decoded : @model.InteractionResponseType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, response)
    assert_eq(response.to_int(), wire)
    assert_eq(response.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1, 2] {
    let invite = @model.InviteType::from_int(wire)
    let decoded : @model.InviteType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, invite)
    assert_eq(invite.to_int(), wire)
    assert_eq(invite.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1, 2, 3] {
    let premium = @model.PremiumType::from_int(wire)
    let decoded : @model.PremiumType = @json.from_json(
      Json::number(wire.to_double()),
    )
    assert_eq(decoded, premium)
    assert_eq(premium.to_int(), wire)
    assert_eq(premium.to_json().stringify(), wire.to_string())
  }
}

///|
test "remaining guild scalar enum wire values round-trip" {
  for wire in [0, 1, 2, 3, 4] {
    let value = @model.VerificationLevel::from_int(wire)
    assert_eq(value.to_int(), wire)
    assert_eq(value.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1] {
    let value = @model.DefaultMessageNotifications::from_int(wire)
    assert_eq(value.to_int(), wire)
    assert_eq(value.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1, 2] {
    let value = @model.ExplicitContentFilter::from_int(wire)
    assert_eq(value.to_int(), wire)
    assert_eq(value.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1] {
    let value = @model.MfaLevel::from_int(wire)
    assert_eq(value.to_int(), wire)
    assert_eq(value.to_json().stringify(), wire.to_string())
  }
  for wire in [0, 1, 2, 3] {
    let tier = @model.PremiumTier::from_int(wire)
    assert_eq(tier.to_int(), wire)
    assert_eq(tier.to_json().stringify(), wire.to_string())
    let nsfw = @model.NsfwLevel::from_int(wire)
    assert_eq(nsfw.to_int(), wire)
    assert_eq(nsfw.to_json().stringify(), wire.to_string())
  }
}

///|
test "remaining scheduled-event and onboarding enum values round-trip" {
  let privacy = @model.GuildScheduledEventPrivacyLevel::from_int(2)
  assert_eq(privacy.to_int(), 2)
  assert_eq(privacy.to_json().stringify(), "2")
  for wire in [0, 1] {
    let prompt = @model.OnboardingPromptType::from_int(wire)
    assert_eq(prompt.to_int(), wire)
    assert_eq(prompt.to_json().stringify(), wire.to_string())
    let mode = @model.OnboardingMode::from_int(wire)
    assert_eq(mode.to_int(), wire)
    assert_eq(mode.to_json().stringify(), wire.to_string())
  }
}

///|
test "round-two enum decoders pin their wrong-shape errors" {
  let wrong = Json::boolean(false)
  expect_model_decode_error(
    wrong,
    "expected base theme (number)",
    @model.BaseTheme::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a reaction type (number)",
    @model.ReactionType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a message type (number)",
    @model.MessageType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected a message activity (number)",
    @model.MessageActivityType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected a message reference (number)",
    @model.MessageReferenceType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected guild verification level (number)",
    @model.VerificationLevel::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected default message notification level (number)",
    @model.DefaultMessageNotifications::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected explicit content filter level (number)",
    @model.ExplicitContentFilter::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected guild MFA level (number)",
    @model.MfaLevel::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected guild premium tier (number)",
    @model.PremiumTier::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected guild NSFW level (number)",
    @model.NsfwLevel::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected connection service (string)",
    @model.ConnectionService::from_string("github"),
  )
  expect_model_decode_error(
    wrong,
    "expected onboarding prompt type (number)",
    @model.OnboardingPromptType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected onboarding mode (number)",
    @model.OnboardingMode::from_int(0),
  )
}

///|
test "round-two malformed integer representations pin flag decode errors" {
  let malformed = Json::number(1, repr="not-an-integer")
  expect_model_decode_error(
    malformed,
    "expected message flags (number), got not-an-integer",
    @model.MessageFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    malformed,
    "expected guild member flags (number), got not-an-integer",
    @model.GuildMemberFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    malformed,
    "expected user flags (number), got not-an-integer",
    @model.UserFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    malformed,
    "expected role flags (number), got not-an-integer",
    @model.RoleFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    malformed,
    "expected invite flags (number)",
    @model.InviteFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    malformed,
    "expected activity flags (number)",
    @model.ActivityFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    malformed,
    "expected embed flags (number)",
    @model.EmbedFlags::from_bits(0UL),
  )
}
