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
      #|    components: [
      #|      Button(
      #|        {
      #|          style: Primary,
      #|          label: Some("Confirm"),
      #|          emoji: Some(
      #|            {
      #|              id: Value(41771983429993937),
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
      #|                    id: Null,
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
      #|    custom_id: "feedback",
      #|    style: Paragraph,
      #|    label: "Feedback",
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
      #|    custom_id: "feedback",
      #|    style: Paragraph,
      #|    label: "Feedback",
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
      #|    components: [
      #|      ActionRow(
      #|        {
      #|          components: [
      #|            Button(
      #|              {
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
