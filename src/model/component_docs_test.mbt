// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/components/using-message-components.mdx
// Skipped blocks from this page:
// - line 36, Sending a Message with a Component — outbound message request body.
// - line 52, Sending a Message with Multiple Components — outbound message request body.
// - line 74, Nesting Components with Layout Components — outbound message request body.
// Page: developers/components/using-modal-components.mdx
// Skipped blocks from this page: none.

///|
test "discord docs: displaying a modal (line 26)" {
  let fixture =
    #|{
    #|  "type": 9,
    #|  "data": {
    #|    "custom_id": "bug_modal",
    #|    "title": "Bug Report",
    #|    "components": [
    #|      {
    #|        "type": 18,
    #|        "label": "What's your favorite bug?",
    #|        "component": {
    #|          "type": 3,
    #|          "custom_id": "bug_string_select",
    #|          "placeholder": "Choose...",
    #|          "options": [
    #|            {
    #|              "label": "Ant",
    #|              "value": "ant",
    #|              "description": "(best option)",
    #|              "emoji": {
    #|                "name": "🐜"
    #|              }
    #|            },
    #|            {
    #|              "label": "Butterfly",
    #|              "value": "butterfly",
    #|              "emoji": {
    #|                "name": "🦋"
    #|              }
    #|            },
    #|            {
    #|              "label": "Caterpillar",
    #|              "value": "caterpillar",
    #|              "emoji": {
    #|                "name": "🐛"
    #|              }
    #|            }
    #|          ]
    #|        }
    #|      },
    #|      {
    #|        "type": 18,
    #|        "label": "Why is it your favorite?",
    #|        "description": "Please provide as much detail as possible!",
    #|        "component": {
    #|          "type": 4,
    #|          "custom_id": "bug_explanation",
    #|          "style": 2,
    #|          "min_length": 1000,
    #|          "max_length": 4000,
    #|          "placeholder": "Write your explanation here...",
    #|          "required": true
    #|        }
    #|      }
    #|    ]
    #|  }
    #|}
  let first : @model.InteractionResponse = @json.from_json(@json.parse(fixture))
  let second : @model.InteractionResponse = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.typ.to_int(), content="9")
  guard first.data is Some(Object(data)) &&
    data.get("components") is Some(component_json) else {
    fail("modal response is missing components")
  }
  let components : Array[@model.Component] = @json.from_json(component_json)
  let components_again : Array[@model.Component] = @json.from_json(
    components.to_json(),
  )
  assert_eq("\{Repr(components)}", "\{Repr(components_again)}")
  inspect(components.length(), content="2")
}
