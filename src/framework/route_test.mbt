///|
fn route_modal_interaction(custom_id : String) -> @model.Interaction raise {
  let interaction = modal_interaction()
  guard interaction.data is Some(Modal(data)) else { fail("expected modal") }
  { ..interaction, data: Some(Modal({ ..data, custom_id, })), }
}

///|
async test "id routes match the exact id or id plus state, not a longer sibling id" {
  let fw = test_framework()
  let components : Array[String] = []
  let modals : Array[String] = []
  fw.component_id("feedback", ctx => components.push(ctx.data.custom_id))
  |> ignore
  fw.modal_id("feedback", ctx => modals.push(ctx.data.custom_id)) |> ignore
  for id in ["feedback", "feedback:", "feedback:ticket:42"] {
    assert_true(fw.process(component_interaction(id)))
    assert_true(fw.process(route_modal_interaction(id)))
  }
  for id in ["feedbackish", "feedbackish:42", "feed"] {
    assert_false(fw.process(component_interaction(id)))
    assert_false(fw.process(route_modal_interaction(id)))
  }
  assert_eq(components, ["feedback", "feedback:", "feedback:ticket:42"])
  assert_eq(modals, components)
}

///|
async test "strict prefix routes stay legal and the longest wins" {
  for longer_first in [false, true] {
    let fw = test_framework()
    let seen : Array[String] = []
    if longer_first {
      fw.component("ticket:close:", _ => seen.push("component-long")) |> ignore
      fw.modal("ticket:close:", _ => seen.push("modal-long")) |> ignore
    }
    fw.component("ticket:", _ => seen.push("component-short")) |> ignore
    fw.modal("ticket:", _ => seen.push("modal-short")) |> ignore
    if !longer_first {
      fw.component("ticket:close:", _ => seen.push("component-long")) |> ignore
      fw.modal("ticket:close:", _ => seen.push("modal-long")) |> ignore
    }
    assert_true(fw.process(component_interaction("ticket:close:42")))
    assert_true(fw.process(route_modal_interaction("ticket:close:42")))
    assert_eq(seen, ["component-long", "modal-long"])
  }
}

///|
async test "id routes rank by their effective prefix and ties keep registration order" {
  for id_first in [false, true] {
    let fw = test_framework()
    let seen : Array[String] = []
    fw.component("a", _ => seen.push("short")) |> ignore
    fw.modal("a", _ => seen.push("short")) |> ignore
    if id_first {
      fw.component_id("a", _ => seen.push("id")) |> ignore
      fw.modal_id("a", _ => seen.push("id")) |> ignore
    }
    fw.component("a:", _ => seen.push("prefix")) |> ignore
    fw.modal("a:", _ => seen.push("prefix")) |> ignore
    if !id_first {
      fw.component_id("a", _ => seen.push("id")) |> ignore
      fw.modal_id("a", _ => seen.push("id")) |> ignore
    }
    assert_true(fw.process(component_interaction("a:42")))
    assert_true(fw.process(route_modal_interaction("a:42")))
    let winner = if id_first { "id" } else { "prefix" }
    assert_eq(seen, [winner, winner])
  }
}
