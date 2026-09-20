# Components and modals

Define a `component_route` once and use it both to produce a button or select's
`custom_id` and to register its handler. The route owns an id and a
`CustomIdCodec[A]`; the handler receives decoded state of type `A`:

```text
ticket-close:42
^^^^^^^^^^^^ route id
             ^^ encoded state
```

`route.custom_id(state)` enforces Discord's 100-character limit, measured
conservatively in UTF-16 units. Treat decoded state as untrusted input and
authorize the user again in the handler.

## Buttons and selects

Components are placed inside action rows:

```mbt check
///|
let close_ticket : @discord.ComponentRoute[Int] = @discord.component_route(
  id="ticket-close",
  state=@discord.CustomIdCodec::int(),
)

///|
let ticket_priority : @discord.ComponentRoute[Int] = @discord.component_route(
  id="ticket-priority",
  state=@discord.CustomIdCodec::int(),
)

///|
fn ticket_controls(ticket : Int) -> Array[@model.Component] raise {
  [
    @discord.action_row([
      @discord.button(
        custom_id=close_ticket.custom_id(ticket),
        label="Close",
        style=Danger,
      ),
      @discord.string_select(
        custom_id=ticket_priority.custom_id(ticket),
        placeholder="Priority",
        options=[
          @discord.select_option(label="Low", value="low"),
          @discord.select_option(label="High", value="high"),
        ],
      ),
    ]),
  ]
}
```

Register the same route values. `values()` returns string-select values;
the second handler argument is the ticket carried in the custom id.

```mbt check
///|
fn register_ticket_handlers(app : @discord.App) -> Unit {
  app.on_component(
    close_ticket,
    Immediate((_, ticket) => {
      @discord.ComponentReply::update_message(
        content="Closed ticket \{ticket}",
        components=[],
      )
    }),
  )
  app.on_component(
    ticket_priority,
    Immediate((ctx, ticket) => {
      let priority = ctx.values().get(0).unwrap_or("none")
      @discord.ComponentReply::message(
        content="Ticket \{ticket} priority: \{priority}",
        ephemeral=true,
      )
    }),
  )
}
```

Component interaction contexts expose a non-optional `message()`, plus
`scope()` and `user()` for the invoker.

`CustomIdCodec::unit()` produces the bare route id; `string()`, `int()`, and
`id()` carry strings, integers, and typed snowflakes. `zip` joins two codecs
with `:` and splits at the first separator; only the final segment may contain
`:`. `imap` and `custom` support application types. Encoding ambiguous segments
raises `CustomIdError::SeparatorInSegment`; oversized ids raise `TooLong`.
Decode failures reach the error policy as `HandlerError::InvalidArgument`.

Typed routes match the exact id or that id followed by `:` and state, so
`ticket-closeish` does not match `ticket-close`. Route ids must be nonempty,
contain no `:`, and fit within 100 UTF-16 units. `App::validate` also rejects
duplicate effective prefixes: typed `ticket-close` collides with raw
`ticket-close:`. `on_component_raw(prefix~, handler)` and `on_modal_raw`
retain literal-prefix routing for advanced handlers. Strict prefix overlaps
are legal; the longest effective prefix wins, with registration order breaking
ties in the low-level Framework.

## Components V2

Components V2 lets components provide the message's layout and content instead
of using the legacy `content` and `embeds` fields. When a top-level V2
component is present, discord.mbt sets `IS_COMPONENTS_V2` automatically on
initial replies, followups, ordinary sends, and edits.

```mbt check
///|
let components_v2 : Array[@model.Component] = [
  @discord.container(
    components=[
      @discord.text_display("## Deployment ready\nChoose the next action."),
      @discord.separator(divider=true, spacing=1),
      @discord.action_row([
        @discord.button(
          custom_id="deploy:approve",
          label="Approve",
          style=Success,
        ),
        @discord.button(custom_id="deploy:cancel", label="Cancel", style=Danger),
      ]),
    ],
    accent_color=0x5865F2,
  ),
]
```

Do not pass `content` or non-empty `embeds` with these components; the library
raises `DiscordHttpError::Validation` before sending the request. Discord also
does not allow a message that has been sent as Components V2 to return to a V1
layout.

Deferring first is supported. The edit path detects the V2 layout and adds the
flag to the original-response PATCH:

```mbt check
///|
async fn edit_to_components_v2(ctx : @framework.CommandCtx) -> Unit {
  ctx.defer_response()
  ctx.edit_response(components=components_v2) |> ignore
}

///|
test "Components V2 declarations compile" {
  ignore(components_v2)
  ignore(edit_to_components_v2)
}
```

## Typed modals

Define modal fields once, then use the same `Modal[A]` for display and typed
submission decoding:

```mbt check
///|
struct Feedback {
  topic : String
  details : String?
} derive(Debug)

///|
let feedback : @discord.Modal[Feedback] = @discord.modal(
  custom_id="feedback",
  title="Feedback",
  fields=@discord.ModalFields::map2(
    @discord.text_field(
      custom_id="topic",
      label="Topic",
      value="General feedback",
    ),
    @discord.text_field(custom_id="details", label="Details", style=Paragraph).optional(),
    (topic, details) => { topic, details, },
  ),
)

///|
let feedback_state : @discord.CustomIdCodec[Int] = @discord.CustomIdCodec::int()

///|
let open_feedback : @discord.ComponentRoute[Int] = @discord.component_route(
  id="open-feedback",
  state=feedback_state,
)

///|
fn feedback_button(ticket : Int) -> @model.Component raise {
  @discord.button(custom_id=open_feedback.custom_id(ticket), label="Feedback")
}

///|
fn register_feedback(app : @discord.App) -> Unit {
  app.on_component(
    open_feedback,
    Immediate((_, ticket) => {
      ShowModal(
        feedback.show(state=feedback_state.encode(ticket), values={
          "topic": "Follow-up",
        }),
      )
    }),
  )
  app.on_modal(
    feedback,
    Immediate((ctx, form) => {
      let ticket = feedback_state.decode(ctx.state().unwrap_or(""))
      @discord.InitialResponse::message(
        content="ticket=\{ticket}; topic=\{form.topic}",
        ephemeral=true,
      )
    }),
  )
}
```

