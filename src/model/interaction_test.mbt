///|
test "slash command autocomplete dispatches command data with resolved users" {
  let fixture =
    #|{
    #|  "id": "108000000000000001",
    #|  "application_id": "172150183260323840",
    #|  "type": 4,
    #|  "data": {
    #|    "id": "107000000000000001",
    #|    "name": "search",
    #|    "type": 1,
    #|    "resolved": {
    #|      "users": {
    #|        "80351110224678912": {
    #|          "id": "80351110224678912",
    #|          "username": "Nelly",
    #|          "discriminator": "0",
    #|          "global_name": "Nelly",
    #|          "avatar": null
    #|        }
    #|      }
    #|    },
    #|    "options": [{
    #|      "name": "query",
    #|      "type": 3,
    #|      "value": "ne",
    #|      "focused": true
    #|    }],
    #|    "guild_id": "81384788765712384"
    #|  },
    #|  "guild_id": "81384788765712384",
    #|  "channel": {
    #|    "id": "41771983423143937",
    #|    "type": 0,
    #|    "name": "bot-commands"
    #|  },
    #|  "channel_id": "41771983423143937",
    #|  "user": {
    #|    "id": "80351110224678912",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "token": "interaction-token",
    #|  "version": 1,
    #|  "app_permissions": "2048",
    #|  "locale": "en-US",
    #|  "guild_locale": "ja",
    #|  "entitlements": [{
    #|    "id": "125000000000000001",
    #|    "sku_id": "125000000000000002",
    #|    "application_id": "172150183260323840",
    #|    "user_id": "80351110224678912",
    #|    "type": 1,
    #|    "deleted": false,
    #|    "starts_at": null,
    #|    "ends_at": null,
    #|    "future": true
    #|  }],
    #|  "context": 0,
    #|  "brand_new_field_from_discord": true
    #|}
  let interaction : @model.Interaction = @json.from_json(@json.parse(fixture))
  debug_inspect(
    interaction,
    content=(
      #|{
      #|  id: 108000000000000001,
      #|  application_id: 172150183260323840,
      #|  typ: ApplicationCommandAutocomplete,
      #|  data: Some(
      #|    Command(
      #|      {
      #|        id: 107000000000000001,
      #|        name: "search",
      #|        typ: ChatInput,
      #|        resolved: Some(
      #|          {
      #|            users: Some(
      #|              {
      #|                "80351110224678912": {
      #|                  id: 80351110224678912,
      #|                  username: "Nelly",
      #|                  discriminator: "0",
      #|                  global_name: Some(Value("Nelly")),
      #|                  avatar: Null,
      #|                  bot: None,
      #|                  system: None,
      #|                  mfa_enabled: None,
      #|                  banner: None,
      #|                  accent_color: None,
      #|                  locale: None,
      #|                  verified: None,
      #|                  email: None,
      #|                  flags: None,
      #|                  premium_type: None,
      #|                  public_flags: None,
      #|                  avatar_decoration: None,
      #|                  avatar_decoration_data: None,
      #|                },
      #|              },
      #|            ),
      #|            members: None,
      #|            roles: None,
      #|            channels: None,
      #|            messages: None,
      #|            attachments: None,
      #|          },
      #|        ),
      #|        options: Some(
      #|          [
      #|            {
      #|              name: "query",
      #|              typ: String,
      #|              value: Some(String("ne")),
      #|              options: None,
      #|              focused: Some(true),
      #|            },
      #|          ],
      #|        ),
      #|        guild_id: Some(81384788765712384),
      #|        target_id: None,
      #|      },
      #|    ),
      #|  ),
      #|  guild_id: Some(81384788765712384),
      #|  channel: Some(
      #|    {
      #|      id: 41771983423143937,
      #|      typ: GuildText,
      #|      guild_id: None,
      #|      position: None,
      #|      permission_overwrites: None,
      #|      name: Some(Value("bot-commands")),
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
      #|  channel_id: Some(41771983423143937),
      #|  guild_member: None,
      #|  user: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Some(Value("Nelly")),
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
      #|  ),
      #|  token: "interaction-token",
      #|  version: 1,
      #|  message: None,
      #|  app_permissions: Some(2048),
      #|  locale: Some("en-US"),
      #|  guild_locale: Some("ja"),
      #|  entitlements: Some(
      #|    [
      #|      {
      #|        id: 125000000000000001,
      #|        sku_id: 125000000000000002,
      #|        application_id: 172150183260323840,
      #|        user_id: Some(80351110224678912),
      #|        typ: Purchase,
      #|        deleted: false,
      #|        starts_at: Null,
      #|        ends_at: Null,
      #|        guild_id: None,
      #|        consumed: None,
      #|      },
      #|    ],
      #|  ),
      #|  context: Some(Guild),
      #|}
    ),
  )
  match interaction.data {
    Some(@model.InteractionData::Command(data)) => {
      assert_true(
        data.options is Some(options) && options[0].focused == Some(true),
      )
      assert_true(data.resolved is Some(resolved) && resolved.users is Some(_))
    }
    _ => fail("expected command interaction data")
  }
}

