///|
test "modal title and top-level component count boundaries" {
  let text : @model.Component = TextDisplay({ id: None, content: "Welcome", })
  for title in ["x", "x".repeat(45)] {
    debug_inspect(
      @model.modal_limit_violations(title~, components=[text]),
      content="[]",
    )
  }
  for count in [1, 5] {
    debug_inspect(
      @model.modal_limit_violations(
        title="Title",
        components=Array::make(count, text),
      ),
      content="[]",
    )
  }
  debug_inspect(
    @model.modal_limit_violations(title="", components=[]),
    content=(
      #|[{ path: "components", custom_id: None, reason: "0 (1 to 5)" }]
    ),
  )
  debug_inspect(
    @model.modal_limit_violations(
      title="x".repeat(46),
      components=Array::make(6, text),
    ),
    content=(
      #|[
      #|  { path: "title", custom_id: None, reason: "46 units (at most 45)" },
      #|  { path: "components", custom_id: None, reason: "6 (1 to 5)" },
      #|]
    ),
  )
}

///|
test "modal text input boundary limits and optional values" {
  let base : Json = { "type": 4, "custom_id": "answer", "style": 1 }
  inspect(
    limit_field_cases(
      base,
      [
        ("custom_id", limit_text(1), limit_text(0)),
        ("custom_id", limit_text(100), limit_text(101)),
        ("min_length", 0, -1),
        ("min_length", 4000, 4001),
        ("max_length", 1, 0),
        ("max_length", 4000, 4001),
        ("value", limit_text(4000), limit_text(4001)),
        (
          "value",
          Json::string("😀".repeat(2000)),
          Json::string("😀".repeat(2000) + "x"),
        ),
        ("placeholder", limit_text(100), limit_text(101)),
      ],
      modal=true,
    ),
    content=(
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.min_length: -1 (0 to 4000)
      #|components[0].component.min_length: 4001 (0 to 4000)
      #|components[0].component.max_length: 0 (1 to 4000)
      #|components[0].component.max_length: 4001 (1 to 4000)
      #|components[0].component.value: 4001 units (at most 4000)
      #|components[0].component.value: 4001 units (at most 4000)
      #|components[0].component.placeholder: 101 units (at most 100)
    ),
  )
  inspect(
    limit_field_cases(
      limit_with(base, "max_length", 2),
      [("min_length", 2, 3)],
      modal=true,
    ),
    content=(
      #|components[0].component.min_length: 3 exceeds the maximum 2
    ),
  )
  debug_inspect(limit_check(base, modal=true), content="[]")
}

