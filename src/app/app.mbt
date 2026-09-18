///|
/// Where application commands are synchronized after the first READY.
pub(all) enum CommandSync {
  Global
  Guild(@model.GuildId)
  Guilds(Array[@model.GuildId])
  Disabled
} derive(Debug)

///|
/// Configuration errors detected before starting an application executor.
pub(all) suberror AppConfigError {
  EmptyToken
  DuplicateCommand(name~ : String)
  DuplicateCommandPath(command~ : String, path~ : String)
  NestedSubcommandGroup(command~ : String, path~ : String)
  ChoicesWithAutocomplete(command~ : String, path~ : String)
  RequiredOptionAfterOptional(command~ : String, path~ : String)
  InvalidModalFieldCount(custom_id~ : String, count~ : Int)
  DuplicateModalTextInput(custom_id~ : String, field~ : String)
  /// A `file_types` filter with more than 10 entries or an extension that is
  /// not dot-prefixed. `owner` is a command option path or modal field id.
  InvalidFileTypes(owner~ : String, reason~ : String)
  InvalidCooldown(command~ : String, seconds~ : Int)
  InvalidMaxInFlight(value~ : Int)
} derive(Debug)

///|
priv struct RegisteredComponent {
  prefix : String
  handler : ComponentHandler
}

///|
priv struct RegisteredModal {
  prefix : String
  field_count : Int?
  text_input_ids : Array[String]?
  file_type_filters : Array[(String, Array[@model.FileTypeFilter])]
  dispatch : async (AppCtx, @framework.ModalCtx) -> Unit
}

///|
priv struct AutocompleteHandler {
  name : String
  dispatch : async (@framework.AutocompleteCtx) -> Unit
}

///|
/// Executor-provided function that runs a handler task concurrently on
/// the surrounding async runtime.
pub type Spawner = async (async () -> Unit) -> Unit

///|
/// Gateway-free application declarations shared by gateway and HTTP executors.
pub struct App {
  priv sync_ : CommandSync
  priv max_in_flight_ : Int
  priv commands_ : Array[RegisteredCommand]
  priv components_ : Array[RegisteredComponent]
  priv modals_ : Array[RegisteredModal]
  priv autocompletes_ : Array[AutocompleteHandler]
  priv middleware_ : Array[InteractionMiddleware]
  priv mut policy_ : ErrorPolicy?
  priv mut warn_ : (String) -> Unit
  priv mut now_ : () -> Int64
}

///|
/// Create an application core. `sync` picks the command-sync strategy
/// applied by `sync_commands` (default: overwrite global commands);
/// `max_in_flight` caps concurrently running interaction handlers.
pub fn App::App(sync? : CommandSync = Global, max_in_flight? : Int = 64) -> App {
  {
    sync_: sync,
    max_in_flight_: max_in_flight,
    commands_: [],
    components_: [],
    modals_: [],
    autocompletes_: [],
    middleware_: [],
    policy_: None,
    warn_: message => println(message),
    now_: @clock.now_ms,
  }
}

///|
/// Install middleware around every command, component, and modal handler
/// (not autocomplete). First installed is outermost. Runs inside the error
/// policy: raising HandlerError behaves exactly like a failing check.
pub fn App::middleware(self : App, middleware : InteractionMiddleware) -> Unit {
  self.middleware_.push(middleware)
}

///|
/// Register a typed slash or context-menu command built with the
/// `command` / `user_command` / `message_command` builders.
pub fn[A] App::command(self : App, command : Command[A]) -> Unit {
  self.register(command.erase())
}

///|
/// Register a type-erased command. `App::command` is the typed
/// entry point; use this when composing pre-erased commands, e.g. from
/// a plugin.
pub fn App::register(self : App, command : RegisteredCommand) -> Unit {
  self.commands_.push(command)
}

///|
/// Route component interactions whose custom id starts with `prefix` to
/// `handler`. Longer prefixes win when several match.
pub fn App::on_component(
  self : App,
  prefix~ : String,
  handler : ComponentHandler,
) -> Unit {
  self.components_.push({ prefix, handler, })
}

