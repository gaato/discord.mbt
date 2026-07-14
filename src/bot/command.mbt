///|
/// Execution strategy for a typed application command.
pub(all) enum InteractionHandler[A] {
  Immediate(async (ImmediateCtx, A) -> InitialResponse)
  Deferred(ephemeral~ : Bool, async (DeferredCtx, A) -> Unit)
  Raw(async (@framework.CommandCtx) -> Unit)
}

///|
/// A slash-command definition whose registration options and decoder share
/// the same typed `Args` value.
pub struct Command[A] {
  priv name : String
  priv description : String
  priv args : @interaction.Args[A]
  priv handler : InteractionHandler[A]
}

///|
/// Define a typed slash command.
pub fn[A] slash(
  name~ : String,
  description~ : String,
  args~ : @interaction.Args[A],
  handler~ : InteractionHandler[A],
) -> Command[A] {
  { name, description, args, handler }
}

///|
/// The command registration specification derived from the typed arguments.
pub fn[A] Command::spec(self : Command[A]) -> @interaction.CommandSpec {
  @interaction.CommandSpec::slash(
    self.name,
    self.description,
    options=self.args.definitions(),
  )
}

///|
/// Decode command arguments and translate reader errors into a stable handler
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
fn[A] raise_failure(
  command : String,
  phase : ResponsePhase,
  source : Error,
) -> A raise BotDispatchError {
  raise Failure(command~, phase~, source~)
}

///|
async fn[A] Command::dispatch_typed(
  self : Command[A],
  bot : BotCtx,
  waiter : ComponentWaiter?,
  warn : (String) -> Unit,
  raw : @framework.CommandCtx,
) -> Unit {
  let value = decode_command_args(self.args, raw.options) catch {
    source => raise_failure(self.name, BeforeInitial, source)
  }
  match self.handler {
    Immediate(handler) => {
      let response = handler({ raw_: raw, bot_: bot }, value) catch {
        source => raise_failure(self.name, BeforeInitial, source)
      }
      response.send(raw) catch {
        source => raise_failure(self.name, BeforeInitial, source)
      }
    }
    Deferred(ephemeral~, handler) => {
      raw.defer_response(ephemeral~) catch {
        source => raise_failure(self.name, BeforeInitial, source)
      }
      handler({ raw_: raw, bot_: bot, waiter_: waiter, warn_: warn }, value) catch {
        source => raise_failure(self.name, AfterDeferred, source)
      }
    }
    Raw(handler) =>
      handler(raw) catch {
        source => raise_failure(self.name, BeforeInitial, source)
      }
  }
}

///|
/// A type-erased command consumed by the bot runtime.
pub struct RegisteredCommand {
  priv name_ : String
  priv definition : @interaction.CommandSpec
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
    name_: self.name,
    definition: self.spec(),
    dispatch: (bot, waiter, warn, raw) => {
      self.dispatch_typed(bot, waiter, warn, raw)
    },
  }
}
