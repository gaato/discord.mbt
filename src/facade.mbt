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
  type SuggestCtx,
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
  type GatewayCtx,
  type InteractionApp,
  type InteractionOutcome,
  type Command,
  type RegisteredCommand,
  type InteractionHandler,
  type CommandReply,
  type ComponentReply,
  type ComponentHandler,
  type ComponentImmediateCtx,
  type ComponentDeferredCtx,
  type InitialResponse,
  type ModalField,
  type ModalFields,
  type Modal,
  type ModalHandle,
  type ModalSubmitHandler,
  type ModalImmediateCtx,
  type ModalDeferredCtx,
  type TargetUser,
  type SlashChild,
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
  user_command,
  message_command,
  subcommand,
  subcommand_group,
  slash_group,
  text_field,
  select_field,
  modal,
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
  action_row,
  button,
  link_button,
  string_select,
  select_option,
  user_select,
  role_select,
  mentionable_select,
  channel_select,
  text_display,
  section,
  thumbnail,
  container,
  separator,
  media_gallery,
  media_item,
  label,
  text_input,
}
