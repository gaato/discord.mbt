///|
test "component decodes an action row with a button and string select" {
  let fixture =
    #|{
    #|  "type": 1,
    #|  "components": [{
    #|    "type": 2,
    #|    "style": 1,
    #|    "label": "Confirm",
    #|    "emoji": {
    #|      "id": "41771983429993937",
    #|      "name": "check",
    #|      "animated": false
    #|    },
    #|    "custom_id": "confirm-order",
    #|    "disabled": false
    #|  }, {
    #|    "type": 3,
    #|    "custom_id": "favorite-color",
    #|    "placeholder": "Choose a color",
    #|    "min_values": 1,
    #|    "max_values": 1,
    #|    "disabled": false,
    #|    "options": [{
    #|      "label": "Blue",
    #|      "value": "blue",
    #|      "description": "A calm color",
    #|      "emoji": {
    #|        "id": null,
    #|        "name": "🔵"
    #|      },
    #|      "default": true
    #|    }]
    #|  }],
    #|  "brand_new_field_from_discord": true
    #|}
  let component : @model.Component = @json.from_json(@json.parse(fixture))
  debug_inspect(
    component,
    content=(
      #|ActionRow(
      #|  {
      #|    id: None,
      #|    components: [
      #|      Button(
      #|        {
      #|          id: None,
      #|          style: Primary,
      #|          label: Some("Confirm"),
      #|          emoji: Some(
      #|            {
      #|              id: Some(Value(41771983429993937)),
      #|              name: Value("check"),
      #|              animated: Some(false),
      #|              roles: None,
      #|              user: None,
      #|              require_colons: None,
      #|              managed: None,
      #|              available: None,
      #|            },
      #|          ),
      #|          custom_id: Some("confirm-order"),
      #|          sku_id: None,
      #|          url: None,
      #|          disabled: Some(false),
      #|        },
      #|      ),
      #|      StringSelect(
      #|        {
      #|          id: None,
      #|          custom_id: "favorite-color",
      #|          placeholder: Some("Choose a color"),
      #|          min_values: Some(1),
      #|          max_values: Some(1),
      #|          disabled: Some(false),
      #|          options: Some(
      #|            [
      #|              {
      #|                label: "Blue",
      #|                value: "blue",
      #|                description: Some("A calm color"),
      #|                emoji: Some(
      #|                  {
      #|                    id: Some(Null),
      #|                    name: Value("🔵"),
      #|                    animated: None,
      #|                    roles: None,
      #|                    user: None,
      #|                    require_colons: None,
      #|                    managed: None,
      #|                    available: None,
      #|                  },
      #|                ),
      #|                default: Some(true),
      #|              },
      #|            ],
      #|          ),
      #|          channel_types: None,
      #|          default_values: None,
      #|          values: None,
      #|        },
      #|      ),
      #|    ],
      #|  },
      #|)
    ),
  )
  inspect(
    component.to_json().stringify(),
    content=(
      #|{"components":[{"style":1,"label":"Confirm","emoji":{"id":"41771983429993937","name":"check","animated":false},"custom_id":"confirm-order","disabled":false,"type":2},{"custom_id":"favorite-color","placeholder":"Choose a color","min_values":1,"max_values":1,"disabled":false,"options":[{"label":"Blue","value":"blue","description":"A calm color","emoji":{"id":null,"name":"🔵"},"default":true}],"type":3}],"type":1}
    ),
  )
}

///|
test "component preserves an unknown type verbatim" {
  let raw =
    #|{"type":99,"custom":"keep","nested":{"x":1}}
  let component : @model.Component = @json.from_json(@json.parse(raw))
  debug_inspect(
    component,
    content=(
      #|Unknown(
      #|  Object(
      #|    {
      #|      "type": Number(99),
      #|      "custom": String("keep"),
      #|      "nested": Object({ "x": Number(1) }),
      #|    },
      #|  ),
      #|)
    ),
  )
  inspect(
    component.to_json().stringify(),
    content=(
      #|{"type":99,"custom":"keep","nested":{"x":1}}
    ),
  )
}

