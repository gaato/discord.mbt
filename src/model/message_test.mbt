///|
test "message decodes a full fixture with a string nonce and nested reference" {
  let fixture =
    #|{
    #|  "id": "100000000000000001",
    #|  "channel_id": "41771983423143937",
    #|  "author": {
    #|    "id": "80351110224678912",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "content": "Hello from a reply",
    #|  "timestamp": "2024-02-03T04:05:06.000000+00:00",
    #|  "edited_timestamp": null,
    #|  "tts": false,
    #|  "mention_everyone": false,
    #|  "mentions": [{
    #|    "id": "811111111111111111",
    #|    "username": "Mochi",
    #|    "discriminator": "0",
    #|    "global_name": null,
    #|    "avatar": null
    #|  }],
    #|  "mention_roles": ["41771983423143936"],
    #|  "mention_channels": [{
    #|    "id": "41771983423143937",
    #|    "guild_id": "81384788765712384",
    #|    "type": 0,
    #|    "name": "general"
    #|  }],
    #|  "attachments": [{
    #|    "id": "905000000000000001",
    #|    "filename": "notes.txt",
    #|    "size": 42,
    #|    "url": "https://cdn.discordapp.com/notes.txt",
    #|    "proxy_url": "https://media.discordapp.net/notes.txt"
    #|  }],
    #|  "embeds": [{
    #|    "type": "rich",
    #|    "description": "Embedded context"
    #|  }],
    #|  "reactions": [{
    #|    "count": 3,
    #|    "count_details": {"burst": 1, "normal": 2},
    #|    "me": true,
    #|    "me_burst": false,
    #|    "emoji": {"id": null, "name": "👍"},
    #|    "burst_colors": ["#FF73FA"]
    #|  }],
    #|  "nonce": "client-123",
    #|  "pinned": true,
    #|  "webhook_id": "955000000000000001",
    #|  "type": 19,
    #|  "activity": {"type": 1, "party_id": "party-1"},
    #|  "application_id": "965000000000000001",
    #|  "message_reference": {
    #|    "type": 0,
    #|    "message_id": "100000000000000000",
    #|    "channel_id": "41771983423143937",
    #|    "guild_id": "81384788765712384",
    #|    "fail_if_not_exists": true
    #|  },
    #|  "flags": 64,
    #|  "referenced_message": {
    #|    "id": "100000000000000000",
    #|    "channel_id": "41771983423143937",
    #|    "author": {
    #|      "id": "811111111111111111",
    #|      "username": "Mochi",
    #|      "discriminator": "0",
    #|      "global_name": null,
    #|      "avatar": null
    #|    },
    #|    "content": "Original message",
    #|    "timestamp": "2024-02-03T04:00:00.000000+00:00",
    #|    "edited_timestamp": null,
    #|    "tts": false,
    #|    "mention_everyone": false,
    #|    "mentions": [],
    #|    "mention_roles": [],
    #|    "attachments": [],
    #|    "embeds": [],
    #|    "pinned": false,
    #|    "type": 0
    #|  },
    #|  "thread": {"id": "100000000000000001", "type": 11},
    #|  "components": [{
    #|    "type": 1,
    #|    "components": [{
    #|      "type": 2,
    #|      "style": 1,
    #|      "label": "Open",
    #|      "custom_id": "open-message"
    #|    }]
    #|  }],
    #|  "sticker_items": [{
    #|    "id": "749054660769218631",
    #|    "name": "Wave",
    #|    "format_type": 1
    #|  }],
    #|  "position": 12,
    #|  "role_subscription_data": {
    #|    "role_subscription_listing_id": "1144058844004233369",
    #|    "tier_name": "Supporter",
    #|    "total_months_subscribed": 6,
    #|    "is_renewal": true
    #|  },
    #|  "call": {
    #|    "participants": ["80351110224678912"],
    #|    "ended_timestamp": null
    #|  },
    #|  "brand_new_field_from_discord": true
    #|}
  let message : @model.Message = @json.from_json(@json.parse(fixture))
  debug_inspect(
    message,
    content=(
      #|{
      #|  id: 100000000000000001,
      #|  channel_id: 41771983423143937,
      #|  author: {
      #|    id: 80351110224678912,
      #|    username: "Nelly",
      #|    discriminator: "0",
      #|    global_name: Value("Nelly"),
      #|    avatar: Null,
      #|    bot: None,
      #|    system: None,
      #|    mfa_enabled: None,
      #|    banner: None,
      #|    accent_color: None,
      #|    locale: None,
      #|    verified: None,
      #|    email: None,
      #|    flags: None,
      #|    premium_type: None,
      #|    public_flags: None,
      #|    avatar_decoration: None,
      #|    avatar_decoration_data: None,
      #|  },
      #|  content: "Hello from a reply",
      #|  timestamp: "2024-02-03T04:05:06.000000+00:00",
      #|  edited_timestamp: Null,
      #|  tts: false,
      #|  mention_everyone: false,
      #|  mentions: [
      #|    {
      #|      id: 811111111111111111,
      #|      username: "Mochi",
      #|      discriminator: "0",
      #|      global_name: Null,
      #|      avatar: Null,
      #|      bot: None,
      #|      system: None,
      #|      mfa_enabled: None,
      #|      banner: None,
      #|      accent_color: None,
      #|      locale: None,
      #|      verified: None,
      #|      email: None,
      #|      flags: None,
      #|      premium_type: None,
      #|      public_flags: None,
      #|      avatar_decoration: None,
      #|      avatar_decoration_data: None,
      #|    },
      #|  ],
      #|  mention_roles: [41771983423143936],
      #|  mention_channels: Some(
      #|    [
      #|      {
      #|        id: 41771983423143937,
      #|        guild_id: 81384788765712384,
      #|        typ: GuildText,
      #|        name: "general",
      #|      },
      #|    ],
      #|  ),
      #|  attachments: [
      #|    {
      #|      id: 905000000000000001,
      #|      filename: "notes.txt",
      #|      title: None,
      #|      description: None,
      #|      content_type: None,
      #|      size: 42,
      #|      url: "https://cdn.discordapp.com/notes.txt",
      #|      proxy_url: "https://media.discordapp.net/notes.txt",
      #|      height: None,
      #|      width: None,
      #|      ephemeral: None,
      #|      duration_secs: None,
      #|      waveform: None,
      #|      flags: None,
      #|    },
      #|  ],
      #|  embeds: [
      #|    {
      #|      title: None,
      #|      typ: Some(Rich),
      #|      url: None,
      #|      description: Some("Embedded context"),
      #|      timestamp: None,
      #|      color: None,
      #|      footer: None,
      #|      image: None,
      #|      thumbnail: None,
      #|      video: None,
      #|      provider: None,
      #|      author: None,
      #|      fields: None,
      #|    },
      #|  ],
      #|  reactions: Some(
      #|    [
      #|      {
      #|        count: 3,
      #|        count_details: { burst: 1, normal: 2 },
      #|        me: true,
      #|        me_burst: false,
      #|        emoji: {
      #|          id: Null,
      #|          name: Value("👍"),
      #|          animated: None,
      #|          roles: None,
      #|          user: None,
      #|          require_colons: None,
      #|          managed: None,
      #|          available: None,
      #|        },
      #|        burst_colors: ["#FF73FA"],
      #|      },
      #|    ],
      #|  ),
      #|  nonce: Some(Str("client-123")),
      #|  pinned: true,
      #|  webhook_id: Some(955000000000000001),
      #|  typ: Reply,
      #|  activity: Some({ typ: Join, party_id: Some("party-1") }),
      #|  application_id: Some(965000000000000001),
      #|  message_reference: Some(
      #|    {
      #|      typ: Some(Default),
      #|      message_id: Some(100000000000000000),
      #|      channel_id: Some(41771983423143937),
      #|      guild_id: Some(81384788765712384),
      #|      fail_if_not_exists: Some(true),
      #|    },
      #|  ),
      #|  flags: Some(64),
      #|  referenced_message: Some(
      #|    Value(
      #|      {
      #|        id: 100000000000000000,
      #|        channel_id: 41771983423143937,
      #|        author: {
      #|          id: 811111111111111111,
      #|          username: "Mochi",
      #|          discriminator: "0",
      #|          global_name: Null,
      #|          avatar: Null,
      #|          bot: None,
      #|          system: None,
      #|          mfa_enabled: None,
      #|          banner: None,
      #|          accent_color: None,
      #|          locale: None,
      #|          verified: None,
      #|          email: None,
      #|          flags: None,
      #|          premium_type: None,
      #|          public_flags: None,
      #|          avatar_decoration: None,
      #|          avatar_decoration_data: None,
      #|        },
      #|        content: "Original message",
      #|        timestamp: "2024-02-03T04:00:00.000000+00:00",
      #|        edited_timestamp: Null,
      #|        tts: false,
      #|        mention_everyone: false,
      #|        mentions: [],
      #|        mention_roles: [],
      #|        mention_channels: None,
      #|        attachments: [],
      #|        embeds: [],
      #|        reactions: None,
      #|        nonce: None,
      #|        pinned: false,
      #|        webhook_id: None,
      #|        typ: Default,
      #|        activity: None,
      #|        application_id: None,
      #|        message_reference: None,
      #|        flags: None,
      #|        referenced_message: None,
      #|        thread: None,
      #|        components: None,
      #|        sticker_items: None,
      #|        position: None,
      #|        role_subscription_data: None,
      #|        poll: None,
      #|        call: None,
      #|      },
      #|    ),
      #|  ),
      #|  thread: Some(
      #|    {
      #|      id: 100000000000000001,
      #|      typ: PublicThread,
      #|      guild_id: None,
      #|      position: None,
      #|      permission_overwrites: None,
      #|      name: None,
      #|      topic: None,
      #|      nsfw: None,
      #|      last_message_id: None,
      #|      bitrate: None,
      #|      user_limit: None,
      #|      rate_limit_per_user: None,
      #|      recipients: None,
      #|      icon: None,
      #|      owner_id: None,
      #|      application_id: None,
      #|      managed: None,
      #|      parent_id: None,
      #|      last_pin_timestamp: None,
      #|      rtc_region: None,
      #|      video_quality_mode: None,
      #|      message_count: None,
      #|      member_count: None,
      #|      thread_metadata: None,
      #|      thread_member: None,
      #|      default_auto_archive_duration: None,
      #|      permissions: None,
      #|      flags: None,
      #|      total_message_sent: None,
      #|      available_tags: None,
      #|      applied_tags: None,
      #|      default_reaction_emoji: None,
      #|      default_thread_rate_limit_per_user: None,
      #|      default_sort_order: None,
      #|      default_forum_layout: None,
      #|    },
      #|  ),
      #|  components: Some(
      #|    [
      #|      ActionRow(
      #|        {
      #|          id: None,
      #|          components: [
      #|            Button(
      #|              {
      #|                id: None,
      #|                style: Primary,
      #|                label: Some("Open"),
      #|                emoji: None,
      #|                custom_id: Some("open-message"),
      #|                sku_id: None,
      #|                url: None,
      #|                disabled: None,
      #|              },
      #|            ),
      #|          ],
      #|        },
      #|      ),
      #|    ],
      #|  ),
      #|  sticker_items: Some([{ id: 749054660769218631, name: "Wave", format_type: Png }]),
      #|  position: Some(12),
      #|  role_subscription_data: Some(
      #|    {
      #|      role_subscription_listing_id: 1144058844004233369,
      #|      tier_name: "Supporter",
      #|      total_months_subscribed: 6,
      #|      is_renewal: true,
      #|    },
      #|  ),
      #|  poll: None,
      #|  call: Some({ participants: [80351110224678912], ended_timestamp: Some(Null) }),
      #|}
    ),
  )
}

