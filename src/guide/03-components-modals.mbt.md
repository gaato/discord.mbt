# Components and modals

Component handlers are routed by a `custom_id` prefix. Put handler identity in
the prefix and compact state in the suffix:

```text
ticket:close:123456789012345678
^^^^^^^^^^^^ handler prefix
             ^^^^^^^^^^^^^^^^^^ state suffix
```

Keep the complete ID within Discord's 100-character limit. Treat suffixes as
untrusted input and authorize the user again in the handler.

## Buttons and selects

Components are placed inside action rows:

```mbt check
///|
let controls : Array[@model.Component] = [
  @discord.action_row([
    @discord.button(
      custom_id="ticket:close:123456789012345678",
      label="Close",
      style=Danger,
    ),
    @discord.string_select(
      custom_id="ticket:priority:123456789012345678",
      placeholder="Priority",
      options=[
        @discord.select_option(label="Low", value="low"),
        @discord.select_option(label="High", value="high"),
      ],
    ),
  ]),
]
```

Register one handler per prefix. `suffix()` removes the registered prefix;
`values()` returns string-select values.

```mbt check
///|
fn register_ticket_handlers(app : @discord.App) -> Unit {
  app.on_component(
    prefix="ticket:close:",
    Immediate(ctx => {
      @discord.ComponentReply::update_message(
        content="Closed ticket \{ctx.suffix()}",
        components=[],
      )
    }),
  )
  app.on_component(
    prefix="ticket:priority:",
    Immediate(ctx => {
      let priority = ctx.values().get(0).unwrap_or("none")
      @discord.ComponentReply::message(
        content="Priority: \{priority}",
        ephemeral=true,
      )
    }),
  )
}
```

Component interaction contexts expose a non-optional `message()`, plus
`scope()` and `user()` for the invoker.

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
async fn edit_to_components_v2(ctx : @discord.CommandCtx) -> Unit {
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
    @discord.text_field(custom_id="topic", label="Topic"),
    @discord.text_field(custom_id="details", label="Details", style=Paragraph).optional(),
    (topic, details) => { topic, details },
  ),
)

///|
fn register_feedback(app : @discord.App) -> Unit {
  app.on_component(
    prefix="feedback:",
    Immediate(ctx => {
      @discord.ComponentReply::ShowModal(feedback.show(state=ctx.suffix()))
    }),
  )
  app.on_modal(
    feedback,
    Immediate((ctx, form) => {
      @discord.InitialResponse::message(
        content="topic=\{form.topic}; state=\{ctx.state().unwrap_or("none")}",
        ephemeral=true,
      )
    }),
  )
}
```

`ModalImmediateCtx::origin()` distinguishes a modal opened from a component
from one opened from a command. `state()` is the value passed to `show`.

## Waiting for one component

A deferred handler can wait for an exact custom ID. Waiters take precedence
over prefix handlers.

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
  ignore(controls)
  ignore(register_ticket_handlers)
  ignore(register_feedback)
  ignore(confirm_command)
}
```

Use a user- or interaction-specific value in the exact ID so another user
cannot satisfy the waiter accidentally.