///|
/// Route submissions of the typed `modal` to `handler`; field values
/// are decoded through the modal's `ModalFields` before the handler
/// runs.
pub fn[A] App::on_modal(
  self : App,
  modal : Modal[A],
  handler : ModalSubmitHandler[A],
) -> Unit {
  self.modals_.push({
    prefix: modal.custom_id_,
    field_count: Some(modal.fields_.definitions_.length()),
    text_input_ids: Some(modal_text_input_ids(modal.fields_.definitions_)),
    file_type_filters: modal_file_type_filters(modal.fields_.definitions_),
    dispatch: (bot, raw) => dispatch_modal_handler(modal, handler, bot, raw),
  })
}

///|
/// Register a fully raw modal route without a typed modal definition.
pub fn App::on_modal_raw(
  self : App,
  prefix~ : String,
  handler : async (@framework.ModalCtx) -> Unit,
) -> Unit {
  self.modals_.push({
    prefix,
    field_count: None,
    text_input_ids: None,
    file_type_filters: [],
    dispatch: (_, raw) => handler(raw),
  })
}

///|
/// Register a raw autocomplete handler. A raw handler takes precedence over
/// Arg-level `suggest` handlers registered for the same command name.
pub fn App::autocomplete(
  self : App,
  name : String,
  handler : async (@framework.AutocompleteCtx) -> Unit,
) -> Unit {
  self.autocompletes_.push({ name, dispatch: handler, })
}

///|
/// Replace the error policy invoked when a handler raises. The default
/// policy maps `HandlerError` variants to ephemeral user-facing
/// messages and warns about everything else.
pub fn App::error_policy(self : App, policy : ErrorPolicy) -> Unit {
  self.policy_ = Some(policy)
}

///|
/// Replace the warning hook used for non-fatal diagnostics (default:
/// `println`).
pub fn App::on_warn(self : App, hook : (String) -> Unit) -> Unit {
  self.warn_ = hook
}

///|
/// Internal clock seam used by deterministic command-dispatch tests.
#warnings("-unused_value")
fn App::set_clock(self : App, clock : () -> Int64) -> Unit {
  self.now_ = clock
}

///|
fn App::current_policy(self : App) -> ErrorPolicy {
  self.policy_.unwrap_or_else(() => default_error_policy(self.warn_))
}

///|
fn validate_file_types(
  owner : String,
  filters : Array[@model.FileTypeFilter],
) -> Unit raise AppConfigError {
  if filters.length() > 10 {
    raise InvalidFileTypes(
      owner~,
      reason="\{filters.length()} entries (at most 10)",
    )
  }
  for filter in filters {
    if filter is Extension(extension) &&
      (!extension.has_prefix(".") || extension.length() < 2) {
      raise InvalidFileTypes(
        owner~,
        reason="extension \{extension} is not dot-prefixed",
      )
    }
  }
}

///|
fn validate_command_options(
  command : String,
  parent_path : Array[String],
  options : Array[@model.CommandOption],
) -> Unit raise AppConfigError {
  let mut saw_optional = false
  for option in options {
    let path = parent_path.copy()
    path.push(option.name)
    if option.autocomplete is Some(true) && option.choices is Some(_) {
      raise ChoicesWithAutocomplete(command~, path=path.join("/"))
    }
    if !(option.typ is (SubCommand | SubCommandGroup)) {
      if option.required is Some(true) {
        if saw_optional {
          raise RequiredOptionAfterOptional(command~, path=path.join("/"))
        }
      } else {
        saw_optional = true
      }
    }
    if option.file_types is Some(filters) {
      validate_file_types("\{command}/\{path.join("/")}", filters)
    }
    if option.options is Some(children) {
      validate_command_options(command, path, children)
    }
  }
}

