///|
/// A registered command: its registration spec plus its handler.
priv struct CommandEntry {
  spec : @interaction.CommandSpec
  handler : async (CommandCtx) -> Unit
}

///|
fn command_key(typ : @model.ApplicationCommandType, name : String) -> String {
  "\{typ.to_int()}:\{name}"
}

///|
/// One task waiting for a specific component interaction.
priv struct ComponentWaiter {
  custom_id : String
  queue : @aqueue.Queue[ComponentCtx]
}

///|
/// Routes incoming interactions to declared command / component / modal
/// handlers, and can register the declared commands with Discord.
///
/// Registration methods return `self` for chaining. Feed every
/// `InteractionCreate` gateway event to `process`.
pub struct Framework {
  priv client : @dhttp.Client
  priv application_id : @model.ApplicationId
  priv commands : Map[String, CommandEntry]
  priv autocompletes : Map[String, async (AutocompleteCtx) -> Unit]
  priv components : Array[(String, async (ComponentCtx) -> Unit)]
  priv modals : Array[(String, async (ModalCtx) -> Unit)]
  priv waiters : Array[ComponentWaiter]
  priv mut error_hook : (async (String, Error) -> Unit)?
}

///|
pub fn Framework::Framework(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
) -> Framework {
  {
    client,
    application_id,
    commands: Map([]),
    autocompletes: Map([]),
    components: [],
    modals: [],
    waiters: [],
    error_hook: None,
  }
}

///|
/// Register a command: `spec` describes it to Discord, `handler` runs when
/// it is invoked. Routing is by command type and top-level command name;
/// subcommand routing happens inside the handler via `ctx.options.path()`.
pub fn Framework::command(
  self : Framework,
  spec : @interaction.CommandSpec,
  handler : async (CommandCtx) -> Unit,
) -> Framework {
  self.commands[command_key(spec.typ, spec.name)] = { spec, handler }
  self
}

///|
/// Register an autocomplete handler for a command name.
pub fn Framework::autocomplete(
  self : Framework,
  command_name : String,
  handler : async (AutocompleteCtx) -> Unit,
) -> Framework {
  self.autocompletes[command_name] = handler
  self
}

///|
/// Register a component handler for custom ids starting with `prefix`.
/// Handlers are tried in registration order; waiters take precedence.
pub fn Framework::component(
  self : Framework,
  prefix : String,
  handler : async (ComponentCtx) -> Unit,
) -> Framework {
  self.components.push((prefix, handler))
  self
}

///|
/// Register a modal-submit handler for custom ids starting with `prefix`.
pub fn Framework::modal(
  self : Framework,
  prefix : String,
  handler : async (ModalCtx) -> Unit,
) -> Framework {
  self.modals.push((prefix, handler))
  self
}

///|
/// Install an error hook. When set, handler errors are passed to it
/// (with a `kind:name` label) instead of propagating out of `process`.
pub fn Framework::on_error(
  self : Framework,
  hook : async (String, Error) -> Unit,
) -> Framework {
  self.error_hook = Some(hook)
  self
}

///|
/// The registration payload for every declared command, as sent to the
/// bulk-overwrite endpoints.
pub fn Framework::command_specs(self : Framework) -> Json {
  let specs = []
  for _, entry in self.commands {
    specs.push(entry.spec.to_json())
  }
  Json::array(specs)
}

///|
/// Replace all global commands with the declared ones.
pub async fn Framework::sync_global(
  self : Framework,
) -> Array[@model.ApplicationCommand] {
  self.client.bulk_overwrite_global_commands(
    self.application_id,
    self.command_specs(),
  )
}

///|
/// Replace all commands of one guild with the declared ones. Guild
/// commands update instantly, which makes this the right call during
/// development.
pub async fn Framework::sync_guild(
  self : Framework,
  guild_id : @model.GuildId,
) -> Array[@model.ApplicationCommand] {
  self.client.bulk_overwrite_guild_commands(
    self.application_id,
    guild_id,
    self.command_specs(),
  )
}

///|
async fn Framework::guard_errors(
  self : Framework,
  label : String,
  body : async () -> Unit,
) -> Unit {
  match self.error_hook {
    Some(hook) => body() catch { error => hook(label, error) }
    None => body()
  }
}

