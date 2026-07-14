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
