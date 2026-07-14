///|
/// Execution strategy for a typed application command.
pub(all) enum InteractionHandler[A] {
  Immediate(async (ImmediateCtx, A) -> CommandReply)
  Deferred(ephemeral~ : Bool, async (DeferredCtx, A) -> Unit)
  Raw(async (@framework.CommandCtx) -> Unit)
}

///|
/// The resolved target of a USER context-menu command.
pub(all) struct TargetUser {
  user : @model.User
  member : @model.GuildMember?
}

///|
priv struct SlashRoute {
  path : Array[String]
  dispatch : async (
    BotCtx,
    ComponentWaiter?,
    (String) -> Unit,
    @framework.CommandCtx,
  ) -> Unit
}

///|
/// A type-erased slash subcommand or subcommand group.
pub struct SlashChild {
  priv definition_ : @model.CommandOption
  priv routes_ : Array[SlashRoute]
  priv node_paths_ : Array[Array[String]]
  priv nested_group_paths_ : Array[Array[String]]
  priv is_group_ : Bool
}

///|
/// An application-command definition with a context-aware decoder.
pub struct Command[A] {
  priv definition : @interaction.CommandSpec
  priv decode : (@framework.CommandCtx) -> A raise
  priv handler : InteractionHandler[A]
  priv routes : Array[SlashRoute]?
  priv node_paths : Array[Array[String]]
  priv nested_group_paths : Array[Array[String]]
}

///|
/// Decode slash arguments and translate reader errors into a stable handler
/// error understood by the bot error policy.
fn[A] decode_command_args(
  args : @interaction.Args[A],
  options : @interaction.CommandOptions,
) -> A raise HandlerError {
  args.decode(options) catch {
    source => raise InvalidArgument("\{to_repr(source)}")
  }
}

///|
/// Define a typed slash command.
pub fn[A] slash(
  name~ : String,
  description~ : String,
  args~ : @interaction.Args[A],
  handler~ : InteractionHandler[A],
  default_member_permissions? : @model.Permissions,
  nsfw? : Bool,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
) -> Command[A] {
  {
    definition: @interaction.CommandSpec::slash(
      name,
      description,
      options=args.definitions(),
      default_member_permissions?,
      nsfw?,
      integration_types?,
      contexts?,
    ),
    decode: raw => decode_command_args(args, raw.options),
    handler,
    routes: None,
    node_paths: [],
    nested_group_paths: [],
  }
}

///|
fn target_key(raw : @framework.CommandCtx) -> String raise HandlerError {
  guard raw.data.target_id is Some(target_id) else {
    raise InvalidArgument("context command is missing target_id")
  }
  target_id.to_string()
}

///|
fn decode_target_user(
  raw : @framework.CommandCtx,
) -> TargetUser raise HandlerError {
  let key = target_key(raw)
  guard raw.data.resolved is Some(resolved) else {
    raise InvalidArgument("user target is missing resolved data")
  }
  guard resolved.users is Some(users) && users.get(key) is Some(user) else {
    raise InvalidArgument("resolved user target \{key} was not found")
  }
  let target_member = match resolved.members {
    Some(members) => members.get(key)
    None => None
  }
  { user, member: target_member }
}

///|
fn decode_target_message(
  raw : @framework.CommandCtx,
) -> @model.Message raise HandlerError {
  let key = target_key(raw)
  guard raw.data.resolved is Some(resolved) else {
    raise InvalidArgument("message target is missing resolved data")
  }
  guard resolved.messages is Some(messages) &&
    messages.get(key) is Some(message) else {
    raise InvalidArgument("resolved message target \{key} was not found")
  }
  message
}

///|
/// Define a USER context-menu command.
pub fn user_command(
  name~ : String,
  handler~ : InteractionHandler[TargetUser],
  default_member_permissions? : @model.Permissions,
  nsfw? : Bool,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
) -> Command[TargetUser] {
  {
    definition: @interaction.CommandSpec::user(
      name,
      default_member_permissions?,
      nsfw?,
      integration_types?,
      contexts?,
    ),
    decode: raw => decode_target_user(raw),
    handler,
    routes: None,
    node_paths: [],
    nested_group_paths: [],
  }
}

///|
/// Define a MESSAGE context-menu command.
pub fn message_command(
  name~ : String,
  handler~ : InteractionHandler[@model.Message],
  default_member_permissions? : @model.Permissions,
  nsfw? : Bool,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
) -> Command[@model.Message] {
  {
    definition: @interaction.CommandSpec::message(
      name,
      default_member_permissions?,
      nsfw?,
      integration_types?,
      contexts?,
    ),
    decode: raw => decode_target_message(raw),
    handler,
    routes: None,
    node_paths: [],
    nested_group_paths: [],
  }
}

///|
fn prefixed_path(prefix : String, path : Array[String]) -> Array[String] {
  let result = [prefix]
  for part in path {
    result.push(part)
  }
  result
}

///|
fn path_key(path : Array[String]) -> String {
  path.join("\u{1f}")
}

///|
/// Define a typed slash subcommand.
pub fn[A] subcommand(
  name~ : String,
  description~ : String,
  args~ : @interaction.Args[A],
  handler~ : InteractionHandler[A],
) -> SlashChild {
  let decode = (raw : @framework.CommandCtx) => {
    decode_command_args(args, raw.options)
  }
  {
    definition_: @interaction.sub_command(
      name,
      description,
      options=args.definitions(),
    ),
    routes_: [
      {
        path: [name],
        dispatch: (bot, waiter, warn, raw) => {
          dispatch_command_handler(
            raw.data.name,
            raw => decode(raw),
            handler,
            bot,
            waiter,
            warn,
            raw,
          )
        },
      },
    ],
    node_paths_: [[name]],
    nested_group_paths_: [],
    is_group_: false,
  }
}