///|
/// Route one interaction. Returns `true` when a handler (or waiter)
/// consumed it, `false` when nothing matched. Handler errors propagate
/// unless an `on_error` hook is installed.
pub async fn Framework::process(
  self : Framework,
  interaction : @model.Interaction,
) -> Bool {
  let gate = ResponseGate::rest(self.client, interaction)
  self.process_with(interaction, gate~)
}

///|
/// Route one interaction through a caller-provided initial-response gate.
pub async fn Framework::process_with(
  self : Framework,
  interaction : @model.Interaction,
  gate~ : ResponseGate,
) -> Bool {
  match interaction.typ {
    Ping => {
      gate.send({ typ: Pong, data: None })
      true
    }
    ApplicationCommand => {
      guard interaction.data is Some(Command(data)) else { return false }
      guard self.commands.get(command_key(data.typ, data.name)) is Some(entry) else {
        return false
      }
      let scope = interaction_scope(interaction)
      let ctx : CommandCtx = {
        client: self.client,
        application_id: self.application_id,
        interaction,
        data,
        options: @interaction.CommandOptions::from_data(data),
        scope_: scope,
        gate,
      }
      self.guard_errors("command:\{data.name}", () => (entry.handler)(ctx))
      true
    }
    ApplicationCommandAutocomplete => {
      guard interaction.data is Some(Command(data)) else { return false }
      guard self.autocompletes.get(data.name) is Some(handler) else {
        return false
      }
      let ctx : AutocompleteCtx = {
        client: self.client,
        application_id: self.application_id,
        interaction,
        data,
        options: @interaction.CommandOptions::from_data(data),
        gate,
      }
      self.guard_errors("autocomplete:\{data.name}", () => handler(ctx))
      true
    }
    MessageComponent => {
      guard interaction.data is Some(Component(data)) else { return false }
      // Validate the guarantees of ComponentCtx before waiters or registered
      // routes can observe this interaction.
      let scope = interaction_scope(interaction)
      let message = component_message(interaction)
      let ctx : ComponentCtx = {
        client: self.client,
        application_id: self.application_id,
        interaction,
        data,
        scope_: scope,
        message_: message,
        gate,
      }
      for i, waiter in self.waiters {
        if waiter.custom_id == data.custom_id {
          self.waiters.remove(i) |> ignore
          waiter.queue.put(ctx)
          return true
        }
      }
      for entry in self.components {
        let (prefix, handler) = entry
        if data.custom_id.has_prefix(prefix) {
          self.guard_errors("component:\{data.custom_id}", () => handler(ctx))
          return true
        }
      }
      false
    }
    ModalSubmit => {
      guard interaction.data is Some(Modal(data)) else { return false }
      let scope = interaction_scope(interaction)
      let origin = modal_origin(interaction)
      for entry in self.modals {
        let (prefix, handler) = entry
        if data.custom_id.has_prefix(prefix) {
          let ctx : ModalCtx = {
            client: self.client,
            application_id: self.application_id,
            interaction,
            data,
            scope_: scope,
            origin_: origin,
            gate,
          }
          self.guard_errors("modal:\{data.custom_id}", () => handler(ctx))
          return true
        }
      }
      false
    }
    Unknown(_) => false
  }
}

///|
/// Wait for the next component interaction whose custom id matches
/// exactly. Returns `None` on timeout. Waiters win over registered
/// component handlers, which makes multi-step flows (confirm buttons,
/// pagination) straightforward inside one handler.
pub async fn Framework::wait_for_component(
  self : Framework,
  custom_id~ : String,
  timeout_ms? : Int,
) -> ComponentCtx? {
  let waiter : ComponentWaiter = { custom_id, queue: Queue(kind=Unbounded) }
  self.waiters.push(waiter)
  defer (for i, pending in self.waiters {
    if physical_equal(pending, waiter) {
      self.waiters.remove(i) |> ignore
      break
    }
  })
  match timeout_ms {
    Some(ms) => @async.with_timeout_opt(ms, () => waiter.queue.get())
    None => Some(waiter.queue.get())
  }
}
