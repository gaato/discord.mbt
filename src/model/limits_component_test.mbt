///|
test "message limit traversal does not skip children nested inside a Label" {
  // Raw component trees may contain modal-only nodes. The limit walker must
  // still inspect descendants; structural legality is a separate concern.
  let component : @model.Component = @json.from_json({
    "type": 18,
    "label": "Choice",
    "component": {
      "type": 2,
      "style": 1,
      "custom_id": "button",
      "label": "x".repeat(81),
    },
  })
  let violations = @model.message_component_limit_violations([component])
  assert_eq(violations.length(), 1)
  assert_true(violations[0].message().contains("components[0].component.label"))
}

///|
fn limit_with(base : Json, field : String, value : Json) -> Json {
  guard base is Object(fields) else { abort("expected object fixture") }
  let fields = fields.copy()
  fields[field] = value
  Json::object(fields)
}

///|
fn limit_text(length : Int) -> Json {
  Json::string("x".repeat(length))
}

///|
fn limit_array(length : Int, item : Json) -> Json {
  Json::array(Array::make(length, item))
}

///|
fn limit_check(
  json : Json,
  modal~ : Bool,
) -> Array[@model.LimitViolation] raise {
  let component : @model.Component = @json.from_json(json)
  if modal {
    @model.modal_limit_violations(title="Choose", components=[
      Label({ id: None, label: Some("Choice"), description: None, component, }),
    ])
  } else {
    @model.message_component_limit_violations([component])
  }
}

///|
fn limit_field_cases(
  base : Json,
  cases : Array[(String, Json, Json)],
  modal? : Bool = false,
) -> String raise {
  let messages : Array[String] = []
  for (field, valid, invalid) in cases {
    debug_inspect(
      limit_check(limit_with(base, field, valid), modal~),
      content="[]",
    )
    let violations = limit_check(limit_with(base, field, invalid), modal~)
    assert_false(violations.is_empty())
    for violation in violations {
      messages.push(violation.message())
    }
  }
  messages.join("\n")
}

///|
test "message button length boundaries use UTF-16 units" {
  inspect(
    limit_field_cases({ "type": 2, "style": 1, "custom_id": "button" }, [
      ("label", limit_text(80), limit_text(81)),
      (
        "label",
        Json::string("😀".repeat(40)),
        Json::string("😀".repeat(40) + "x"),
      ),
      ("custom_id", limit_text(1), limit_text(0)),
      ("custom_id", limit_text(100), limit_text(101)),
      ("url", limit_text(512), limit_text(513)),
    ]),
    content=(
      #|components[0].label: 81 units (at most 80)
      #|components[0].label: 81 units (at most 80)
      #|components[0].custom_id: 0 units (1 to 100)
      #|components[0].custom_id: 101 units (1 to 100)
      #|components[0].url: 513 units (at most 512)
    ),
  )
  debug_inspect(
    limit_check({ "type": 2, "style": 5 }, modal=false),
    content="[]",
  )
}