`text_field(value=...)` sets the reusable static default.
`Modal::show(values=...)` overrides selected text inputs for one response and
does not mutate the modal definition, so later calls return to the static
default. Override keys are text-input `custom_id` values. An unknown key or a
key naming a non-text field raises `ModalPrefillError` instead of being
silently ignored.

`ModalImmediateCtx::origin()` distinguishes a modal opened from a component
from one opened from a command. `state()` is the value passed to `show`.
Modal fields stay typed by `Modal[A]`; encode typed modal state with a codec
when calling `show`, then decode `ctx.state()` in the submission handler as
above. `show` checks the complete custom id, including state, against the same
100-unit limit and raises `CustomIdError::TooLong` if it is exceeded.

### File uploads

`file_field` adds a file upload input and decodes to the uploaded files'
`Attachment` objects, which Discord resolves alongside the submission.
`file_types` narrows the client's file picker to preset groups (`Image`,
`Video`, `Audio`) or dot-prefixed extensions; the same filter is available on
slash commands through `arg_attachment(file_types=...)`:

```mbt check
///|
let upload_report : @discord.Modal[Array[@model.Attachment]] = @discord.modal(
  custom_id="upload-report",
  title="Report",
  fields=@discord.ModalFields::of(
    @discord.file_field(
      custom_id="proof",
      label="Screenshots or a PDF",
      max_values=3,
      file_types=[Image, Extension(".pdf")],
    ),
  ),
)
```

Filters match file extensions only, so validate the attachment contents
before trusting them. `App::validate` rejects a filter with more than 10
entries or an extension without its leading dot.

## Waiting for one component

A deferred handler can wait for an exact custom ID. By default, only the user
who invoked the command or component may satisfy the wait. Waiters take
precedence over registered component handlers.

```mbt check
///|
let confirm_command : @discord.Command[Unit] = @discord.slash(
  name="confirm",
  description="Ask for confirmation",
  args=@discord.Args::unit(),
  handler=Deferred(ephemeral=false, (ctx, _) => {
    let custom_id = "confirm:\{ctx.interaction().id}"
    ctx.edit_original(content="Continue?", components=[
      @discord.action_row([
        @discord.button(custom_id~, label="Confirm", style=Success),
      ]),
    ])
    |> ignore
    match ctx.wait_for_component(custom_id~, timeout_ms=30_000) {
      Some(click) => click.update_message(content="Confirmed", components=[])
      None => ctx.edit_original(content="Timed out", components=[]) |> ignore
    }
  }),
)

///|
test "component and modal declarations compile" {
  let app = @discord.App()
  register_ticket_handlers(app)
  register_feedback(app)
  app.validate()
  assert_eq(ticket_controls(42).length(), 1)
  guard feedback_button(42) is Button(button) else { fail("expected button") }
  assert_eq(button.custom_id, Some("open-feedback:42"))
  ignore(upload_report)
  ignore(confirm_command)
}
```

For a public poll, opt out of the user filter explicitly with
`ctx.wait_for_component(custom_id~, from=Anyone, timeout_ms=30_000)`. Keep an
interaction-specific value in the exact ID when concurrent waits are possible;
the unique value prevents two waits from colliding, while the default
`Invoker` filter provides user safety.

```mbt check
///|
fn component_wait_guide_interaction(
  user_id : String,
) -> @model.Interaction raise {
  let payload =
    #|{"id":"500000000000000050","application_id":"400000000000000001","type":3,"token":"interaction-token","version":1,"user":{"id":"USER_ID","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"message":{"id":"700000000000000001","channel_id":"800000000000000001","author":{"id":"200000000000000099","username":"bot","discriminator":"0","global_name":null,"avatar":null},"content":"confirm","timestamp":"2025-06-01T10:00:00.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0},"data":{"custom_id":"confirm:guide","component_type":2}}
  @json.from_json(@json.parse(payload.replace(old="USER_ID", new=user_id)))
}

///|
async test "another user's click does not satisfy a component wait" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let fw = @framework.Framework(client, @model.Id::parse("400000000000000001"))
  let invoker : @model.UserId = @model.Id::parse("200000000000000001")
  @async.with_task_group((group : @async.TaskGroup[Unit]) => {
    let pending = group.spawn(no_wait=true, () => {
      fw.wait_for_component(
        custom_id="confirm:guide",
        user=invoker,
        timeout_ms=1000,
      )
    })
    @async.sleep(20)
    assert_false(
      fw.process(component_wait_guide_interaction("200000000000000002")),
    )
    assert_true(
      fw.process(component_wait_guide_interaction("200000000000000001")),
    )
    guard pending.wait() is Some(click) else {
      fail("expected the invoking user's click")
    }
    assert_true(click.user().id == invoker)
  })
}
```
