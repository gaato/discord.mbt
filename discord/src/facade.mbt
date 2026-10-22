///|
// Golden-path names that a typical bot uses directly: application
// declarations and handler contexts, typed arguments and components, common
// models, the REST client, executors, and verification. Every type
// these names mention is exported here too, unless it belongs to one of the
// focused packages below; `scripts/api_surface_audit.mbtx` keeps it so.
//
// Not re-exported — import the focused package instead:
// - `gaato/discord/http` for resource refs and pagination.
// - `gaato/discord/framework` for the low-level router and the raw contexts
//   used by `Raw` handlers.
// - `gaato/discord/gateway` for shard transport primitives.
// - `gaato/discord/coordinator` for multi-process coordination.
// - `gaato/discord/telemetry` for observability events.
// - `gaato/discord/interaction` for raw option builders, `CommandSpec`, and
//   low-level option decoding.
// - `gaato/discord/app` for implementation-facing registration, spawning,
//   waiting, and raw failure details.

///|
/// Discord REST client: token + HTTP transport + rate limiter.
pub using @dhttp {type Client}

///|
/// One file to upload in a `multipart/form-data` request, next to the
/// `payload_json` part.
pub using @dhttp {type FileUpload}

///|
/// Everything a REST call can raise, from client-side validation to decoded
/// Discord API errors.
pub using @dhttp {type DiscordHttpError}

///|
/// A message id and its channel id bound to the REST client that operates on
/// it.
pub using @dhttp {type MessageRef}

///|
/// A channel id bound to the REST client that operates on it.
pub using @dhttp {type ChannelRef}

///|
/// A guild id bound to the REST client that operates on it.
pub using @dhttp {type GuildRef}

///|
/// A guild member identity bound to the REST client that operates on it.
pub using @dhttp {type MemberRef}

///|
/// A user id bound to the REST client that operates on it.
pub using @dhttp {type UserRef}

///|
/// An application id bound to the REST client that operates on it.
pub using @dhttp {type ApplicationRef}

///|
// Invocation and response types every handler context hands out, and the
// unanswered `ComponentCtx` a component wait returns.

///|
/// Context handed to a message-component (button / select) handler.
pub using @framework {type ComponentCtx}

///|
/// Proof that an interaction was invoked in a guild: the guild id and the
/// invoking member, both validated when the context was built.
pub using @framework {type GuildInvocation}

///|
/// The context in which an interaction was invoked.
pub using @framework {type InvocationScope}

///|
/// The interaction that opened a submitted modal.
pub using @framework {type ModalOrigin}

///|
/// What has happened to an interaction's single initial callback.
pub using @framework {type ResponseState}

///|
/// The resolved target of a USER context-menu command.
pub using @framework {type TargetUser}

///|
/// A gateway-driven, resource-selective in-memory cache.
pub using @cache {type InMemoryCache}

///|
/// Selects which gateway resources an in-memory cache retains.
pub using @cache {type CacheResources}

///|
/// Per-resource bounds for an in-memory cache.
pub using @cache {type CacheLimits}

///|
/// Bounds one cached resource by entry count, lifetime, or both.
pub using @cache {type CacheLimit}

///|
/// Gateway intents: the server-side event subscription bitfield sent in
/// Identify.
pub using @model {type Intents}

///|
/// Gateway capabilities: the Identify bitfield that opts a client into gateway
/// behaviors (as opposed to `Intents`, which select events).
pub using @model {type GatewayCapabilities}

///|
/// A gateway dispatch event decoded by its wire event name.
pub using @model {type Event}

///|
/// Controls which mentions Discord resolves and notifies for an outgoing
/// message.
pub using @model {type AllowedMentions}

///|
/// A mention category Discord may derive directly from message content.
pub using @model {type AllowedMentionType}

///|
/// An invalid allowed-mentions configuration rejected during construction.
pub using @model {type AllowedMentionsError}

///|
/// One typed command option, combining its registration definition and reader.
pub using @interaction {type Arg}

///|
/// A typed collection of command options used for registration and decoding.
pub using @interaction {type Args}

///|
/// Data available while producing autocomplete choices.
pub using @interaction {type SuggestCtx}

///|
// Gateway-free application declarations (built with `AppBuilder`), typed
// interaction handlers, command synchronization, and error policy contexts.

///|
/// Validated, immutable application declarations shared by gateway and HTTP
/// executors.
pub using @app {type App}

///|
/// Collects application declarations: commands, component and modal routes,
/// autocomplete handlers, middleware, and failure hooks.
pub using @app {type AppBuilder}

///|
/// Something the App or its executor handled on its own but an operator should
/// know about.
pub using @app {type AppWarning}

///|
/// Whether a command with a cooldown runs while the cooldown store cannot
/// answer.
pub using @app {type CooldownOutage}

