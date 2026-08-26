///|
fn submitted_components(fixture : String) -> Array[@model.Component] raise {
  let data : @model.ModalData = @json.from_json(@json.parse(fixture))
  data.components
}

///|
fn test_modal_fields() -> ModalFields[(String, Array[String]?)] {
  ModalFields::map2(
    text_field(custom_id="note", label="Note"),
    select_field(custom_id="color", label="Color", options=[
      @interaction.select_option(label="Blue", value="blue"),
    ]).optional(),
    (note, colors) => (note, colors),
  )
}

///|
test "modal fields decode label and legacy action-row submissions" {
  let form = modal(
    custom_id="feedback",
    title="Feedback",
    fields=test_modal_fields(),
  )
  let modern = submitted_components(
    (
      #|{"custom_id":"feedback:ticket-7","components":[{"type":18,"label":"Note","component":{"type":4,"custom_id":"note","style":1,"value":"hello"}},{"type":18,"label":"Color","component":{"type":3,"custom_id":"color","values":["blue"]}}]}
    ),
  )
  debug_inspect(
    form.decode(modern),
    content=(
      #|("hello", Some(["blue"]))
    ),
  )
  let legacy = submitted_components(
    (
      #|{"custom_id":"feedback","components":[{"type":1,"components":[{"type":4,"custom_id":"note","style":2,"label":"Note","value":"legacy"}]},{"type":1,"components":[{"type":3,"custom_id":"color","values":[]}]}]}
    ),
  )
  debug_inspect(
    form.decode(legacy),
    content=(
      #|("legacy", None)
    ),
  )
}

///|
test "modal field optional default and validation semantics" {
  let empty : Array[@model.Component] = []
  let optional = ModalFields::of(
    text_field(custom_id="optional", label="Optional").optional(),
  )
  debug_inspect((optional.decode_)(empty), content="None")
  let defaulted = ModalFields::of(
    text_field(custom_id="defaulted", label="Defaulted").with_default(
      "fallback",
    ),
  )
  inspect((defaulted.decode_)(empty), content="fallback")
  let validated = modal(
    custom_id="validated",
    title="Validated",
    fields=ModalFields::of(
      text_field(custom_id="code", label="Code").validate(value => {
        if value == "ok" {
          None
        } else {
          Some("code must be ok")
        }
      }),
    ),
  )
  let invalid = submitted_components(
    (
      #|{"custom_id":"validated","components":[{"type":18,"label":"Code","component":{"type":4,"custom_id":"code","style":1,"value":"bad"}}]}
    ),
  )
  try validated.decode(invalid) catch {
    InvalidArgument(message) => inspect(message, content="code must be ok")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected validation failure")
  }
  try validated.decode([]) catch {
    InvalidArgument(message) =>
      inspect(message, content="missing modal field: code")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected required-field failure")
  }
}

///|
test "text fields include a static prefill value" {
  let fields = ModalFields::of(
    text_field(custom_id="note", label="Note", value="draft"),
  )
  json_inspect(fields.definitions_, content=[
    {
      "label": "Note",
      "component": {
        "custom_id": "note",
        "style": 1,
        "required": true,
        "value": "draft",
        "type": 4,
      },
      "type": 18,
    },
  ])
}

///|
test "modal show overrides prefills without changing its definition" {
  let form = modal(
    custom_id="feedback",
    title="Feedback",
    fields=ModalFields::of(
      text_field(custom_id="note", label="Note", value="static-default"),
    ),
  )
  let overridden = form.show(values={ "note": "per-request" })
  json_inspect(overridden.components_, content=[
    {
      "label": "Note",
      "component": {
        "custom_id": "note",
        "style": 1,
        "required": true,
        "value": "per-request",
        "type": 4,
      },
      "type": 18,
    },
  ])
  let pristine = form.show()
  json_inspect(pristine.components_, content=[
    {
      "label": "Note",
      "component": {
        "custom_id": "note",
        "style": 1,
        "required": true,
        "value": "static-default",
        "type": 4,
      },
      "type": 18,
    },
  ])
}

///|
test "modal show rejects unknown and non-text prefill keys" {
  let form = modal(
    custom_id="feedback",
    title="Feedback",
    fields=ModalFields::map2(
      text_field(custom_id="note", label="Note"),
      select_field(custom_id="color", label="Color", options=[
        @interaction.select_option(label="Blue", value="blue"),
      ]),
      (note, colors) => (note, colors),
    ),
  )
  try form.show(values={ "missing": "value" }) |> ignore catch {
    UnknownCustomId(custom_id~) => inspect(custom_id, content="missing")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown custom id error")
  }
  try form.show(values={ "color": "blue" }) |> ignore catch {
    NonTextInput(custom_id~) => inspect(custom_id, content="color")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-text input error")
  }
}

///|
test "app validation rejects duplicate modal text input ids" {
  let app = App(sync=Disabled)
  let form = modal(
    custom_id="duplicate",
    title="Duplicate fields",
    fields=ModalFields::map2(
      text_field(custom_id="same", label="First"),
      text_field(custom_id="same", label="Second"),
      (first, second) => (first, second),
    ),
  )
  app.on_modal(form, Raw(_ => ()))
  try app.validate() catch {
    DuplicateModalTextInput(custom_id~, field~) => {
      inspect(custom_id, content="duplicate")
      inspect(field, content="same")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate modal text input error")
  }
}

///|
test "modal show appends state and emits modern label components" {
  let handle = modal(
    custom_id="feedback",
    title="Feedback",
    fields=ModalFields::of(text_field(custom_id="note", label="Note")),
  ).show(state="ticket-7")
  inspect(handle.custom_id_, content="feedback:ticket-7")
  inspect(handle.title_, content="Feedback")
  json_inspect(handle.components_, content=[
    {
      "label": "Note",
      "component": {
        "custom_id": "note",
        "style": 1,
        "required": true,
        "type": 4,
      },
      "type": 18,
    },
  ])
}
