///|
test "application flag constants pin exact bits and bit operations" {
  let cases : Array[(@model.ApplicationFlags, UInt64)] = [
    (@model.ApplicationFlags::embedded_released(), 1UL << 1),
    (@model.ApplicationFlags::managed_emoji(), 1UL << 2),
    (@model.ApplicationFlags::embedded_iap(), 1UL << 3),
    (@model.ApplicationFlags::group_dm_create(), 1UL << 4),
    (
      @model.ApplicationFlags::application_auto_moderation_rule_create_badge(),
      1UL << 6,
    ),
    (@model.ApplicationFlags::rpc_has_connected(), 1UL << 11),
    (@model.ApplicationFlags::gateway_presence(), 1UL << 12),
    (@model.ApplicationFlags::gateway_presence_limited(), 1UL << 13),
    (@model.ApplicationFlags::gateway_guild_members(), 1UL << 14),
    (@model.ApplicationFlags::gateway_guild_members_limited(), 1UL << 15),
    (@model.ApplicationFlags::verification_pending_guild_limit(), 1UL << 16),
    (@model.ApplicationFlags::embedded(), 1UL << 17),
    (@model.ApplicationFlags::gateway_message_content(), 1UL << 18),
    (@model.ApplicationFlags::gateway_message_content_limited(), 1UL << 19),
    (@model.ApplicationFlags::embedded_first_party(), 1UL << 20),
    (@model.ApplicationFlags::application_command_badge(), 1UL << 23),
  ]
  for item in cases {
    let (flag, expected) = item
    assert_eq(flag.bits(), expected)
  }
  let presence = @model.ApplicationFlags::gateway_presence()
  let content = @model.ApplicationFlags::gateway_message_content()
  let combined = presence | content
  assert_eq(@model.ApplicationFlags::none().bits(), 0UL)
  assert_true(combined.contains(presence))
  assert_eq((combined & content).bits(), content.bits())
}

///|
test "attachment and channel flag constants pin exact bits" {
  let attachment_cases : Array[(@model.AttachmentFlags, UInt64)] = [
    (@model.AttachmentFlags::is_clip(), 1UL << 0),
    (@model.AttachmentFlags::is_thumbnail(), 1UL << 1),
    (@model.AttachmentFlags::is_remix(), 1UL << 2),
    (@model.AttachmentFlags::is_spoiler(), 1UL << 3),
    (@model.AttachmentFlags::is_animated(), 1UL << 5),
  ]
  for item in attachment_cases {
    let (flag, expected) = item
    assert_eq(flag.bits(), expected)
  }
  let clip = @model.AttachmentFlags::is_clip()
  let animated = @model.AttachmentFlags::is_animated()
  assert_eq(@model.AttachmentFlags::none().bits(), 0UL)
  assert_eq(((clip | animated) & animated).bits(), animated.bits())
  let channel_cases : Array[(@model.ChannelFlags, UInt64)] = [
    (@model.ChannelFlags::guild_feed_removed(), 1UL << 0),
    (@model.ChannelFlags::pinned(), 1UL << 1),
    (@model.ChannelFlags::active_channels_removed(), 1UL << 2),
    (@model.ChannelFlags::require_tag(), 1UL << 4),
    (@model.ChannelFlags::is_spam(), 1UL << 5),
    (@model.ChannelFlags::is_guild_resource_channel(), 1UL << 7),
    (@model.ChannelFlags::clyde_ai(), 1UL << 8),
    (@model.ChannelFlags::is_scheduled_for_deletion(), 1UL << 9),
    (@model.ChannelFlags::hide_media_download_options(), 1UL << 15),
  ]
  for item in channel_cases {
    let (flag, expected) = item
    assert_eq(flag.bits(), expected)
  }
  let pinned = @model.ChannelFlags::pinned()
  let tagged = @model.ChannelFlags::require_tag()
  let combined = pinned | tagged
  assert_eq(@model.ChannelFlags::none().bits(), 0UL)
  assert_true(combined.contains(pinned))
  assert_false(pinned.contains(tagged))
  assert_eq((combined & tagged).bits(), tagged.bits())
}