///|
/// Transport-neutral services available to interaction handlers.
pub using @app {type AppCtx}

///|
/// Whether an executor still starts handlers.
pub using @app {type HandlerIntake}

///|
/// A gateway-free interaction dispatcher backed by a caller-owned task group.
pub using @app {type InteractionEndpoint}

///|
/// Read-only context handed to interaction middleware, before any initial
/// response has been sent.
pub using @app {type InteractionCtx}

///|
/// The routed target of an interaction entering the middleware chain.
pub using @app {type InteractionTarget}

///|
/// Reports for each synchronized scope, in the requested order.
pub using @app {type SyncReport}

///|
/// Planned synchronizations for each requested scope, in order.
pub using @app {type CommandPlan}

///|
/// How an executor reaches Discord's REST API: with a bot token, from which it
/// builds and owns a client, or through an existing client the caller owns.
pub using @app {type RestAccess}

///|
/// The result of dispatching one HTTP-delivered interaction.
pub using @app {type InteractionOutcome}

///|
/// The exact bytes received from an HTTP host.
pub using @app {type InteractionHttpRequest}

///|
/// The body of an interaction HTTP response: empty, bytes, or multipart
/// chunks.
pub using @app {type InteractionHttpBody}

///|
/// A host-independent HTTP response for a Discord interaction.
pub using @app {type InteractionHttpResponse}

///|
/// Who may satisfy a component wait.
pub using @app {type WaitFrom}

///|
/// An application-command definition with a context-aware decoder.
pub using @app {type Command}

///|
/// Read-only context passed to command checks before argument decoding and
/// handler execution.
pub using @app {type CheckCtx}

///|
/// A command guard run before argument decoding; returning false rejects the
/// invocation with `HandlerError::CheckFailed`.
pub using @app {type CommandCheck}

///|
/// Identity used to share a fixed-window command cooldown.
pub using @app {type CooldownBucket}

///|
/// Execution strategy for a typed application command.
pub using @app {type InteractionHandler}

///|
/// An initial response returned by an immediate command handler.
pub using @app {type CommandReply}

///|
/// Initial response returned by an immediate component handler.
pub using @app {type ComponentReply}

///|
/// Execution strategy for a component route.
pub using @app {type ComponentHandler}

///|
/// A component's route identity and the codec shared by producer and handler.
pub using @app {type ComponentRoute}

///|
/// Define a component route matching `id` or `id:state`.
pub using @app {component_route}

///|
/// A reversible text encoding for the state carried in a custom id.
pub using @app {type CustomIdCodec}

///|
/// A custom id that exceeds Discord's limit or cannot round-trip its segments.
pub using @app {type CustomIdError}

///|
/// Read-only component context for handlers returning their initial callback.
pub using @app {type ComponentImmediateCtx}

///|
/// Component context available after a deferred callback.
pub using @app {type ComponentDeferredCtx}

///|
/// A declarative initial message response returned by an immediate handler.
pub using @app {type InitialResponse}

///|
/// An `UPDATE_MESSAGE` callback: edits the message that hosts the component
/// (or, for a modal, the message whose component opened it).
pub using @app {type MessageUpdate}

///|
/// Initial response returned by an immediate modal handler.
pub using @app {type ModalReply}

///|
/// Why `Modal::show` could not prepare a modal response.
pub using @app {type ModalShowError}

///|
/// One typed input in a modal form.
pub using @app {type ModalField}

///|
/// A composable collection of typed modal inputs.
pub using @app {type ModalFields}

///|
/// A typed modal definition: a route id with typed state, and typed fields.
pub using @app {type Modal}

///|
/// A type-erased modal response ready to be returned by a command or component
/// handler.
pub using @app {type ModalHandle}

///|
/// Execution strategy for a typed modal submission.
pub using @app {type ModalSubmitHandler}

///|
/// Read-only modal-submit context for handlers returning an initial message.
pub using @app {type ModalImmediateCtx}

///|
/// Modal-submit context available after a deferred response.
pub using @app {type ModalDeferredCtx}

///|
/// A type-erased slash subcommand or subcommand group.
pub using @app {type SlashChild}

///|
/// Read-only command context for handlers that return their initial response.
pub using @app {type ImmediateCtx}

///|
/// Command context made available after the initial deferred response.
pub using @app {type DeferredCtx}

///|
/// Which command scope a synchronization targets.
pub using @app {type CommandScope}

///|
/// Configuration errors detected before starting an application executor.
pub using @app {type AppConfigError}

///|
/// Expected command failures that an error policy can present to the user.
pub using @app {type HandlerError}

///|
/// Policy invoked for interaction, event, and service failures.
pub using @app {type ErrorPolicy}

///|
/// Context handed to the error policy when a handler fails.
pub using @app {type FailureCtx}