///|
/// Check declarations for configuration errors: invalid command trees and
/// cooldowns, invalid modal field counts, duplicate modal text-input ids,
/// and malformed `file_types` upload filters.
/// Executors call this at startup; call it directly in a test to fail fast.
pub fn App::validate(self : App) -> Unit raise AppConfigError {
  if self.max_in_flight_ <= 0 {
    raise InvalidMaxInFlight(value=self.max_in_flight_)
  }
  let commands : Set[String] = Set([])
  for command in self.commands_ {
    let command_key = command_key(command.definition.typ, command.name_)
    if commands.contains(command_key) {
      raise DuplicateCommand(name=command.name_)
    }
    commands.add(command_key)
    for path in command.nested_group_paths_ {
      raise NestedSubcommandGroup(command=command.name_, path=path.join("/"))
    }
    let paths : Set[String] = Set([])
    for path in command.node_paths_ {
      let key = path_key(path)
      if paths.contains(key) {
        raise DuplicateCommandPath(command=command.name_, path=path.join("/"))
      }
      paths.add(key)
    }
    validate_command_options(command.name_, [], command.definition.options)
    if command.cooldown_ is Some(config) && config.seconds <= 0 {
      raise InvalidCooldown(command=command.name_, seconds=config.seconds)
    }
  }
  for modal in self.modals_ {
    if modal.field_count is Some(count) && (count < 1 || count > 5) {
      raise InvalidModalFieldCount(custom_id=modal.prefix, count~)
    }
    for entry in modal.file_type_filters {
      validate_file_types("\{modal.prefix}/\{entry.0}", entry.1)
    }
    if modal.text_input_ids is Some(ids) {
      let seen : Set[String] = Set([])
      for field in ids {
        if seen.contains(field) {
          raise DuplicateModalTextInput(custom_id=modal.prefix, field~)
        }
        seen.add(field)
      }
    }
  }
}

///|
async fn spawn_limited(
  group : @async.TaskGroup[Unit],
  limiter : @async.Semaphore,
  body : async () -> Unit,
) -> Unit {
  // Acquire before spawning: at capacity, the executor applies bounded
  // backpressure instead of allocating an unbounded list of pending tasks.
  limiter.acquire()
  group.spawn_bg(allow_failure=true, () => {
    defer limiter.release()
    body()
  })
}

///|
fn bounded_spawner(
  group : @async.TaskGroup[Unit],
  limiter : @async.Semaphore,
) -> Spawner {
  body => spawn_limited(group, limiter, body)
}

///|
/// Create a bounded task spawner for an executor-owned task group.
pub fn App::spawner(self : App, group : @async.TaskGroup[Unit]) -> Spawner {
  bounded_spawner(group, Semaphore(self.max_in_flight_))
}

///|
fn failure_context(
  origin : FailureOrigin,
  phase : ResponsePhase?,
  raw : FailureRaw?,
  warn : (String) -> Unit,
) -> FailureCtx {
  { origin_: origin, phase_: phase, raw_: raw, warn_: warn, }
}

///|
async fn App::run_registered_command(
  self : App,
  bot : AppCtx,
  waiter : ComponentWaiter?,
  command : RegisteredCommand,
  raw : @framework.CommandCtx,
) -> Unit {
  let failure_raw = RawCommand(raw)
  let ctx = InteractionCtx::{
    target_: Command(name=command.name_),
    raw_: failure_raw,
  }
  self.run_middleware(ctx, 0, () => {
    command.run_checks_and_cooldown(raw, (self.now_)())
    (command.dispatch)(bot, waiter, self.warn_, raw)
  }) catch {
    error if @async.is_being_cancelled() => raise error
    AppDispatchError::Failure(command=name, phase~, source~) =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Command(name~),
          Some(phase),
          Some(failure_raw),
          self.warn_,
        ),
        source,
      )
    error =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Command(name=command.name_),
          Some(BeforeInitial),
          Some(failure_raw),
          self.warn_,
        ),
        error,
      )
  }
}

///|
async fn App::run_registered_component(
  self : App,
  bot : AppCtx,
  waiter : ComponentWaiter?,
  entry : RegisteredComponent,
  raw : @framework.ComponentCtx,
) -> Unit {
  let failure_raw = RawComponent(raw)
  let ctx = InteractionCtx::{
    target_: Component(custom_id=raw.data.custom_id),
    raw_: failure_raw,
  }
  self.run_middleware(ctx, 0, () => {
    dispatch_component_handler(
      entry.prefix,
      entry.handler,
      bot,
      waiter,
      self.warn_,
      raw,
    )
  }) catch {
    error if @async.is_being_cancelled() => raise error
    AppDispatchError::Failure(command=_, phase~, source~) =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Component(custom_id=raw.data.custom_id),
          Some(phase),
          Some(failure_raw),
          self.warn_,
        ),
        source,
      )
    error =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Component(custom_id=raw.data.custom_id),
          Some(BeforeInitial),
          Some(failure_raw),
          self.warn_,
        ),
        error,
      )
  }
}

