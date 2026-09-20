///|
test "automatic select builders preserve options and wire discriminators" {
  let menus = [
    @interaction.user_select(
      custom_id="user",
      placeholder="Choose",
      min_values=0,
      max_values=2,
      disabled=false,
    ),
    @interaction.role_select(
      custom_id="role",
      placeholder="Choose",
      min_values=0,
      max_values=2,
      disabled=false,
    ),
    @interaction.mentionable_select(
      custom_id="mentionable",
      placeholder="Choose",
      min_values=0,
      max_values=2,
      disabled=false,
    ),
    @interaction.channel_select(
      custom_id="channel",
      placeholder="Choose",
      min_values=0,
      max_values=2,
      disabled=false,
      channel_types=[GuildText, GuildVoice],
    ),
  ]
  for i, menu in menus {
    let expected : Json = {
      "type": i + 5,
      "custom_id": ["user", "role", "mentionable", "channel"][i],
      "placeholder": "Choose",
      "min_values": 0,
      "max_values": 2,
      "disabled": false,
    }
    if i == 3 {
      guard! expected is Object(fields)
      fields["channel_types"] = [0, 2]
    }
    assert_eq(menu.to_json(), expected)
    let decoded : @model.Component = @json.from_json(menu.to_json())
    assert_eq(decoded.to_json(), expected)
  }
  assert_eq(@interaction.user_select(custom_id="default").to_json(), {
    "type": 5,
    "custom_id": "default",
  })
  assert_eq(@interaction.channel_select(custom_id="all").to_json(), {
    "type": 8,
    "custom_id": "all",
  })
}

///|
test "media gallery builders preserve descriptions spoilers and omitted fields" {
  let gallery = @interaction.media_gallery([
    @interaction.media_item(
      url="attachment://preview.png",
      description="Preview",
      spoiler=true,
    ),
    @interaction.media_item(url="https://example.com/video.webm"),
  ])
  let expected : Json = {
    "type": 12,
    "items": [
      {
        "media": { "url": "attachment://preview.png" },
        "description": "Preview",
        "spoiler": true,
      },
      { "media": { "url": "https://example.com/video.webm" } },
    ],
  }
  assert_eq(gallery.to_json(), expected)
  let decoded : @model.Component = @json.from_json(gallery.to_json())
  assert_eq(decoded.to_json(), expected)
}

///|
test "component builders emit Discord wire payloads" {
  json_inspect(
    @interaction.action_row([
      @interaction.button(custom_id="save", label="Save"),
      @interaction.link_button(url="https://example.com", label="Docs"),
      @interaction.string_select(custom_id="color", options=[
        @interaction.select_option(label="Blue", value="blue", default=true),
      ]),
    ]),
    content={
      "components": [
        { "style": 1, "label": "Save", "custom_id": "save", "type": 2 },
        { "style": 5, "label": "Docs", "url": "https://example.com", "type": 2 },
        {
          "custom_id": "color",
          "options": [{ "label": "Blue", "value": "blue", "default": true }],
          "type": 3,
        },
      ],
      "type": 1,
    },
  )
  json_inspect(
    @interaction.section(
      components=[@interaction.text_display("A compact summary")],
      accessory=@interaction.thumbnail(
        url="https://cdn.example/preview.png",
        description="Preview",
      ),
    ),
    content={
      "components": [{ "content": "A compact summary", "type": 10 }],
      "accessory": {
        "media": { "url": "https://cdn.example/preview.png" },
        "description": "Preview",
        "type": 11,
      },
      "type": 9,
    },
  )
  json_inspect(
    @interaction.container(
      components=[
        @interaction.text_display("Details"),
        @interaction.separator(divider=true, spacing=2),
      ],
      accent_color=0x5865f2,
      spoiler=false,
    ),
    content={
      "components": [
        { "content": "Details", "type": 10 },
        { "divider": true, "spacing": 2, "type": 14 },
      ],
      "accent_color": 5793266,
      "spoiler": false,
      "type": 17,
    },
  )
  json_inspect(
    @interaction.label(
      label="Name",
      description="Shown publicly",
      component=@interaction.text_input(
        custom_id="name",
        placeholder="Ada",
        required=true,
      ),
    ),
    content={
      "label": "Name",
      "description": "Shown publicly",
      "component": {
        "custom_id": "name",
        "style": 1,
        "required": true,
        "placeholder": "Ada",
        "type": 4,
      },
      "type": 18,
    },
  )
}