///|
/// The operation whose handler failed.
pub using @app {type FailureOrigin}

///|
/// Define a typed slash command.
pub using @app {slash}

///|
/// Define a USER context-menu command.
pub using @app {user_command}

///|
/// Define a MESSAGE context-menu command.
pub using @app {message_command}

///|
/// Define a typed slash subcommand.
pub using @app {subcommand}

///|
/// Define a slash subcommand group.
pub using @app {subcommand_group}

///|
/// Define a slash command whose children dispatch by submitted option path.
pub using @app {slash_group}

///|
/// Define a modern label-wrapped text input.
pub using @app {text_field}

///|
/// Define a modern label-wrapped string select.
pub using @app {select_field}

///|
/// Define a modern label-wrapped file upload.
pub using @app {file_field}

///|
/// Define a typed modal.
pub using @app {modal}

///|
/// Require a guild invocation.
pub using @app {guild_only}

///|
/// Require a direct-message invocation.
pub using @app {dm_only}

///|
/// Require effective guild permissions supplied on the interaction member.
pub using @app {required_permissions}

///|
// Pure MoonBit verification for Discord HTTP interaction signatures.

///|
/// A validated and expanded Discord interaction public key.
pub using @verify {type InteractionVerifier}

///|
/// Errors raised while constructing a reusable Discord interaction verifier.
pub using @verify {type InteractionVerifierError}

///|
/// Verify a Discord HTTP interaction signature without retaining the key.
pub using @verify {verify_signature}

///|
// Typed option constructors and combinators. Re-exporting these values keeps
// command definitions on the facade while `interaction` remains their owner.

///|
/// Define a required string option.
pub using @interaction {arg_string}

///|
/// Define a required integer option.
pub using @interaction {arg_int}

///|
/// Define a required integer option that decodes to `Int`.
pub using @interaction {arg_int32}

///|
/// Define a required floating-point number option.
pub using @interaction {arg_number}

///|
/// Define a required boolean option.
pub using @interaction {arg_bool}

///|
/// Define a required user option.
pub using @interaction {arg_user}

///|
/// Define a required channel option.
pub using @interaction {arg_channel}

///|
/// Define a required role option.
pub using @interaction {arg_role}

///|
/// Define a required mentionable option.
pub using @interaction {arg_mentionable}

///|
/// Define a required attachment option resolved to its attachment object.
pub using @interaction {arg_attachment}

///|
/// Describe a string-valued option choice.
pub using @interaction {string_choice}

///|
/// Describe an integer-valued option choice.
pub using @interaction {int_choice}

///|
/// Describe a number-valued option choice.
pub using @interaction {number_choice}

///|
/// Build a message component row.
pub using @interaction {action_row}

///|
/// Build an interactive button.
pub using @interaction {button}

///|
/// Build a link button.
pub using @interaction {link_button}

///|
/// Build a string select menu.
pub using @interaction {string_select}

///|
/// Build an option for a string select menu.
pub using @interaction {select_option}

///|
/// Build a user select menu; the chosen users arrive in `resolved` and via the
/// component context's `selected_users`.
pub using @interaction {user_select}

///|
/// Build a role select menu; the chosen roles arrive via the component
/// context's `selected_roles`.
pub using @interaction {role_select}

///|
/// Build a mentionable select menu accepting both users and roles.
pub using @interaction {mentionable_select}

///|
/// Build a channel select menu, optionally restricted to `channel_types`; the
/// chosen channels arrive via the component context's `selected_channels`.
pub using @interaction {channel_select}

///|
/// Build a text display block (components v2): markdown `content` rendered in
/// the message body.
pub using @interaction {text_display}

///|
/// Build a section (components v2): up to three text displays laid out next to
/// an `accessory` (a thumbnail or button).
pub using @interaction {section}

///|
/// Build a thumbnail accessory (components v2) from an image `url`
/// (`https://...` or `attachment://<filename>`).
pub using @interaction {thumbnail}

///|
/// Build a container (components v2): groups child components in a rounded box
/// with an optional `accent_color` (`0xRRGGBB`) stripe, similar to an embed.
pub using @interaction {container}

///|
/// Build a separator (components v2): vertical padding between components, with
/// an optional visible `divider` line and `spacing` size (1 = small, 2 =
/// large).
pub using @interaction {separator}

///|
/// Build a media gallery (components v2): a grid of 1–10 media items.
pub using @interaction {media_gallery}

///|
/// Build one media gallery entry from an image or video `url` (`https://...` or
/// `attachment://<filename>`), for use with `media_gallery`.
pub using @interaction {media_item}

///|
/// Wrap a modal component with a `label` and optional `description`.
pub using @interaction {label}

///|
/// Build a modal text input.
pub using @interaction {text_input}

///|
/// Build a file upload input for a modal (wrap it in `label`).
pub using @interaction {file_upload}