///|
test "text input component round-trips" {
  let raw =
    #|{"type":4,"custom_id":"feedback","style":2,"label":"Feedback","min_length":1,"max_length":1000,"required":true,"value":"hello","placeholder":"Tell us more"}
  let component : @model.Component = @json.from_json(@json.parse(raw))
  debug_inspect(
    component,
    content=(
      #|TextInput(
      #|  {
      #|    id: None,
      #|    custom_id: "feedback",
      #|    style: Some(Paragraph),
      #|    label: Some("Feedback"),
      #|    min_length: Some(1),
      #|    max_length: Some(1000),
      #|    required: Some(true),
      #|    value: Some("hello"),
      #|    placeholder: Some("Tell us more"),
      #|  },
      #|)
    ),
  )
  let round_trip : @model.Component = @json.from_json(component.to_json())
  debug_inspect(
    round_trip,
    content=(
      #|TextInput(
      #|  {
      #|    id: None,
      #|    custom_id: "feedback",
      #|    style: Some(Paragraph),
      #|    label: Some("Feedback"),
      #|    min_length: Some(1),
      #|    max_length: Some(1000),
      #|    required: Some(true),
      #|    value: Some("hello"),
      #|    placeholder: Some("Tell us more"),
      #|  },
      #|)
    ),
  )
  inspect(
    component.to_json().stringify(),
    content=(
      #|{"custom_id":"feedback","style":2,"label":"Feedback","min_length":1,"max_length":1000,"required":true,"value":"hello","placeholder":"Tell us more","type":4}
    ),
  )
}

///|
test "label-wrapped text input without style decodes (modal submit shape)" {
  // Modal-submit payloads carry only type/id/custom_id/value (live payload).
  let raw =
    #|{"type":18,"id":1,"component":{"value":"aaa","type":4,"id":2,"custom_id":"topic"}}
  let component : @model.Component = @json.from_json(@json.parse(raw))
  guard component is Label(label) else { fail("expected a label component") }
  guard label.component is TextInput(input) else {
    fail("expected a text input inside the label")
  }
  assert_true(input.style is None)
  assert_true(label.label is None)
  inspect(input.custom_id, content="topic")
  assert_true(input.value is Some("aaa"))
}