///|
test "button interaction dispatches component data" {
  let fixture =
    #|{
    #|  "id": "108000000000000002",
    #|  "application_id": "172150183260323840",
    #|  "type": 3,
    #|  "data": {"custom_id": "confirm", "component_type": 2},
    #|  "channel_id": "41771983423143937",
    #|  "token": "button-token",
    #|  "version": 1,
    #|  "locale": "en-US",
    #|  "future": true
    #|}
  let interaction : @model.Interaction = @json.from_json(@json.parse(fixture))
  debug_inspect(
    interaction,
    content=(
      #|{
      #|  id: 108000000000000002,
      #|  application_id: 172150183260323840,
      #|  typ: MessageComponent,
      #|  data: Some(
      #|    Component(
      #|      {
      #|        custom_id: "confirm",
      #|        component_type: 2,
      #|        values: None,
      #|        resolved: None,
      #|      },
      #|    ),
      #|  ),
      #|  guild_id: None,
      #|  channel: None,
      #|  channel_id: Some(41771983423143937),
      #|  guild_member: None,
      #|  user: None,
      #|  token: "button-token",
      #|  version: 1,
      #|  message: None,
      #|  app_permissions: None,
      #|  locale: Some("en-US"),
      #|  guild_locale: None,
      #|  entitlements: None,
      #|  context: None,
      #|}
    ),
  )
  match interaction.data {
    Some(@model.InteractionData::Component(data)) => {
      assert_true(data.custom_id == "confirm")
      assert_true(data.component_type == 2)
    }
    _ => fail("expected component interaction data")
  }
}

///|
test "modal submit dispatches recursive components" {
  let fixture =
    #|{
    #|  "id": "108000000000000003",
    #|  "application_id": "172150183260323840",
    #|  "type": 5,
    #|  "data": {
    #|    "custom_id": "feedback-modal",
    #|    "components": [{
    #|      "type": 1,
    #|      "components": [{
    #|        "type": 4,
    #|        "custom_id": "feedback",
    #|        "style": 2,
    #|        "label": "Feedback",
    #|        "value": "Great library"
    #|      }]
    #|    }]
    #|  },
    #|  "token": "modal-token",
    #|  "version": 1,
    #|  "locale": "en-US",
    #|  "brand_new_field_from_discord": true
    #|}
  let interaction : @model.Interaction = @json.from_json(@json.parse(fixture))
  debug_inspect(
    interaction,
    content=(
      #|{
      #|  id: 108000000000000003,
      #|  application_id: 172150183260323840,
      #|  typ: ModalSubmit,
      #|  data: Some(
      #|    Modal(
      #|      {
      #|        custom_id: "feedback-modal",
      #|        components: [
      #|          ActionRow(
      #|            {
      #|              id: None,
      #|              components: [
      #|                TextInput(
      #|                  {
      #|                    id: None,
      #|                    custom_id: "feedback",
      #|                    style: Some(Paragraph),
      #|                    label: Some("Feedback"),
      #|                    min_length: None,
      #|                    max_length: None,
      #|                    required: None,
      #|                    value: Some("Great library"),
      #|                    placeholder: None,
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|        resolved: None,
      #|      },
      #|    ),
      #|  ),
      #|  guild_id: None,
      #|  channel: None,
      #|  channel_id: None,
      #|  guild_member: None,
      #|  user: None,
      #|  token: "modal-token",
      #|  version: 1,
      #|  message: None,
      #|  app_permissions: None,
      #|  locale: Some("en-US"),
      #|  guild_locale: None,
      #|  entitlements: None,
      #|  context: None,
      #|}
    ),
  )
  inspect(
    interaction.to_json().stringify(),
    content=(
      #|{"id":"108000000000000003","application_id":"172150183260323840","type":5,"token":"modal-token","version":1,"locale":"en-US","data":{"custom_id":"feedback-modal","components":[{"components":[{"custom_id":"feedback","style":2,"label":"Feedback","value":"Great library","type":4}],"type":1}]}}
    ),
  )
}

