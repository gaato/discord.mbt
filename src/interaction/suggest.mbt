///|
/// Data available while producing autocomplete choices. This context is
/// transport-neutral and intentionally does not own an HTTP client.
pub(all) struct SuggestCtx {
  interaction : @model.Interaction
  options : CommandOptions
  guild_id : @model.GuildId?
  locale : String?
}

///|
/// The raw focused option passed to a type-erased suggestion handler.
pub struct SuggestInput {
  priv name_ : String
  priv value_ : Json
}

///|
/// The name of the focused option.
pub fn SuggestInput::name(self : SuggestInput) -> String {
  self.name_
}

///|
/// A type-erased autocomplete handler retained by `Args`.
pub struct SuggestHandler {
  priv name_ : String
  priv run_ : async (SuggestCtx, SuggestInput) -> Array[
    @model.CommandOptionChoice,
  ]
}

///|
/// The option name served by this handler.
pub fn SuggestHandler::name(self : SuggestHandler) -> String {
  self.name_
}

///|
/// Produce choices from a focused raw input.
pub async fn SuggestHandler::suggest(
  self : SuggestHandler,
  ctx : SuggestCtx,
  input : SuggestInput,
) -> Array[@model.CommandOptionChoice] {
  (self.run_)(ctx, input)
}
