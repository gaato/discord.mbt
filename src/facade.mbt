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
/// Gateway-free application declarations, typed interaction handlers, command
/// synchronization, and error policy contexts.
pub using @app {
  type App,
  type AppCtx,
  type InteractionEndpoint,
  type InteractionOutcome,
  type Spawner,
  type ComponentWaiter,
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
  type CommandSync,
  type AppConfigError,
  type HandlerError,
  type ErrorPolicy,
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
/// Native gateway executor and typed event descriptors.
pub using @bot {
  type Bot,
  type GatewayCtx,
  type EventType,
  type Events,
  type BotError,
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
  string_option,
  integer_option,
  number_option,
  boolean_option,
  user_option,
  channel_option,
  role_option,
  mentionable_option,
  attachment_option,
  sub_command,
  sub_command_group,
  string_choice,
  int_choice,
  number_choice,
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
