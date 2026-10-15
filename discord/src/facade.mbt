///|
/// Golden-path names that a typical bot uses directly: application
/// declarations and handler contexts, typed arguments and components, common
/// models, the REST client, executors, verification, and voice. Every type
/// these names mention is exported here too, unless it belongs to one of the
/// focused packages below; `scripts/api_surface_audit.mbtx` keeps it so.
///
/// Not re-exported — import the focused package instead:
/// - `gaato/discord/http` for resource refs and pagination.
/// - `gaato/discord/framework` for the low-level router and the raw contexts
///   used by `Raw` handlers.
/// - `gaato/discord/gateway` for shard transport primitives.
/// - `gaato/discord/coordinator` for multi-process coordination.
/// - `gaato/discord/telemetry` for observability events.
/// - `gaato/discord/interaction` for raw option builders, `CommandSpec`, and
///   low-level option decoding.
/// - `gaato/discord/app` for implementation-facing registration, spawning,
///   waiting, and raw failure details.
pub using @dhttp {
  type Client,
  type FileUpload,
  type DiscordHttpError,
  type MessageRef,
  type ChannelRef,
  type GuildRef,
  type MemberRef,
  type UserRef,
  type ApplicationRef,
}

///|
/// Invocation and response types every handler context hands out, and the
/// unanswered `ComponentCtx` a component wait returns.
pub using @framework {
  type ComponentCtx,
  type GuildInvocation,
  type InvocationScope,
  type ModalOrigin,
  type ResponseState,
  type TargetUser,
}

///|
pub using @cache {
  type InMemoryCache,
  type CacheResources,
  type CacheLimits,
  type CacheLimit,
}

///|
pub using @model {
  type Intents,
  type GatewayCapabilities,
  type Event,
  type AllowedMentions,
  type AllowedMentionType,
  type AllowedMentionsError,
}

///|
pub using @interaction {type Arg, type Args, type SuggestCtx}

///|
/// Gateway-free application declarations (built with `AppBuilder`), typed
/// interaction handlers, command synchronization, and error policy contexts.
pub using @app {
  type App,
  type AppBuilder,
  type AppWarning,
  type AppCtx,
  type InteractionEndpoint,
  type InteractionCtx,
  type InteractionTarget,
  type SyncReport,
  type RestAccess,
  type InteractionOutcome,
  type InteractionHttpRequest,
  type InteractionHttpBody,
  type InteractionHttpResponse,
  type WaitFrom,
  type Command,
  type CheckCtx,
  type CommandCheck,
  type CooldownBucket,
  type InteractionHandler,
  type CommandReply,
  type ComponentReply,
  type ComponentHandler,
  type ComponentRoute,
  component_route,
  type CustomIdCodec,
  type CustomIdError,
  type ComponentImmediateCtx,
  type ComponentDeferredCtx,
  type InitialResponse,
  type MessageUpdate,
  type ModalReply,
  type ModalShowError,
  type ModalField,
  type ModalFields,
  type Modal,
  type ModalHandle,
  type ModalSubmitHandler,
  type ModalImmediateCtx,
  type ModalDeferredCtx,
  type SlashChild,
  type ImmediateCtx,
  type DeferredCtx,
  type CommandScope,
  type AppConfigError,
  type HandlerError,
  type ErrorPolicy,
  type FailureCtx,
  type FailureOrigin,
  slash,
  user_command,
  message_command,
  subcommand,
  subcommand_group,
  slash_group,
  text_field,
  select_field,
  file_field,
  modal,
  guild_only,
  dm_only,
  required_permissions,
}

///|
/// Pure MoonBit verification for Discord HTTP interaction signatures.
pub using @verify {
  type InteractionVerifier,
  type InteractionVerifierError,
  verify_signature,
}

///|
/// Typed option constructors and combinators. Re-exporting these values keeps
/// command definitions on the facade while `interaction` remains their owner.
pub using @interaction {
  arg_string,
  arg_int,
  arg_int32,
  arg_number,
  arg_bool,
  arg_user,
  arg_channel,
  arg_role,
  arg_mentionable,
  arg_attachment,
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
  file_upload,
}