///|
test "modal labels attach all interactive custom ids" {
  let components : Array[Json] = [
    { "type": 2, "style": 1, "custom_id": "button" },
    { "type": 3, "custom_id": "string" },
    { "type": 4, "custom_id": "text", "style": 1 },
    { "type": 5, "custom_id": "user" },
    { "type": 6, "custom_id": "role" },
    { "type": 7, "custom_id": "mention" },
    { "type": 8, "custom_id": "channel" },
    { "type": 19, "custom_id": "upload" },
    {
      "type": 21,
      "custom_id": "radio",
      "options": [
        { "label": "Yes", "value": "yes" },
        { "label": "No", "value": "no" },
      ],
    },
    {
      "type": 22,
      "custom_id": "group",
      "options": [{ "label": "Yes", "value": "yes" }],
    },
    { "type": 23, "custom_id": "checkbox" },
  ]
  let violations : Array[@model.LimitViolation] = []
  for json in components {
    let component : @model.Component = @json.from_json(json)
    let valid : @model.Component = Label({
      id: None,
      label: Some("x".repeat(45)),
      description: Some("x".repeat(100)),
      component,
    })
    debug_inspect(
      @model.modal_limit_violations(title="Title", components=[valid]),
      content="[]",
    )
    let invalid : @model.Component = Label({
      id: None,
      label: Some("x".repeat(46)),
      description: Some("x".repeat(101)),
      component,
    })
    violations.append(
      @model.modal_limit_violations(title="Title", components=[invalid]),
    )
  }
  debug_inspect(
    violations,
    content=(
      #|[
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("button"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("button"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("string"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("string"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("text"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("text"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("user"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("user"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("role"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("role"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("mention"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("mention"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("channel"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("channel"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("upload"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("upload"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("radio"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("radio"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("group"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("group"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].label",
      #|    custom_id: Some("checkbox"),
      #|    reason: "46 units (at most 45)",
      #|  },
      #|  {
      #|    path: "components[0].description",
      #|    custom_id: Some("checkbox"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|]
    ),
  )
  // Missing optional fields remain unchecked, including the model's optional label.
  debug_inspect(
    limit_check(
      { "type": 18, "component": { "type": 23, "custom_id": "agree" } },
      modal=true,
    ),
    content="[]",
  )
}

///|
test "modal file upload and file type count boundaries" {
  let base : Json = { "type": 19, "custom_id": "upload" }
  inspect(
    limit_field_cases(
      base,
      [
        ("custom_id", limit_text(1), limit_text(0)),
        ("custom_id", limit_text(100), limit_text(101)),
        ("min_values", 0, -1),
        ("min_values", 10, 11),
        ("max_values", 10, 11),
        ("file_types", limit_array(10, "image"), limit_array(11, "image")),
      ],
      modal=true,
    ),
    content=(
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.min_values: -1 (0 to 10)
      #|components[0].component.min_values: 11 (0 to 10)
      #|components[0].component.max_values: 11 (0 to 10)
      #|components[0].component.file_types: 11 (0 to 10)
    ),
  )
  inspect(
    limit_field_cases(
      limit_with(base, "max_values", 2),
      [("min_values", 2, 3)],
      modal=true,
    ),
    content=(
      #|components[0].component.min_values: 3 exceeds the maximum 2
    ),
  )
  debug_inspect(limit_check(base, modal=true), content="[]")
  debug_inspect(
    limit_check(limit_with(base, "file_types", []), modal=true),
    content="[]",
  )
}

///|
test "modal radio and checkbox groups bound options and option text" {
  let option : Json = { "label": "Yes", "value": "yes" }
  let messages : Array[String] = []
  for (typ, minimum) in [(21, 2), (22, 1)] {
    let base : Json = {
      "type": Json(typ),
      "custom_id": "choice",
      "options": limit_array(minimum, option),
    }
    messages.push(
      limit_field_cases(
        base,
        [
          ("custom_id", limit_text(1), limit_text(0)),
          ("custom_id", limit_text(100), limit_text(101)),
          (
            "options",
            limit_array(minimum, option),
            limit_array(minimum - 1, option),
          ),
          ("options", limit_array(10, option), limit_array(11, option)),
        ],
        modal=true,
      ),
    )
    for field in ["label", "value", "description"] {
      let valid = Array::make(minimum, option)
      let invalid = Array::make(minimum, option)
      valid[0] = limit_with(option, field, limit_text(100))
      invalid[0] = limit_with(option, field, limit_text(101))
      messages.push(
        limit_field_cases(
          base,
          [("options", Json::array(valid), Json::array(invalid))],
          modal=true,
        ),
      )
    }
    debug_inspect(limit_check(base, modal=true), content="[]")
    debug_inspect(
      limit_check(
        limit_with(
          base,
          "options",
          limit_array(minimum, { "label": "", "value": "", "description": "" }),
        ),
        modal=true,
      ),
      content="[]",
    )
  }
  inspect(
    messages.join("\n"),
    content=(
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.options: 1 (2 to 10)
      #|components[0].component.options: 11 (2 to 10)
      #|components[0].component.options[0].label: 101 units (at most 100)
      #|components[0].component.options[0].value: 101 units (at most 100)
      #|components[0].component.options[0].description: 101 units (at most 100)
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.options: 0 (1 to 10)
      #|components[0].component.options: 11 (1 to 10)
      #|components[0].component.options[0].label: 101 units (at most 100)
      #|components[0].component.options[0].value: 101 units (at most 100)
      #|components[0].component.options[0].description: 101 units (at most 100)
    ),
  )
}

///|
test "modal checkbox group selection ranges ordering and required dependency" {
  let base : Json = {
    "type": 22,
    "custom_id": "choices",
    "required": false,
    "options": [{ "label": "Yes", "value": "yes" }],
  }
  inspect(
    limit_field_cases(
      base,
      [
        ("min_values", 0, -1),
        ("min_values", 10, 11),
        ("max_values", 1, 0),
        ("max_values", 10, 11),
      ],
      modal=true,
    ),
    content=(
      #|components[0].component.min_values: -1 (0 to 10)
      #|components[0].component.min_values: 11 (0 to 10)
      #|components[0].component.max_values: 0 (1 to 10)
      #|components[0].component.max_values: 11 (1 to 10)
    ),
  )
  inspect(
    limit_field_cases(
      limit_with(base, "max_values", 2),
      [("min_values", 2, 3)],
      modal=true,
    ),
    content=(
      #|components[0].component.min_values: 3 exceeds the maximum 2
    ),
  )
  inspect(
    limit_field_cases(
      limit_with(base, "required", true),
      [("min_values", 1, 0)],
      modal=true,
    ),
    content=(
      #|components[0].component.min_values: 0 (1 to 10)
    ),
  )
  inspect(
    limit_field_cases(
      {
        "type": 22,
        "custom_id": "choices",
        "options": [{ "label": "Yes", "value": "yes" }],
      },
      [("min_values", 1, 0)],
      modal=true,
    ),
    content=(
      #|components[0].component.min_values: 0 (1 to 10)
    ),
  )
}

///|
test "modal single checkbox bounds only its custom id" {
  let base : Json = { "type": 23, "custom_id": "agree" }
  inspect(
    limit_field_cases(
      base,
      [
        ("custom_id", limit_text(1), limit_text(0)),
        ("custom_id", limit_text(100), limit_text(101)),
      ],
      modal=true,
    ),
    content=(
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
    ),
  )
  debug_inspect(limit_check(base, modal=true), content="[]")
}

///|
test "existing modal text input label string select and upload reasons stay stable" {
  let components : Array[@model.Component] = [
    @json.from_json({
      "type": 1,
      "components": [
        {
          "type": 18,
          "label": "",
          "description": limit_text(101),
          "component": {
            "type": 4,
            "custom_id": "",
            "style": 1,
            "min_length": 4001,
            "max_length": 0,
            "value": limit_text(4001),
            "placeholder": limit_text(101),
          },
        },
      ],
    }),
    @json.from_json({
      "type": 18,
      "label": "Pick",
      "component": {
        "type": 3,
        "custom_id": "select",
        "options": [],
        "placeholder": limit_text(151),
        "min_values": 26,
        "max_values": 0,
      },
    }),
    @json.from_json({
      "type": 18,
      "label": "Attach",
      "component": {
        "type": 19,
        "custom_id": "upload",
        "min_values": 11,
        "max_values": 0,
      },
    }),
  ]
  debug_inspect(
    @model.modal_limit_violations(title="Form", components~),
    content=(
      #|[
      #|  {
      #|    path: "components[0].components[0].description",
      #|    custom_id: Some(""),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[0].components[0].component.custom_id",
      #|    custom_id: Some(""),
      #|    reason: "0 units (1 to 100)",
      #|  },
      #|  {
      #|    path: "components[0].components[0].component.min_length",
      #|    custom_id: Some(""),
      #|    reason: "4001 (0 to 4000)",
      #|  },
      #|  {
      #|    path: "components[0].components[0].component.max_length",
      #|    custom_id: Some(""),
      #|    reason: "0 (1 to 4000)",
      #|  },
      #|  {
      #|    path: "components[0].components[0].component.min_length",
      #|    custom_id: Some(""),
      #|    reason: "4001 exceeds the maximum 0",
      #|  },
      #|  {
      #|    path: "components[0].components[0].component.value",
      #|    custom_id: Some(""),
      #|    reason: "4001 units (at most 4000)",
      #|  },
      #|  {
      #|    path: "components[0].components[0].component.placeholder",
      #|    custom_id: Some(""),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|  {
      #|    path: "components[1].component.placeholder",
      #|    custom_id: Some("select"),
      #|    reason: "151 units (at most 150)",
      #|  },
      #|  {
      #|    path: "components[1].component.min_values",
      #|    custom_id: Some("select"),
      #|    reason: "26 (0 to 25)",
      #|  },
      #|  {
      #|    path: "components[1].component.min_values",
      #|    custom_id: Some("select"),
      #|    reason: "26 exceeds the maximum 0",
      #|  },
      #|  {
      #|    path: "components[2].component.min_values",
      #|    custom_id: Some("upload"),
      #|    reason: "11 (0 to 10)",
      #|  },
      #|  {
      #|    path: "components[2].component.min_values",
      #|    custom_id: Some("upload"),
      #|    reason: "11 exceeds the maximum 0",
      #|  },
      #|]
    ),
  )
  // The reference states only upper bounds for a select's options and
  // max_values, so an empty select is left for Discord to judge.
  let base : Json = { "type": 3, "custom_id": "select" }
  debug_inspect(
    limit_check(
      limit_with(limit_with(base, "options", []), "max_values", 0),
      modal=true,
    ),
    content="[]",
  )
  debug_inspect(
    limit_check(limit_with(base, "min_values", 0), modal=true),
    content="[]",
  )
}

///|
test "realistic fully valid modal and unbounded text display" {
  let components : Array[@model.Component] = [
    @json.from_json({
      "type": 10,
      "content": "## Release feedback\nHelp us improve the next release.",
    }),
    @json.from_json({
      "type": 18,
      "label": "Your feedback",
      "description": "Be as specific as you can.",
      "component": {
        "type": 4,
        "style": 2,
        "custom_id": "feedback",
        "min_length": 1,
        "max_length": 4000,
        "placeholder": "What should we change?",
      },
    }),
    @json.from_json({
      "type": 18,
      "label": "Who should follow up?",
      "component": {
        "type": 5,
        "custom_id": "owner",
        "min_values": 1,
        "max_values": 2,
        "default_values": [{ "id": "123", "type": "user" }],
      },
    }),
    @json.from_json({
      "type": 18,
      "label": "Areas to improve",
      "component": {
        "type": 22,
        "custom_id": "areas",
        "required": false,
        "min_values": 0,
        "max_values": 2,
        "options": [
          {
            "label": "Usability",
            "value": "ux",
            "description": "Layout and navigation",
          },
          { "label": "Performance", "value": "speed" },
        ],
      },
    }),
    @json.from_json({
      "type": 18,
      "label": "Screenshots",
      "component": {
        "type": 19,
        "custom_id": "screenshots",
        "required": false,
        "min_values": 0,
        "max_values": 3,
        "file_types": ["image"],
      },
    }),
  ]
  debug_inspect(
    @model.modal_limit_violations(title="Release feedback", components~),
    content="[]",
  )
  debug_inspect(
    @model.modal_limit_violations(title="Information", components=[
      TextDisplay({ id: None, content: "x".repeat(10000), }),
      Unknown({ "type": 999, "custom_id": limit_text(101) }),
    ]),
    content="[]",
  )
}