///|
test "message decodes an integer nonce without losing precision" {
  let fixture =
    #|{
    #|  "id": "100000000000000002",
    #|  "channel_id": "41771983423143937",
    #|  "author": {
    #|    "id": "80351110224678912",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": null,
    #|    "avatar": null
    #|  },
    #|  "content": "nonce test",
    #|  "timestamp": "2024-02-03T04:05:06.000000+00:00",
    #|  "edited_timestamp": null,
    #|  "tts": false,
    #|  "mention_everyone": false,
    #|  "mentions": [],
    #|  "mention_roles": [],
    #|  "attachments": [],
    #|  "embeds": [],
    #|  "nonce": 9007199254740993,
    #|  "pinned": false,
    #|  "type": 0
    #|}
  let message : @model.Message = @json.from_json(@json.parse(fixture))
  debug_inspect(
    message.nonce,
    content=(
      #|Some(Num(9007199254740993))
    ),
  )
  guard message.nonce is Some(nonce) else { fail("expected nonce") }
  inspect(
    nonce.to_json().stringify(),
    content=(
      #|9007199254740993
    ),
  )
}

///|
test "message encode omits absent optional fields" {
  let author : @model.User = {
    id: @model.Id(2UL),
    username: "neko",
    discriminator: "0",
    global_name: @model.Nullable::Null,
    avatar: @model.Nullable::Null,
    bot: None,
    system: None,
    mfa_enabled: None,
    banner: None,
    accent_color: None,
    locale: None,
    verified: None,
    email: None,
    flags: None,
    premium_type: None,
    public_flags: None,
    avatar_decoration: None,
    avatar_decoration_data: None,
  }
  let message : @model.Message = {
    id: @model.Id(1UL),
    channel_id: @model.Id(3UL),
    author,
    content: "hello",
    timestamp: @model.Timestamp("2024-01-01T00:00:00Z"),
    edited_timestamp: @model.Nullable::Null,
    tts: false,
    mention_everyone: false,
    mentions: [],
    mention_roles: [],
    mention_channels: None,
    attachments: [],
    embeds: [],
    reactions: None,
    nonce: None,
    pinned: false,
    webhook_id: None,
    typ: @model.MessageType::Default,
    activity: None,
    application_id: None,
    message_reference: None,
    flags: None,
    referenced_message: None,
    thread: None,
    components: None,
    sticker_items: None,
    position: None,
    role_subscription_data: None,
    poll: None,
    call: None,
  }
  inspect(
    message.to_json().stringify(),
    content=(
      #|{"id":"1","channel_id":"3","author":{"id":"2","username":"neko","discriminator":"0","global_name":null,"avatar":null},"content":"hello","timestamp":"2024-01-01T00:00:00Z","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
    ),
  )
}

///|
test "message wire enums and flags preserve unknown values" {
  let known : @model.MessageType = @json.from_json(@json.parse("46"))
  debug_inspect(
    known,
    content=(
      #|PollResult
    ),
  )
  let unknown : @model.MessageType = @json.from_json(@json.parse("99"))
  debug_inspect(
    unknown,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    unknown.to_json().stringify(),
    content=(
      #|99
    ),
  )
  let activity : @model.MessageActivityType = @json.from_json(@json.parse("98"))
  debug_inspect(
    activity,
    content=(
      #|Unknown(98)
    ),
  )
  let reference : @model.MessageReferenceType = @json.from_json(
    @json.parse("97"),
  )
  debug_inspect(
    reference,
    content=(
      #|Unknown(97)
    ),
  )
  let unknown_bits = (1UL << 60) | 64UL
  let flags = @model.MessageFlags::from_bits(unknown_bits)
  let encoded = flags.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|1152921504606847040
    ),
  )
  let decoded : @model.MessageFlags = @json.from_json(@json.parse(encoded))
  assert_true(decoded.bits() == unknown_bits)
}
