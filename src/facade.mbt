///|
/// Convenience aliases for the types a typical bot names directly, so the
/// core loop can be written against `@discord` alone. Everything else —
/// entity models, REST wrappers, gateway internals, option builders —
/// lives in the focused packages: `@discord/model`, `@discord/http`,
/// `@discord/gateway`, `@discord/interaction`, `@discord/framework`.
pub using @dhttp {type Client, type FileUpload}

///|
pub using @model {type Intents, type Event}

///|
pub using @gateway {type Shard, type ShardEvent}

///|
pub using @interaction {
  type Arg,
  type Args,
  type ArgsDecodeError,
  type CommandSpec,
  type CommandOptions,
  trait CommandModel,
}

///|
pub using @framework {
  type Framework,
  type CommandCtx,
  type ComponentCtx,
  type ModalCtx,
  type AutocompleteCtx,
}

///|
/// High-level bot runtime, typed commands, event descriptors, and error policy
/// contexts. Their implementations remain owned by the focused `bot` package.
pub using @bot {
  type Bot,
  type BotCtx,
  type Command,
  type RegisteredCommand,
  type InteractionHandler,
  type InitialResponse,
  type ImmediateCtx,
  type DeferredCtx,
  type EventType,
  type Events,
  type CommandSync,
  type BotError,
  type BotConfigError,
  type HandlerError,
  type FailureCtx,
  type FailureOrigin,
  type ResponsePhase,
  slash,
}

///|
/// Typed option constructors and combinators. Re-exporting these values keeps
/// command definitions on the facade while `interaction` remains their owner.
pub using @interaction {
  arg_string,
  arg_int,
  arg_number,
  arg_bool,
  arg_user,
  arg_channel,
  arg_role,
  arg_mentionable,
  arg_attachment,
  optional,
  default,
  validate,
}
