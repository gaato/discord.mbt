///|
/// Expected command failures that an error policy can present to the user.
///
/// Raise these from handlers, checks, or app middleware; the application's
/// `ErrorPolicy` turns them into user-facing responses. A permission guard
/// computed with `@util.channel_permissions` typically raises
/// `MissingPermission`:
///
/// ```mbt check
/// test "guard a handler with a permission requirement" {
///   fn require_send_messages(permissions : @model.Permissions) -> Unit raise {
///     let required = @model.Permissions::send_messages()
///     if !permissions.contains(required) {
///       raise @app.HandlerError::MissingPermission(required)
///     }
///   }
///
///   try require_send_messages(@model.Permissions::none()) catch {
///     @app.HandlerError::MissingPermission(_) => ()
///     other => raise other
///   } noraise {
///     _ => fail("expected MissingPermission")
///   }
/// }
/// ```
pub(all) suberror HandlerError {
  UserMessage(message~ : String, ephemeral~ : Bool)
  GuildOnly
  DmOnly
  CheckFailed
  MissingPermission(@model.Permissions)
  OnCooldown(retry_after_ms~ : Int64)
  /// A submitted value the user can correct, such as an argument outside its
  /// declared range. `message` is shown to the user; `name` identifies the
  /// option when there is one.
  InvalidInput(name~ : String?, message~ : String)
  /// The interaction does not match what the app declared: typically a stale
  /// command registration, an old component, or a payload missing data
  /// Discord should have sent. `reason` is for logs and never shown to users.
  Malformed(reason~ : String)
  /// The handler chose a response Discord does not accept for this
  /// interaction, such as updating the message of a modal a command opened.
  /// It is an app bug, not a user error: `reason` is for logs, and the default
  /// policy tells the user only that something went wrong.
  UnsupportedResponse(reason~ : String)
} derive(Debug)

///|
/// Keep a `HandlerError` raised by user code as is, and classify any other
/// decode failure as a malformed interaction.
fn malformed_unless_handler_error(error : Error) -> HandlerError {
  match error {
    UserMessage(..) as error => error
    GuildOnly => GuildOnly
    DmOnly => DmOnly
    CheckFailed => CheckFailed
    MissingPermission(_) as error => error
    OnCooldown(..) as error => error
    InvalidInput(..) as error => error
    Malformed(..) as error => error
    UnsupportedResponse(..) as error => error
    error => Malformed(reason=Repr(error).to_string())
  }
}
