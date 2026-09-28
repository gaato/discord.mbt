///|
/// Something the App or its executor handled on its own but an operator should
/// know about. Delivered to `AppBuilder::on_warn`; without a hook the App
/// prints it. `Show` renders a one-line message for every variant, so a hook
/// that only logs can call `to_string()`.
pub(all) enum AppWarning {
  /// The watchdog tried to defer a slow deferring route and the defer failed.
  AutoDeferFailed(target~ : String, error~ : Error)
  /// An immediate or raw route found no handler capacity before its response
  /// deadline, so the interaction was not answered.
  InteractionDropped(target~ : String)
  /// An error policy tried to respond to a failure that has no interaction
  /// (an event or a service). `summary` describes the discarded response.
  ErrorResponseWithoutInteraction(summary~ : String)
  /// An error policy tried to respond after the interaction's window closed.
  ErrorResponseExpired(summary~ : String)
  /// The default policy met `HandlerError::Malformed`; `reason` is for logs.
  MalformedInteraction(origin~ : FailureOrigin, reason~ : String)
  /// The default policy met an error it does not render for users.
  UnhandledFailure(origin~ : FailureOrigin, error~ : Error)
  /// The error policy itself raised.
  ErrorPolicyFailed(error~ : Error)
  /// An autocomplete handler returned more than Discord's 25 choices; the
  /// first 25 were sent.
  AutocompleteTruncated(command_path~ : String, option~ : String, count~ : Int)
  /// A handler registered directly on the framework raised.
  HandlerFailed(target~ : String, error~ : Error)
  /// `wait_for_component` ran on an executor without a gateway connection.
  WaiterUnavailable
  /// The executor could not process an interaction at all.
  InteractionProcessingFailed(error~ : Error)
  /// A warning raised by an executor about its own transport (for example the
  /// gateway `Bot`), identified by `source`.
  Executor(source~ : String, message~ : String)
} derive(Debug)

///|
/// The one-line message, as the default hook prints it.
pub extend AppWarning with Show::{to_string}

///|
pub impl Show for AppWarning with fn output(self, logger) {
  match self {
    AutoDeferFailed(target~, error~) =>
      logger.write_string("automatic defer failed (\{target}): \{Repr(error)}")
    InteractionDropped(target~) =>
      logger.write_string(
        "interaction dropped (\{target}): no handler capacity before the response deadline",
      )
    ErrorResponseWithoutInteraction(summary~) =>
      logger.write_string(
        "cannot respond to a non-interaction failure: \{summary}",
      )
    ErrorResponseExpired(summary~) =>
      logger.write_string(
        "cannot respond to an expired interaction: \{summary}",
      )
    MalformedInteraction(origin~, reason~) =>
      logger.write_string("malformed interaction (\{Repr(origin)}): \{reason}")
    UnhandledFailure(origin~, error~) =>
      logger.write_string(
        "unhandled app failure (\{Repr(origin)}): \{Repr(error)}",
      )
    ErrorPolicyFailed(error~) =>
      logger.write_string("error policy failed: \{Repr(error)}")
    AutocompleteTruncated(command_path~, option~, count~) =>
      logger.write_string(
        "autocomplete choices truncated for command path \{command_path}, option \{option}: \{count} choices exceeds the limit of 25",
      )
    HandlerFailed(target~, error~) =>
      logger.write_string(
        "framework handler failed (\{target}): \{Repr(error)}",
      )
    WaiterUnavailable =>
      logger.write_string(
        "component waiting is unavailable without a gateway connection",
      )
    InteractionProcessingFailed(error~) =>
      logger.write_string("interaction processing failed: \{Repr(error)}")
    Executor(message~, ..) => logger.write_string(message)
  }
}