///|
/// Define a slash subcommand group. Nested groups are retained for validation
/// and rejected by `Bot::validate`, never by panic or abort here.
pub fn subcommand_group(
  name~ : String,
  description~ : String,
  children~ : Array[SlashChild],
) -> SlashChild {
  let definitions = children.map(child => child.definition_)
  let routes = []
  let node_paths = [[name]]
  let nested_group_paths = []
  for child in children {
    for route in child.routes_ {
      routes.push({ ..route, path: prefixed_path(name, route.path) })
    }
    for path in child.node_paths_ {
      node_paths.push(prefixed_path(name, path))
    }
    if child.is_group_ {
      nested_group_paths.push([name, child.definition_.name])
    }
    for path in child.nested_group_paths_ {
      nested_group_paths.push(prefixed_path(name, path))
    }
  }
  {
    definition_: @interaction.sub_command_group(name, description, definitions),
    routes_: routes,
    node_paths_: node_paths,
    nested_group_paths_: nested_group_paths,
    is_group_: true,
  }
}

///|
/// Define a slash command whose children dispatch by submitted option path.
pub fn slash_group(
  name~ : String,
  description~ : String,
  children~ : Array[SlashChild],
  default_member_permissions? : @model.Permissions,
  nsfw? : Bool,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
) -> Command[Unit] {
  let routes = []
  let node_paths = []
  let nested_group_paths = []
  for child in children {
    routes.append(child.routes_)
    node_paths.append(child.node_paths_)
    nested_group_paths.append(child.nested_group_paths_)
  }
  {
    definition: @interaction.CommandSpec::slash(
      name,
      description,
      options=children.map(child => child.definition_),
      default_member_permissions?,
      nsfw?,
      integration_types?,
      contexts?,
    ),
    decode: _ => (),
    handler: Raw(_ => ()),
    routes: Some(routes),
    node_paths,
    nested_group_paths,
  }
}

///|
/// The command registration specification.
pub fn[A] Command::spec(self : Command[A]) -> @interaction.CommandSpec {
  self.definition
}

///|
fn[A] raise_failure(
  command : String,
  phase : ResponsePhase,
  source : Error,
) -> A raise BotDispatchError {
  raise Failure(command~, phase~, source~)
}

///|
async fn[A] dispatch_command_handler(
  command : String,
  decode : (@framework.CommandCtx) -> A raise,
  handler : InteractionHandler[A],
  bot : BotCtx,
  waiter : ComponentWaiter?,
  warn : (String) -> Unit,
  raw : @framework.CommandCtx,
) -> Unit {
  let value = decode(raw) catch {
    source => raise_failure(command, BeforeInitial, source)
  }
  match handler {
    Immediate(run) => {
      let response = run({ raw_: raw, bot_: bot }, value) catch {
        source => raise_failure(command, BeforeInitial, source)
      }
      response.send(raw) catch {
        source => raise_failure(command, BeforeInitial, source)
      }
    }
    Deferred(ephemeral~, run) => {
      raw.defer_response(ephemeral~) catch {
        source => raise_failure(command, BeforeInitial, source)
      }
      run({ raw_: raw, bot_: bot, waiter_: waiter, warn_: warn }, value) catch {
        source => raise_failure(command, AfterDeferred, source)
      }
    }
    Raw(run) =>
      run(raw) catch {
        source => raise_failure(command, BeforeInitial, source)
      }
  }
}

///|
async fn[A] Command::dispatch_typed(
  self : Command[A],
  bot : BotCtx,
  waiter : ComponentWaiter?,
  warn : (String) -> Unit,
  raw : @framework.CommandCtx,
) -> Unit {
  match self.routes {
    None =>
      dispatch_command_handler(
        self.definition.name,
        self.decode,
        self.handler,
        bot,
        waiter,
        warn,
        raw,
      )
    Some(routes) => {
      let path = raw.options.path()
      let key = path_key(path)
      for route in routes {
        if path_key(route.path) == key {
          (route.dispatch)(bot, waiter, warn, raw)
          return
        }
      }
      raise_failure(
        self.definition.name,
        BeforeInitial,
        HandlerError::InvalidArgument(
          "unknown subcommand path: \{if path.is_empty() { "<empty>" } else { path.join("/") }}",
        ),
      )
    }
  }
}

///|
/// A type-erased command consumed by the bot runtime.
pub struct RegisteredCommand {
  priv name_ : String
  priv definition : @interaction.CommandSpec
  priv node_paths_ : Array[Array[String]]
  priv nested_group_paths_ : Array[Array[String]]
  priv dispatch : async (
    BotCtx,
    ComponentWaiter?,
    (String) -> Unit,
    @framework.CommandCtx,
  ) -> Unit
}

///|
/// The top-level command name used for routing.
pub fn RegisteredCommand::name(self : RegisteredCommand) -> String {
  self.name_
}

///|
/// Erase the decoded argument type while retaining registration and dispatch.
pub fn[A] Command::erase(self : Command[A]) -> RegisteredCommand {
  {
    name_: self.definition.name,
    definition: self.definition,
    node_paths_: self.node_paths,
    nested_group_paths_: self.nested_group_paths,
    dispatch: (bot, waiter, warn, raw) => {
      self.dispatch_typed(bot, waiter, warn, raw)
    },
  }
}