///|
test "guild, member, and message flag constants pin exact bits" {
  let system_cases : Array[(@model.SystemChannelFlags, UInt64)] = [
    (@model.SystemChannelFlags::suppress_join_notifications(), 1UL << 0),
    (@model.SystemChannelFlags::suppress_premium_subscriptions(), 1UL << 1),
    (
      @model.SystemChannelFlags::suppress_guild_reminder_notifications(),
      1UL << 2,
    ),
    (@model.SystemChannelFlags::suppress_join_notification_replies(), 1UL << 3),
    (
      @model.SystemChannelFlags::suppress_role_subscription_purchase_notifications(),
      1UL << 4,
    ),
    (
      @model.SystemChannelFlags::suppress_role_subscription_purchase_notification_replies(),
      1UL << 5,
    ),
  ]
  for item in system_cases {
    let (flag, expected) = item
    assert_eq(flag.bits(), expected)
  }
  let joins = @model.SystemChannelFlags::suppress_join_notifications()
  let replies = @model.SystemChannelFlags::suppress_join_notification_replies()
  assert_eq(@model.SystemChannelFlags::none().bits(), 0UL)
  assert_eq(((joins | replies) & replies).bits(), replies.bits())
  let member_cases : Array[(@model.GuildMemberFlags, UInt64)] = [
    (@model.GuildMemberFlags::did_rejoin(), 1UL << 0),
    (@model.GuildMemberFlags::completed_onboarding(), 1UL << 1),
    (@model.GuildMemberFlags::bypasses_verification(), 1UL << 2),
    (@model.GuildMemberFlags::started_onboarding(), 1UL << 3),
    (@model.GuildMemberFlags::is_guest(), 1UL << 4),
    (@model.GuildMemberFlags::started_home_actions(), 1UL << 5),
    (@model.GuildMemberFlags::completed_home_actions(), 1UL << 6),
    (
      @model.GuildMemberFlags::automod_quarantined_username_or_guild_nickname(),
      1UL << 7,
    ),
    (@model.GuildMemberFlags::automod_quarantined_bio(), 1UL << 8),
    (@model.GuildMemberFlags::dm_settings_upsell_acknowledged(), 1UL << 9),
    (@model.GuildMemberFlags::auto_mod_quarantined_guild_tag(), 1UL << 10),
  ]
  for item in member_cases {
    let (flag, expected) = item
    assert_eq(flag.bits(), expected)
  }
  let guest = @model.GuildMemberFlags::is_guest()
  let bio = @model.GuildMemberFlags::automod_quarantined_bio()
  assert_eq(((guest | bio) & bio).bits(), bio.bits())
  let message_cases : Array[(@model.MessageFlags, UInt64)] = [
    (@model.MessageFlags::crossposted(), 1UL << 0),
    (@model.MessageFlags::is_crosspost(), 1UL << 1),
    (@model.MessageFlags::suppress_embeds(), 1UL << 2),
    (@model.MessageFlags::source_message_deleted(), 1UL << 3),
    (@model.MessageFlags::urgent(), 1UL << 4),
    (@model.MessageFlags::has_thread(), 1UL << 5),
    (@model.MessageFlags::ephemeral(), 1UL << 6),
    (@model.MessageFlags::loading(), 1UL << 7),
    (@model.MessageFlags::failed_to_mention_some_roles_in_thread(), 1UL << 8),
    (@model.MessageFlags::should_show_link_not_discord_warning(), 1UL << 10),
    (@model.MessageFlags::suppress_notifications(), 1UL << 12),
    (@model.MessageFlags::is_voice_message(), 1UL << 13),
    (@model.MessageFlags::has_snapshot(), 1UL << 14),
    (@model.MessageFlags::is_components_v2(), 1UL << 15),
  ]
  for item in message_cases {
    let (flag, expected) = item
    assert_eq(flag.bits(), expected)
  }
  let urgent = @model.MessageFlags::urgent()
  let voice = @model.MessageFlags::is_voice_message()
  let combined = urgent | voice
  assert_eq(@model.MessageFlags::none().bits(), 0UL)
  assert_true(combined.contains(voice))
  assert_eq((combined & voice).bits(), voice.bits())
}

///|
test "SKU, role, invite, embed, and activity flags pin wire values" {
  let available = @model.SkuFlags::available()
  let guild = @model.SkuFlags::guild_subscription()
  let user = @model.SkuFlags::user_subscription()
  assert_eq(available.bits(), 1UL << 2)
  assert_eq(guild.bits(), 1UL << 7)
  assert_eq(user.bits(), 1UL << 8)
  let sku = available | guild | user
  assert_eq(@model.SkuFlags::none().bits(), 0UL)
  assert_true(sku.contains(guild))
  assert_eq((sku & user).bits(), user.bits())
  let prompt = @model.RoleFlags::in_prompt()
  assert_eq(prompt.bits(), 1UL)
  assert_eq(((@model.RoleFlags::none() | prompt) & prompt).bits(), 1UL)
  assert_eq(@model.InviteFlags::is_guest_invite().bits(), 1UL)
  assert_eq(@model.EmbedFlags::is_content_inventory_entry().bits(), 1UL << 5)
  let activity = @model.ActivityFlags::from_bits(257UL)
  assert_eq(activity.bits(), 257UL)
  assert_eq(activity.to_json().stringify(), "257")
}

