///|
test "select fields raise on missing submissions and map transforms values" {
  let colors = select_field(custom_id="color", label="Color", options=[
    @interaction.select_option(label="Blue", value="blue"),
  ])
  let empty : Array[@model.Component] = []
  try (colors.decode_)(empty) |> ignore catch {
    HandlerError::InvalidArgument(message) =>
      inspect(message, content="missing modal field: color")
    _ => fail("unexpected modal error")
  } noraise {
    _ => fail("expected a missing select field error")
  }
  let first = colors.map(values => values.get(0).unwrap_or("none"))
  let submitted = submitted_components(
    (
      #|{"custom_id":"pick","components":[{"type":18,"label":"Color","component":{"type":3,"custom_id":"color","values":["blue"]}}]}
    ),
  )
  inspect((first.decode_)(submitted), content="blue")
}

///|
test "modal field tuples decode at every arity" {
  fn note(id : String) -> ModalField[String] {
    text_field(custom_id=id, label=id)
  }

  let submitted = submitted_components(
    (
      #|{"custom_id":"many","components":[{"type":18,"label":"f1","component":{"type":4,"custom_id":"f1","style":1,"value":"a"}},{"type":18,"label":"f2","component":{"type":4,"custom_id":"f2","style":1,"value":"b"}},{"type":18,"label":"f3","component":{"type":4,"custom_id":"f3","style":1,"value":"c"}},{"type":18,"label":"f4","component":{"type":4,"custom_id":"f4","style":1,"value":"d"}},{"type":18,"label":"f5","component":{"type":4,"custom_id":"f5","style":1,"value":"e"}}]}
    ),
  )
  inspect(
    (ModalFields::map1(note("f1"), value => value + "!").decode_)(submitted),
    content="a!",
  )
  inspect(
    (ModalFields::map3(note("f1"), note("f2"), note("f3"), (a, b, c) => {
      a + b + c
    }).decode_)(submitted),
    content="abc",
  )
  inspect(
    (ModalFields::map4(note("f1"), note("f2"), note("f3"), note("f4"), (
      a,
      b,
      c,
      d,
    ) => a + b + c + d).decode_)(submitted),
    content="abcd",
  )
  inspect(
    (ModalFields::map5(
      note("f1"),
      note("f2"),
      note("f3"),
      note("f4"),
      note("f5"),
      (a, b, c, d, e) => a + b + c + d + e,
    ).decode_)(submitted),
    content="abcde",
  )
}

///|
test "legacy action rows thread through ids, prefill, and optional marking" {
  let row : @model.Component = ActionRow({
    id: None,
    components: [
      TextInput({
        id: None,
        custom_id: "note",
        style: Some(@model.TextInputStyle::Short),
        label: Some("Note"),
        min_length: None,
        max_length: None,
        required: None,
        value: None,
        placeholder: None,
      }),
    ],
  })
  debug_inspect(modal_text_input_ids([row]), content="[\"note\"]")
  guard prefill_modal_component(row, Map([("note", "hello")]))
    is ActionRow({ components: [TextInput({ value: Some("hello"), .. })], .. }) else {
    fail("expected the prefill to reach the nested text input")
  }
  guard prefill_modal_component(row, Map([("other", "x")]))
    is ActionRow({ components: [TextInput({ value: None, .. })], .. }) else {
    fail("expected an unmatched prefill to leave the input untouched")
  }
  guard set_modal_field_optional(row) is ActionRow(_) else {
    fail("expected non-label components to pass through unchanged")
  }
}

///|
test "modal state parsing accepts bare and suffixed ids and rejects others" {
  assert_true(modal_state("feedback", "feedback") is None)
  assert_true(modal_state("feedback", "feedback:s-1") is Some("s-1"))
  try modal_state("feedback", "different") |> ignore catch {
    HandlerError::InvalidArgument(message) =>
      inspect(message, content="modal custom_id does not match feedback")
    _ => fail("unexpected modal state error")
  } noraise {
    _ => fail("expected a mismatched custom_id error")
  }
}