///|
test "unknown interaction type preserves raw data" {
  let fixture =
    #|{
    #|  "id": "108000000000000099",
    #|  "application_id": "172150183260323840",
    #|  "type": 99,
    #|  "data": {
    #|    "future_kind": "quantum-button",
    #|    "nested": [1, true, null],
    #|    "opaque": {"keep": "all of this"}
    #|  },
    #|  "token": "future-token",
    #|  "version": 1,
    #|  "future_outer_field": "ignored"
    #|}
  let interaction : @model.Interaction = @json.from_json(@json.parse(fixture))
  debug_inspect(
    interaction,
    content=(
      #|{
      #|  id: 108000000000000099,
      #|  application_id: 172150183260323840,
      #|  typ: Unknown(99),
      #|  data: Some(
      #|    Unknown(
      #|      Object(
      #|        {
      #|          "future_kind": String("quantum-button"),
      #|          "nested": Array([Number(1), True, Null]),
      #|          "opaque": Object({ "keep": String("all of this") }),
      #|        },
      #|      ),
      #|    ),
      #|  ),
      #|  guild_id: None,
      #|  channel: None,
      #|  channel_id: None,
      #|  guild_member: None,
      #|  user: None,
      #|  token: "future-token",
      #|  version: 1,
      #|  message: None,
      #|  app_permissions: None,
      #|  locale: None,
      #|  guild_locale: None,
      #|  entitlements: None,
      #|  context: None,
      #|}
    ),
  )
  let encoded = interaction.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|{"id":"108000000000000099","application_id":"172150183260323840","type":99,"token":"future-token","version":1,"data":{"future_kind":"quantum-button","nested":[1,true,null],"opaque":{"keep":"all of this"}}}
    ),
  )
  let round_tripped : @model.Interaction = @json.from_json(@json.parse(encoded))
  match round_tripped.data {
    Some(@model.InteractionData::Unknown(raw)) =>
      inspect(
        raw.stringify(),
        content=(
          #|{"future_kind":"quantum-button","nested":[1,true,null],"opaque":{"keep":"all of this"}}
        ),
      )
    _ => fail("expected raw unknown interaction data")
  }
}

///|
test "ping interaction decodes without data" {
  let fixture =
    #|{
    #|  "id": "108000000000000004",
    #|  "application_id": "172150183260323840",
    #|  "type": 1,
    #|  "token": "ping-token",
    #|  "version": 1,
    #|  "future": true
    #|}
  let interaction : @model.Interaction = @json.from_json(@json.parse(fixture))
  debug_inspect(
    interaction,
    content=(
      #|{
      #|  id: 108000000000000004,
      #|  application_id: 172150183260323840,
      #|  typ: Ping,
      #|  data: None,
      #|  guild_id: None,
      #|  channel: None,
      #|  channel_id: None,
      #|  guild_member: None,
      #|  user: None,
      #|  token: "ping-token",
      #|  version: 1,
      #|  message: None,
      #|  app_permissions: None,
      #|  locale: None,
      #|  guild_locale: None,
      #|  entitlements: None,
      #|  context: None,
      #|}
    ),
  )
  assert_true(interaction.data is None)
}

///|
test "interaction response types preserve known and unknown values" {
  let known : @model.InteractionResponseType = @json.from_json(
    @json.parse("12"),
  )
  let unknown : @model.InteractionResponseType = @json.from_json(
    @json.parse("99"),
  )
  debug_inspect(
    known,
    content=(
      #|LaunchActivity
    ),
  )
  debug_inspect(
    unknown,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    [known.to_json(), unknown.to_json()].to_json().stringify(),
    content=(
      #|[12,99]
    ),
  )
}

///|
test "modal data decodes resolved attachments" {
  let fixture =
    #|{
    #|  "custom_id": "upload-form",
    #|  "components": [{
    #|    "type": 18,
    #|    "label": "Receipt",
    #|    "component": {
    #|      "type": 19,
    #|      "custom_id": "receipt",
    #|      "values": ["987654321098765432"]
    #|    }
    #|  }],
    #|  "resolved": {
    #|    "attachments": {
    #|      "987654321098765432": {
    #|        "id": "987654321098765432",
    #|        "filename": "receipt.pdf",
    #|        "content_type": "application/pdf",
    #|        "size": 2048,
    #|        "url": "https://cdn.discordapp.com/attachments/receipt.pdf",
    #|        "proxy_url": "https://media.discordapp.net/attachments/receipt.pdf"
    #|      }
    #|    }
    #|  }
    #|}
  let modal : @model.ModalData = @json.from_json(@json.parse(fixture))
  let encoded = modal.to_json()
  let round_trip : @model.ModalData = @json.from_json(encoded)
  assert_eq(round_trip.to_json().stringify(), encoded.stringify())
  json_inspect(encoded, content={
    "custom_id": "upload-form",
    "components": [
      {
        "label": "Receipt",
        "component": {
          "custom_id": "receipt",
          "values": ["987654321098765432"],
          "type": 19,
        },
        "type": 18,
      },
    ],
    "resolved": {
      "attachments": {
        "987654321098765432": {
          "id": "987654321098765432",
          "filename": "receipt.pdf",
          "content_type": "application/pdf",
          "size": 2048,
          "url": "https://cdn.discordapp.com/attachments/receipt.pdf",
          "proxy_url": "https://media.discordapp.net/attachments/receipt.pdf",
        },
      },
    },
  })
}
