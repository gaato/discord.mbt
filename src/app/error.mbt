///|
/// Expected command failures that an error policy can present to the user.
pub(all) suberror HandlerError {
  UserMessage(message~ : String, ephemeral~ : Bool)
  GuildOnly
  MissingPermission(@model.Permissions)
  InvalidArgument(String)
} derive(Debug)

///|
/// A command dispatch failure with its response phase and original cause.
pub(all) suberror AppDispatchError {
  Failure(command~ : String, phase~ : ResponsePhase, source~ : Error)
} derive(Debug)