///|
test "action rows decode recursively" {
  let fixture =
    #|{
    #|  "type": 1,
    #|  "components": [{
    #|    "type": 1,
    #|    "components": [{
    #|      "type": 2,
    #|      "style": 5,
    #|      "label": "Docs",
    #|      "url": "https://discord.com/developers/docs"
    #|    }]
    #|  }]
    #|}
  let component : @model.Component = @json.from_json(@json.parse(fixture))
  debug_inspect(
    component,
    content=(
      #|ActionRow(
      #|  {
      #|    id: None,
      #|    components: [
      #|      ActionRow(
      #|        {
      #|          id: None,
      #|          components: [
      #|            Button(
      #|              {
      #|                id: None,
      #|                style: Link,
      #|                label: Some("Docs"),
      #|                emoji: None,
      #|                custom_id: None,
      #|                sku_id: None,
      #|                url: Some("https://discord.com/developers/docs"),
      #|                disabled: None,
      #|              },
      #|            ),
      #|          ],
      #|        },
      #|      ),
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
fn component_round_trip(fixture : String) -> Json raise {
  let decoded : @model.Component = @json.from_json(@json.parse(fixture))
  let encoded = decoded.to_json()
  let round_trip : @model.Component = @json.from_json(encoded)
  assert_eq(round_trip.to_json().stringify(), encoded.stringify())
  encoded
}

///|
test "section with text and thumbnail round-trips" {
  json_inspect(
    component_round_trip(
      (
        #|{
        #|  "type": 9,
        #|  "id": 100,
        #|  "components": [{"type": 10, "id": 101, "content": "## Welcome"}],
        #|  "accessory": {
        #|    "type": 11,
        #|    "id": 102,
        #|    "media": {
        #|      "url": "https://cdn.discordapp.com/welcome.png",
        #|      "proxy_url": "https://media.discordapp.net/welcome.png",
        #|      "height": 180,
        #|      "width": 320,
        #|      "content_type": "image/png",
        #|      "flags": 0,
        #|      "attachment_id": "123456789012345678"
        #|    },
        #|    "description": "Welcome image",
        #|    "spoiler": false
        #|  }
        #|}
      ),
    ),
    content={
      "id": 100,
      "components": [{ "id": 101, "content": "## Welcome", "type": 10 }],
      "accessory": {
        "id": 102,
        "media": {
          "url": "https://cdn.discordapp.com/welcome.png",
          "proxy_url": "https://media.discordapp.net/welcome.png",
          "height": 180,
          "width": 320,
          "content_type": "image/png",
          "flags": 0,
          "attachment_id": "123456789012345678",
        },
        "description": "Welcome image",
        "spoiler": false,
        "type": 11,
      },
      "type": 9,
    },
  )
}

///|
test "container with text and separator round-trips" {
  json_inspect(
    component_round_trip(
      (
        #|{
        #|  "type": 17,
        #|  "id": 200,
        #|  "components": [
        #|    {"type": 10, "content": "First block"},
        #|    {"type": 14, "divider": true, "spacing": 2},
        #|    {"type": 10, "content": "Second block"}
        #|  ],
        #|  "accent_color": null,
        #|  "spoiler": true
        #|}
      ),
    ),
    content={
      "id": 200,
      "components": [
        { "content": "First block", "type": 10 },
        { "divider": true, "spacing": 2, "type": 14 },
        { "content": "Second block", "type": 10 },
      ],
      "accent_color": null,
      "spoiler": true,
      "type": 17,
    },
  )
}

///|
test "modern label with unlabeled text input round-trips" {
  json_inspect(
    component_round_trip(
      (
        #|{
        #|  "type": 18,
        #|  "id": 300,
        #|  "label": "Feedback",
        #|  "description": "Tell us what happened",
        #|  "component": {
        #|    "type": 4,
        #|    "id": 301,
        #|    "custom_id": "feedback",
        #|    "style": 2,
        #|    "required": true,
        #|    "placeholder": "Details"
        #|  }
        #|}
      ),
    ),
    content={
      "id": 300,
      "label": "Feedback",
      "description": "Tell us what happened",
      "component": {
        "id": 301,
        "custom_id": "feedback",
        "style": 2,
        "required": true,
        "placeholder": "Details",
        "type": 4,
      },
      "type": 18,
    },
  )
}

///|
test "label with submitted string select values round-trips" {
  json_inspect(
    component_round_trip(
      (
        #|{
        #|  "type": 18,
        #|  "label": "Favorite colors",
        #|  "component": {
        #|    "type": 3,
        #|    "id": 401,
        #|    "custom_id": "colors",
        #|    "values": ["blue", "green"]
        #|  }
        #|}
      ),
    ),
    content={
      "label": "Favorite colors",
      "component": {
        "id": 401,
        "custom_id": "colors",
        "values": ["blue", "green"],
        "type": 3,
      },
      "type": 18,
    },
  )
}

///|
test "file upload response round-trips" {
  json_inspect(
    component_round_trip(
      (
        #|{
        #|  "type": 19,
        #|  "id": 500,
        #|  "custom_id": "receipts",
        #|  "min_values": 1,
        #|  "max_values": 3,
        #|  "required": true,
        #|  "values": ["987654321098765432", "987654321098765433"]
        #|}
      ),
    ),
    content={
      "id": 500,
      "custom_id": "receipts",
      "min_values": 1,
      "max_values": 3,
      "required": true,
      "values": ["987654321098765432", "987654321098765433"],
      "type": 19,
    },
  )
}

///|
test "radio and checkbox responses round-trip" {
  let radio = component_round_trip(
    (
      #|{
      #|  "type": 21,
      #|  "id": 600,
      #|  "custom_id": "priority",
      #|  "options": [
      #|    {"value": "low", "label": "Low", "description": "Can wait"},
      #|    {"value": "high", "label": "High", "default": true}
      #|  ],
      #|  "required": true,
      #|  "value": "high"
      #|}
    ),
  )
  let group = component_round_trip(
    (
      #|{
      #|  "type": 22,
      #|  "id": 601,
      #|  "custom_id": "features",
      #|  "options": [
      #|    {"value": "search", "label": "Search"},
      #|    {"value": "export", "label": "Export"}
      #|  ],
      #|  "min_values": 1,
      #|  "max_values": 2,
      #|  "required": true,
      #|  "values": ["search", "export"]
      #|}
    ),
  )
  let checkbox = component_round_trip(
    (
      #|{
      #|  "type": 23,
      #|  "id": 602,
      #|  "custom_id": "terms",
      #|  "default": false,
      #|  "value": true
      #|}
    ),
  )
  json_inspect([radio, group, checkbox], content=[
    {
      "id": 600,
      "custom_id": "priority",
      "options": [
        { "value": "low", "label": "Low", "description": "Can wait" },
        { "value": "high", "label": "High", "default": true },
      ],
      "required": true,
      "value": "high",
      "type": 21,
    },
    {
      "id": 601,
      "custom_id": "features",
      "options": [
        { "value": "search", "label": "Search" },
        { "value": "export", "label": "Export" },
      ],
      "min_values": 1,
      "max_values": 2,
      "required": true,
      "values": ["search", "export"],
      "type": 22,
    },
    {
      "id": 602,
      "custom_id": "terms",
      "default": false,
      "value": true,
      "type": 23,
    },
  ])
}

///|
test "media gallery round-trips" {
  json_inspect(
    component_round_trip(
      (
        #|{
        #|  "type": 12,
        #|  "id": 700,
        #|  "items": [{
        #|    "media": {
        #|      "url": "attachment://chart.png",
        #|      "placeholder": "eJxjYGAEQgEBBiDJwZDBy",
        #|      "placeholder_version": 1
        #|    },
        #|    "description": "Latest chart",
        #|    "spoiler": false
        #|  }, {
        #|    "media": {"url": "https://example.com/diagram.jpg"},
        #|    "description": "Architecture",
        #|    "spoiler": true
        #|  }]
        #|}
      ),
    ),
    content={
      "id": 700,
      "items": [
        {
          "media": {
            "url": "attachment://chart.png",
            "placeholder": "eJxjYGAEQgEBBiDJwZDBy",
            "placeholder_version": 1,
          },
          "description": "Latest chart",
          "spoiler": false,
        },
        {
          "media": { "url": "https://example.com/diagram.jpg" },
          "description": "Architecture",
          "spoiler": true,
        },
      ],
      "type": 12,
    },
  )
}

///|
test "file component round-trips" {
  json_inspect(
    component_round_trip(
      (
        #|{
        #|  "type": 13,
        #|  "id": 800,
        #|  "file": {
        #|    "url": "attachment://report.pdf",
        #|    "content_type": "application/pdf",
        #|    "attachment_id": "111122223333444455"
        #|  },
        #|  "spoiler": false,
        #|  "name": "report.pdf",
        #|  "size": 4096
        #|}
      ),
    ),
    content={
      "id": 800,
      "file": {
        "url": "attachment://report.pdf",
        "content_type": "application/pdf",
        "attachment_id": "111122223333444455",
      },
      "spoiler": false,
      "name": "report.pdf",
      "size": 4096,
      "type": 13,
    },
  )
}

///|
test "components v2 media accept documented null description and size" {
  let component : @model.Component = @json.from_json({
    "type": 11,
    "media": {
      "url": "https://example.com/a.png",
      "width": Json::null(),
      "height": Json::null(),
    },
    "description": Json::null(),
  })
  guard component is Thumbnail(thumbnail) else { fail("expected thumbnail") }
  assert_true(thumbnail.description is Some(Null))
  assert_true(thumbnail.media.width is Some(Null))
  let item : @model.MediaGalleryItem = @json.from_json({
    "media": { "url": "https://example.com/b.png" },
    "description": Json::null(),
  })
  assert_true(item.description is Some(Null))
}

///|
test "file type filters round-trip on attachment options and file uploads" {
  let upload : @model.Component = @json.from_json({
    "type": 19,
    "custom_id": "proof",
    "file_types": ["image", "video", "audio", ".PDF", "sticker"],
  })
  guard upload is FileUpload({ file_types: Some(filters), .. }) else {
    fail("expected file upload with filters")
  }
  debug_inspect(
    filters,
    content=(
      #|[Image, Video, Audio, Extension(".PDF"), Unknown("sticker")]
    ),
  )
  inspect(
    Json(filters).stringify(),
    content=(
      #|["image","video","audio",".PDF","sticker"]
    ),
  )
  let option : @model.CommandOption = @json.from_json({
    "type": 11,
    "name": "file",
    "description": "File",
    "file_types": [".pdf"],
  })
  assert_true(option.file_types is Some([Extension(".pdf")]))
}