///|
test "all select types share message and modal field boundaries" {
  let messages : Array[String] = []
  for modal in [false, true] {
    for typ in [3, 5, 6, 7, 8] {
      let base : Json = { "type": typ.to_json(), "custom_id": "pick" }
      messages.push(
        limit_field_cases(
          base,
          [
            ("custom_id", limit_text(1), limit_text(0)),
            ("custom_id", limit_text(100), limit_text(101)),
            ("placeholder", limit_text(150), limit_text(151)),
            ("min_values", 0, -1),
            ("min_values", 25, 26),
            ("max_values", 25, 26),
            ("max_values", if modal { 1 } else { 0 }, -1),
          ],
          modal~,
        ),
      )
      messages.push(
        limit_field_cases(
          limit_with(base, "max_values", 2),
          [("min_values", 2, 3)],
          modal~,
        ),
      )
      debug_inspect(limit_check(base, modal~), content="[]")
    }
  }
  inspect(
    messages.join("\n"),
    content=(
      #|components[0].custom_id: 0 units (1 to 100)
      #|components[0].custom_id: 101 units (1 to 100)
      #|components[0].placeholder: 151 units (at most 150)
      #|components[0].min_values: -1 (0 to 25)
      #|components[0].min_values: 26 (0 to 25)
      #|components[0].max_values: 26 (0 to 25)
      #|components[0].max_values: -1 (0 to 25)
      #|components[0].min_values: 3 exceeds the maximum 2
      #|components[0].custom_id: 0 units (1 to 100)
      #|components[0].custom_id: 101 units (1 to 100)
      #|components[0].placeholder: 151 units (at most 150)
      #|components[0].min_values: -1 (0 to 25)
      #|components[0].min_values: 26 (0 to 25)
      #|components[0].max_values: 26 (0 to 25)
      #|components[0].max_values: -1 (0 to 25)
      #|components[0].min_values: 3 exceeds the maximum 2
      #|components[0].custom_id: 0 units (1 to 100)
      #|components[0].custom_id: 101 units (1 to 100)
      #|components[0].placeholder: 151 units (at most 150)
      #|components[0].min_values: -1 (0 to 25)
      #|components[0].min_values: 26 (0 to 25)
      #|components[0].max_values: 26 (0 to 25)
      #|components[0].max_values: -1 (0 to 25)
      #|components[0].min_values: 3 exceeds the maximum 2
      #|components[0].custom_id: 0 units (1 to 100)
      #|components[0].custom_id: 101 units (1 to 100)
      #|components[0].placeholder: 151 units (at most 150)
      #|components[0].min_values: -1 (0 to 25)
      #|components[0].min_values: 26 (0 to 25)
      #|components[0].max_values: 26 (0 to 25)
      #|components[0].max_values: -1 (0 to 25)
      #|components[0].min_values: 3 exceeds the maximum 2
      #|components[0].custom_id: 0 units (1 to 100)
      #|components[0].custom_id: 101 units (1 to 100)
      #|components[0].placeholder: 151 units (at most 150)
      #|components[0].min_values: -1 (0 to 25)
      #|components[0].min_values: 26 (0 to 25)
      #|components[0].max_values: 26 (0 to 25)
      #|components[0].max_values: -1 (0 to 25)
      #|components[0].min_values: 3 exceeds the maximum 2
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.placeholder: 151 units (at most 150)
      #|components[0].component.min_values: -1 (0 to 25)
      #|components[0].component.min_values: 26 (0 to 25)
      #|components[0].component.max_values: 26 (0 to 25)
      #|components[0].component.max_values: -1 (0 to 25)
      #|components[0].component.min_values: 3 exceeds the maximum 2
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.placeholder: 151 units (at most 150)
      #|components[0].component.min_values: -1 (0 to 25)
      #|components[0].component.min_values: 26 (0 to 25)
      #|components[0].component.max_values: 26 (0 to 25)
      #|components[0].component.max_values: -1 (0 to 25)
      #|components[0].component.min_values: 3 exceeds the maximum 2
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.placeholder: 151 units (at most 150)
      #|components[0].component.min_values: -1 (0 to 25)
      #|components[0].component.min_values: 26 (0 to 25)
      #|components[0].component.max_values: 26 (0 to 25)
      #|components[0].component.max_values: -1 (0 to 25)
      #|components[0].component.min_values: 3 exceeds the maximum 2
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.placeholder: 151 units (at most 150)
      #|components[0].component.min_values: -1 (0 to 25)
      #|components[0].component.min_values: 26 (0 to 25)
      #|components[0].component.max_values: 26 (0 to 25)
      #|components[0].component.max_values: -1 (0 to 25)
      #|components[0].component.min_values: 3 exceeds the maximum 2
      #|components[0].component.custom_id: 0 units (1 to 100)
      #|components[0].component.custom_id: 101 units (1 to 100)
      #|components[0].component.placeholder: 151 units (at most 150)
      #|components[0].component.min_values: -1 (0 to 25)
      #|components[0].component.min_values: 26 (0 to 25)
      #|components[0].component.max_values: 26 (0 to 25)
      #|components[0].component.max_values: -1 (0 to 25)
      #|components[0].component.min_values: 3 exceeds the maximum 2
    ),
  )
}