///|
test "every user flag constant pins its exact bit" {
  let cases : Array[(@model.UserFlags, UInt64)] = [
    (@model.UserFlags::staff(), 1UL << 0),
    (@model.UserFlags::partner(), 1UL << 1),
    (@model.UserFlags::hypesquad(), 1UL << 2),
    (@model.UserFlags::bug_hunter_level_1(), 1UL << 3),
    (@model.UserFlags::mfa_sms(), 1UL << 4),
    (@model.UserFlags::premium_promo_dismissed(), 1UL << 5),
    (@model.UserFlags::hype_squad_online_house_1(), 1UL << 6),
    (@model.UserFlags::hype_squad_online_house_2(), 1UL << 7),
    (@model.UserFlags::hype_squad_online_house_3(), 1UL << 8),
    (@model.UserFlags::premium_early_supporter(), 1UL << 9),
    (@model.UserFlags::team_pseudo_user(), 1UL << 10),
    (@model.UserFlags::has_unread_urgent_messages(), 1UL << 13),
    (@model.UserFlags::bug_hunter_level_2(), 1UL << 14),
    (@model.UserFlags::verified_bot(), 1UL << 16),
    (@model.UserFlags::verified_developer(), 1UL << 17),
    (@model.UserFlags::certified_moderator(), 1UL << 18),
    (@model.UserFlags::bot_http_interactions(), 1UL << 19),
    (@model.UserFlags::spammer(), 1UL << 20),
    (@model.UserFlags::disable_premium(), 1UL << 21),
    (@model.UserFlags::active_developer(), 1UL << 22),
    (@model.UserFlags::quarantined(), 1UL << 44),
    (@model.UserFlags::collaborator(), 1UL << 50),
    (@model.UserFlags::restricted_collaborator(), 1UL << 51),
  ]
  for item in cases {
    let (flag, expected) = item
    assert_eq(flag.bits(), expected)
  }
  let staff = @model.UserFlags::staff()
  let active = @model.UserFlags::active_developer()
  let combined = staff | active
  assert_eq(@model.UserFlags::none().bits(), 0UL)
  assert_true(combined.contains(active))
  assert_eq((combined & active).bits(), active.bits())
}

///|
test "numeric flag decoders reject non-numbers and negative representations" {
  let non_number = Json::string("flags")
  expect_model_decode_error(
    Json::string("flags"),
    "expected application flags (integer string), got flags",
    @model.ApplicationFlags::none(),
  )
  expect_model_decode_error(
    Json::number(1, repr="bad"),
    "expected application flags (number), got \\{repr}",
    @model.ApplicationFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected attachment flags (number)",
    @model.AttachmentFlags::none(),
  )
  expect_model_decode_error(
    Json::number(1, repr="bad"),
    "expected attachment flags (number), got bad",
    @model.AttachmentFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected channel flags (number)",
    @model.ChannelFlags::none(),
  )
  expect_model_decode_error(
    Json::number(1, repr="bad"),
    "expected channel flags (number), got bad",
    @model.ChannelFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected system channel flags (number)",
    @model.SystemChannelFlags::none(),
  )
  expect_model_decode_error(
    Json::number(1, repr="bad"),
    "expected system channel flags (number), got bad",
    @model.SystemChannelFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected guild member flags (number)",
    @model.GuildMemberFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected message flags (number)",
    @model.MessageFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected SKU flags (number)",
    @model.SkuFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected user flags (number)",
    @model.UserFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected role flags (number)",
    @model.RoleFlags::none(),
  )
  expect_model_decode_error(
    non_number,
    "expected invite flags (number)",
    @model.InviteFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    non_number,
    "expected embed flags (number)",
    @model.EmbedFlags::from_bits(0UL),
  )
  expect_model_decode_error(
    non_number,
    "expected activity flags (number)",
    @model.ActivityFlags::from_bits(0UL),
  )
}
