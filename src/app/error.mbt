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
  InvalidArgument(String)
} derive(Debug)

///|
/// A command dispatch failure with its response phase and original cause.
pub(all) suberror AppDispatchError {
  Failure(command~ : String, phase~ : ResponsePhase, source~ : Error)
} derive(Debug)