///|
test "string select options and option text boundaries in both contexts" {
  let option : Json = { "label": "Blue", "value": "blue" }
  let base : Json = { "type": 3, "custom_id": "color" }
  let messages : Array[String] = []
  for modal in [false, true] {
    messages.push(
      limit_field_cases(
        base,
        [("options", limit_array(25, option), limit_array(26, option))],
        modal~,
      ),
    )
    for field in ["label", "value", "description"] {
      messages.push(
        limit_field_cases(
          base,
          [
            (
              "options",
              limit_array(1, limit_with(option, field, limit_text(100))),
              limit_array(1, limit_with(option, field, limit_text(101))),
            ),
          ],
          modal~,
        ),
      )
    }
    // The reference states only a maximum for option text, including label/value.
    debug_inspect(
      limit_check(
        limit_with(base, "options", [
          { "label": "", "value": "", "description": "" },
        ]),
        modal~,
      ),
      content="[]",
    )
  }
  inspect(
    messages.join("\n"),
    content=(
      #|components[0].options: 26 (0 to 25)
      #|components[0].options[0].label: 101 units (at most 100)
      #|components[0].options[0].value: 101 units (at most 100)
      #|components[0].options[0].description: 101 units (at most 100)
      #|components[0].component.options: 26 (0 to 25)
      #|components[0].component.options[0].label: 101 units (at most 100)
      #|components[0].component.options[0].value: 101 units (at most 100)
      #|components[0].component.options[0].description: 101 units (at most 100)
    ),
  )
  debug_inspect(
    limit_check(limit_with(base, "options", []), modal=false),
    content="[]",
  )
}

///|
test "auto select default counts follow explicit and default selection bounds" {
  let messages : Array[String] = []
  let value : Json = { "id": "123", "type": "user" }
  for modal in [false, true] {
    for typ in [5, 6, 7, 8] {
      let base : Json = { "type": typ.to_json(), "custom_id": "entity" }
      messages.push(
        limit_field_cases(
          base,
          [("default_values", limit_array(1, value), limit_array(2, value))],
          modal~,
        ),
      )
      messages.push(
        limit_field_cases(
          limit_with(limit_with(base, "min_values", 2), "max_values", 3),
          [
            ("default_values", limit_array(2, value), limit_array(1, value)),
            ("default_values", limit_array(3, value), limit_array(4, value)),
          ],
          modal~,
        ),
      )
      messages.push(
        limit_field_cases(
          limit_with(base, "max_values", 25),
          [("default_values", limit_array(25, value), limit_array(26, value))],
          modal~,
        ),
      )
      debug_inspect(
        limit_check(
          limit_with(limit_with(base, "min_values", 0), "default_values", []),
          modal~,
        ),
        content="[]",
      )
    }
  }
  inspect(
    messages.join("\n"),
    content=(
      #|components[0].default_values: 2 (1 to 1)
      #|components[0].default_values: 1 (2 to 3)
      #|components[0].default_values: 4 (2 to 3)
      #|components[0].default_values: 26 (1 to 25)
      #|components[0].default_values: 2 (1 to 1)
      #|components[0].default_values: 1 (2 to 3)
      #|components[0].default_values: 4 (2 to 3)
      #|components[0].default_values: 26 (1 to 25)
      #|components[0].default_values: 2 (1 to 1)
      #|components[0].default_values: 1 (2 to 3)
      #|components[0].default_values: 4 (2 to 3)
      #|components[0].default_values: 26 (1 to 25)
      #|components[0].default_values: 2 (1 to 1)
      #|components[0].default_values: 1 (2 to 3)
      #|components[0].default_values: 4 (2 to 3)
      #|components[0].default_values: 26 (1 to 25)
      #|components[0].component.default_values: 2 (1 to 1)
      #|components[0].component.default_values: 1 (2 to 3)
      #|components[0].component.default_values: 4 (2 to 3)
      #|components[0].component.default_values: 26 (1 to 25)
      #|components[0].component.default_values: 2 (1 to 1)
      #|components[0].component.default_values: 1 (2 to 3)
      #|components[0].component.default_values: 4 (2 to 3)
      #|components[0].component.default_values: 26 (1 to 25)
      #|components[0].component.default_values: 2 (1 to 1)
      #|components[0].component.default_values: 1 (2 to 3)
      #|components[0].component.default_values: 4 (2 to 3)
      #|components[0].component.default_values: 26 (1 to 25)
      #|components[0].component.default_values: 2 (1 to 1)
      #|components[0].component.default_values: 1 (2 to 3)
      #|components[0].component.default_values: 4 (2 to 3)
      #|components[0].component.default_values: 26 (1 to 25)
    ),
  )
}

