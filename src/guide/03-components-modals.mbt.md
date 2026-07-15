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
