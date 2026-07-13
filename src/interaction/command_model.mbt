///|
/// A typed view of one command invocation, decoded from its submitted
/// options.
///
/// Implement this by hand per command (MoonBit has no derive macro for it):
///
/// ```mbt nocheck
/// struct Echo {
///   text : String
///   times : Int64?
/// }
///
/// impl @interaction.CommandModel for Echo with fn from_options(options) {
///   { text: options.string("text"), times: options.int_opt("times") }
/// }
/// ```
///
/// Commands with subcommands are naturally modeled as an enum whose
/// `from_options` matches on `options.path()`.
pub(open) trait CommandModel {
  fn from_options(CommandOptions) -> Self raise
}