///|
test "legacy rows and per-row counts also apply inside V2 containers" {
  let button : Json = { "type": 2, "style": 1, "custom_id": "ok" }
  let row : @model.Component = @json.from_json({
    "type": 1,
    "components": [button],
  })
  debug_inspect(
    @model.message_component_limit_violations(Array::make(5, row)),
    content="[]",
  )
  debug_inspect(
    @model.message_component_limit_violations(Array::make(6, row)),
    content=(
      #|[{ path: "components", custom_id: None, reason: "6 (0 to 5)" }]
    ),
  )
  inspect(
    limit_field_cases({ "type": 1 }, [
      ("components", limit_array(5, button), limit_array(6, button)),
    ]),
    content=(
      #|components[0].components: 6 (0 to 5)
    ),
  )
  let messages : Array[String] = []
  for typ in [3, 5, 6, 7, 8] {
    let select : Json = { "type": typ.to_json(), "custom_id": "pick" }
    messages.push(
      limit_field_cases({ "type": 1 }, [
        ("components", [select], [select, select]),
        ("components", [select], [button, select]),
      ]),
    )
  }
  inspect(
    messages.join("\n"),
    content=(
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
      #|components[0].components: 2 (0 to 1)
    ),
  )
  let container : Json = {
    "type": 17,
    "components": [{ "type": 1, "components": limit_array(6, button) }],
  }
  debug_inspect(
    limit_check(container, modal=false),
    content=(
      #|[
      #|  {
      #|    path: "components[0].components[0].components",
      #|    custom_id: None,
      #|    reason: "6 (0 to 5)",
      #|  },
      #|]
    ),
  )
  debug_inspect(
    @model.message_component_limit_violations([
      Container({
        id: None,
        components: Array::make(6, row),
        accent_color: None,
        spoiler: None,
      }),
    ]),
    content="[]",
  )
}

///|
test "V2 component total counts layout nodes children and accessories" {
  let section : @model.Component = @json.from_json({
    "type": 9,
    "components": [
      { "type": 10, "content": "One" },
      { "type": 10, "content": "Two" },
    ],
    "accessory": {
      "type": 11,
      "media": { "url": "https://example.com/image.png" },
    },
  })
  debug_inspect(
    @model.message_component_limit_violations(Array::make(10, section)),
    content="[]",
  )
  let components = Array::make(10, section)
  components.push(TextDisplay({ id: None, content: "Extra", }))
  debug_inspect(
    @model.message_component_limit_violations(components),
    content=(
      #|[
      #|  {
      #|    path: "components",
      #|    custom_id: None,
      #|    reason: "41 total components including nested components (at most 40)",
      #|  },
      #|]
    ),
  )
  let text : @model.Component = TextDisplay({ id: None, content: "Nested", })
  debug_inspect(
    @model.message_component_limit_violations([
      Container({
        id: None,
        components: Array::make(39, text),
        accent_color: None,
        spoiler: None,
      }),
    ]),
    content="[]",
  )
  debug_inspect(
    @model.message_component_limit_violations([
      Container({
        id: None,
        components: Array::make(40, text),
        accent_color: None,
        spoiler: None,
      }),
    ]),
    content=(
      #|[
      #|  {
      #|    path: "components",
      #|    custom_id: None,
      #|    reason: "41 total components including nested components (at most 40)",
      #|  },
      #|]
    ),
  )
  // A gallery item is not a component. Unknown payloads are not traversed.
  let gallery : @model.Component = @json.from_json({
    "type": 12,
    "items": limit_array(10, { "media": { "url": "attachment://image.png" } }),
  })
  debug_inspect(
    @model.message_component_limit_violations(Array::make(40, gallery)),
    content="[]",
  )
  components.pop() |> ignore
  components.push(
    Unknown({ "type": 999, "components": limit_array(100, { "type": 2 }) }),
  )
  debug_inspect(
    @model.message_component_limit_violations(components),
    content="[]",
  )
}