///|
async fn App::run_registered_modal(
  self : App,
  bot : AppCtx,
  entry : RegisteredModal,
  raw : @framework.ModalCtx,
) -> Unit {
  let failure_raw = RawModal(raw)
  let ctx = InteractionCtx::{
    target_: Modal(custom_id=raw.data.custom_id),
    raw_: failure_raw,
  }
  self.run_middleware(ctx, 0, () => (entry.dispatch)(bot, raw)) catch {
    error if @async.is_being_cancelled() => raise error
    AppDispatchError::Failure(command=_, phase~, source~) =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Modal(custom_id=raw.data.custom_id),
          Some(phase),
          Some(failure_raw),
          self.warn_,
        ),
        source,
      )
    error =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Modal(custom_id=raw.data.custom_id),
          Some(BeforeInitial),
          Some(failure_raw),
          self.warn_,
        ),
        error,
      )
  }
}

///|
async fn App::run_registered_autocomplete(
  self : App,
  command : RegisteredCommand,
  raw : @framework.AutocompleteCtx,
) -> Unit {
  dispatch_suggest(command.suggest_routes_, self.warn_, raw) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Autocomplete(name=command.name_),
          None,
          None,
          self.warn_,
        ),
        error,
      )
      // ErrorPolicy is transport-neutral and cannot construct an autocomplete
      // callback, so complete the interaction with a safe empty result.
      raw.suggest([])
    }
  }
}

///|
/// Wire every registered command, component, modal, and autocomplete
/// route into `framework` and return the `AppCtx` shared by handlers.
/// Called by the built-in executors (`Bot`, the HTTP endpoint); only
/// custom executors need it directly.
pub fn App::attach(
  self : App,
  framework : @framework.Framework,
  client~ : @dhttp.Client,
  application_id~ : @model.ApplicationId,
  waiter? : ComponentWaiter,
  latency_ms? : () -> Int64?,
) -> AppCtx {
  let app_ctx = AppCtx::{
    client_: client,
    application_id_: application_id,
    latency_ms_: latency_ms,
  }
  for command in self.commands_ {
    framework.command(command.definition, raw => {
      self.run_registered_command(app_ctx, waiter, command, raw)
    })
    |> ignore
    if !command.suggest_routes_.is_empty() {
      framework.autocomplete(command.name_, raw => {
        self.run_registered_autocomplete(command, raw)
      })
      |> ignore
    }
  }
  for entry in self.components_ {
    framework.component(entry.prefix, raw => {
      self.run_registered_component(app_ctx, waiter, entry, raw)
    })
    |> ignore
  }
  for entry in self.modals_ {
    framework.modal(entry.prefix, raw => {
      self.run_registered_modal(app_ctx, entry, raw)
    })
    |> ignore
  }
  // Registered last so explicitly configured raw handlers win by name.
  for entry in self.autocompletes_ {
    framework.autocomplete(entry.name, entry.dispatch) |> ignore
  }
  framework.on_error((label, error) => {
    if @async.is_being_cancelled() {
      raise error
    }
    (self.warn_)("framework handler failed (\{label}): \{Repr(error)}")
  })
  |> ignore
  app_ctx
}

///|
/// Push the declared command set to Discord following the `CommandSync`
/// strategy chosen at construction: global, one or more guilds, or
/// disabled.
pub async fn App::sync_commands(
  self : App,
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
) -> Unit {
  let specs = self.commands_.map(command => command.definition)
  match self.sync_ {
    Global => sync_global_commands(client, application_id, specs)
    Guild(guild_id) =>
      sync_guild_commands(client, application_id, guild_id, specs)
    Guilds(guild_ids) =>
      for guild_id in guild_ids {
        sync_guild_commands(client, application_id, guild_id, specs)
      }
    Disabled => ()
  }
}

///|
/// Run the error policy for a failure raised outside interaction
/// dispatch. Executors use this for event and service handlers; the
/// policy context has no response target in that case.
pub async fn App::report_failure(
  self : App,
  origin : FailureOrigin,
  error : Error,
) -> Unit {
  invoke_error_policy(
    self.current_policy(),
    failure_context(origin, None, None, self.warn_),
    error,
  )
}

///|
/// Emit a message through the app's warning hook.
pub fn App::warn(self : App, message : String) -> Unit {
  (self.warn_)(message)
}
