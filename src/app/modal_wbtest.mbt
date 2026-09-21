///|
fn submission(components : Array[@model.Component]) -> ModalSubmission {
  { components, resolved: None, }
}

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
  debug_inspect((optional.decode_)(submission(empty)), content="None")
  let defaulted = ModalFields::of(
    text_field(custom_id="defaulted", label="Defaulted").with_default(
      "fallback",
    ),
  )
  inspect((defaulted.decode_)(submission(empty)), content="fallback")
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
  let app = App()
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

///|
/// The first limit violation `App::validate` reports for a one-field modal.
fn[A] modal_limit_violation(
  field : ModalField[A],
  title? : String = "Limits",
) -> String {
  let app = App()
  app.on_modal(
    modal(custom_id="limits", title~, fields=ModalFields::of(field)),
    Raw(_ => ()),
  )
  try app.validate() catch {
    ModalOutsideLimits(custom_id="limits", violation~) =>
      "\{violation.custom_id.unwrap_or("-")} \{violation.message()}"
    error => "unexpected error: \{Repr(error)}"
  } noraise {
    _ => "valid"
  }
}

///|
test "app validation rejects modal fields outside Discord's limits" {
  // The embed description limit is 4096, but a text input stops at 4000.
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body", max_length=4096),
    ),
    content=(
      #|body components[0].component.max_length: 4096 (1 to 4000)
    ),
  )
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body", max_length=4000),
    ),
    content="valid",
  )
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body", min_length=-1),
    ),
    content=(
      #|body components[0].component.min_length: -1 (0 to 4000)
    ),
  )
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body", min_length=9, max_length=3),
    ),
    content=(
      #|body components[0].component.min_length: 9 exceeds the maximum 3
    ),
  )
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body", value="x".repeat(4001)),
    ),
    content=(
      #|body components[0].component.value: 4001 units (at most 4000)
    ),
  )
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body", placeholder="x".repeat(101)),
    ),
    content=(
      #|body components[0].component.placeholder: 101 units (at most 100)
    ),
  )
  inspect(
    modal_limit_violation(text_field(custom_id="body", label="x".repeat(46))),
    content=(
      #|body components[0].label: 46 units (at most 45)
    ),
  )
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body", description="x".repeat(101)),
    ),
    content=(
      #|body components[0].description: 101 units (at most 100)
    ),
  )
  inspect(
    modal_limit_violation(
      select_field(custom_id="color", label="Color", options=[], max_values=26),
    ),
    content=(
      #|color components[0].component.max_values: 26 (0 to 25)
    ),
  )
  inspect(
    modal_limit_violation(
      file_field(custom_id="files", label="Files", max_values=11),
    ),
    content=(
      #|files components[0].component.max_values: 11 (0 to 10)
    ),
  )
  // Optional fields lower `min_values` to 0, which Discord accepts.
  inspect(
    modal_limit_violation(
      file_field(custom_id="files", label="Files").optional(),
    ),
    content="valid",
  )
  inspect(
    modal_limit_violation(
      text_field(custom_id="body", label="Body"),
      title="x".repeat(46),
    ),
    content=(
      #|- title: 46 units (at most 45)
    ),
  )
}

///|
test "modal show rejects a prefill value over 4000 units" {
  let form = modal(
    custom_id="edit",
    title="Edit",
    fields=ModalFields::of(text_field(custom_id="body", label="Body")),
  )
  form.show(values={ "body": "x".repeat(4000) }) |> ignore
  try form.show(values={ "body": "x".repeat(4001) }) |> ignore catch {
    ValueTooLong(custom_id~, length~) => {
      inspect(custom_id, content="body")
      inspect(length, content="4001")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected value too long error")
  }
}