///|
test "section gallery thumbnail separator and container limits" {
  let text : Json = { "type": 10, "content": "Details" }
  let thumbnail : Json = {
    "type": 11,
    "media": { "url": "attachment://image.png" },
  }
  inspect(
    limit_field_cases({ "type": 9, "accessory": thumbnail }, [
      ("components", limit_array(1, text), []),
      ("components", limit_array(3, text), limit_array(4, text)),
    ]),
    content=(
      #|components[0].components: 0 (1 to 3)
      #|components[0].components: 4 (1 to 3)
    ),
  )
  inspect(
    limit_field_cases(thumbnail, [
      ("description", limit_text(1024), limit_text(1025)),
    ]),
    content=(
      #|components[0].description: 1025 units (at most 1024)
    ),
  )
  let item : Json = { "media": { "url": "attachment://image.png" } }
  inspect(
    limit_field_cases({ "type": 12 }, [
      ("items", limit_array(1, item), []),
      ("items", limit_array(10, item), limit_array(11, item)),
      (
        "items",
        [limit_with(item, "description", limit_text(1024))],
        [limit_with(item, "description", limit_text(1025))],
      ),
    ]),
    content=(
      #|components[0].items: 0 (1 to 10)
      #|components[0].items: 11 (1 to 10)
      #|components[0].items[0].description: 1025 units (at most 1024)
    ),
  )
  inspect(
    limit_field_cases({ "type": 14 }, [("spacing", 1, 0), ("spacing", 2, 3)]),
    content=(
      #|components[0].spacing: 0 (1 to 2)
      #|components[0].spacing: 3 (1 to 2)
    ),
  )
  inspect(
    limit_field_cases({ "type": 17, "components": [text] }, [
      ("accent_color", 0, -1),
      ("accent_color", 16777215, 16777216),
    ]),
    content=(
      #|components[0].accent_color: -1 (0 to 16777215)
      #|components[0].accent_color: 16777216 (0 to 16777215)
    ),
  )
  debug_inspect(
    limit_check(limit_with(thumbnail, "description", Json::null()), modal=false),
    content="[]",
  )
  debug_inspect(
    limit_check(
      { "type": 12, "items": [limit_with(item, "description", Json::null())] },
      modal=false,
    ),
    content="[]",
  )
  debug_inspect(
    limit_check(
      { "type": 17, "components": [], "accent_color": Json::null() },
      modal=false,
    ),
    content="[]",
  )
}

///|
test "message validation preserves nested paths and nearest custom id" {
  let component : Json = {
    "type": 17,
    "components": [
      {
        "type": 9,
        "components": [{ "type": 10, "content": "Summary" }],
        "accessory": {
          "type": 2,
          "style": 1,
          "custom_id": "details",
          "label": limit_text(81),
        },
      },
      {
        "type": 1,
        "components": [
          {
            "type": 3,
            "custom_id": "color",
            "options": [{ "label": "Blue", "value": limit_text(101) }],
          },
        ],
      },
    ],
  }
  debug_inspect(
    limit_check(component, modal=false),
    content=(
      #|[
      #|  {
      #|    path: "components[0].components[0].accessory.label",
      #|    custom_id: Some("details"),
      #|    reason: "81 units (at most 80)",
      #|  },
      #|  {
      #|    path: "components[0].components[1].components[0].options[0].value",
      #|    custom_id: Some("color"),
      #|    reason: "101 units (at most 100)",
      #|  },
      #|]
    ),
  )
}

///|
test "realistic fully valid message and undocumented lengths" {
  let component : Json = {
    "type": 17,
    "accent_color": 5793266,
    "components": [
      {
        "type": 9,
        "components": [
          {
            "type": 10,
            "content": "## Weekly update\nSee the screenshots below.",
          },
        ],
        "accessory": {
          "type": 11,
          "media": { "url": "attachment://avatar.png" },
          "description": "Project logo",
        },
      },
      {
        "type": 12,
        "items": [
          {
            "media": { "url": "attachment://preview.png" },
            "description": "New settings screen",
          },
        ],
      },
      { "type": 14, "spacing": 2 },
      { "type": 13, "file": { "url": "attachment://notes.txt" } },
      {
        "type": 1,
        "components": [
          {
            "type": 2,
            "style": 5,
            "url": "https://example.com/release",
            "label": "Release notes",
          },
        ],
      },
      {
        "type": 1,
        "components": [
          {
            "type": 3,
            "custom_id": "feedback",
            "options": [
              {
                "label": "Looks good",
                "value": "good",
                "description": "Ready to ship",
              },
              { "label": "Needs work", "value": "changes" },
            ],
            "min_values": 0,
            "max_values": 1,
            "placeholder": "Share feedback",
          },
        ],
      },
    ],
  }
  debug_inspect(limit_check(component, modal=false), content="[]")
  debug_inspect(
    limit_check({ "type": 10, "content": limit_text(10000) }, modal=false),
    content="[]",
  )
  // Position validation is deliberately separate; the top-level count counts rows.
  let button : @model.Component = @json.from_json({ "type": 2, "style": 1 })
  debug_inspect(
    @model.message_component_limit_violations(Array::make(6, button)),
    content="[]",
  )
  debug_inspect(
    limit_check(
      {
        "type": 1,
        "components": [
          { "type": 10, "content": limit_text(10000) },
          { "type": 2, "style": 1, "label": "Hi" },
        ],
      },
      modal=false,
    ),
    content="[]",
  )
}
