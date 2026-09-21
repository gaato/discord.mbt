///|
/// Raises `Validation` for the first embed or component value outside a limit
/// Discord documents, which would otherwise come back as 400 Invalid Form Body.
fn validate_message_limits(
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
) -> Unit raise DiscordHttpError {
  if embeds is Some(embeds) &&
    @model.embed_limit_violations(embeds) is [violation, ..] {
    raise Validation(message=violation.message())
  }
  if components is Some(components) &&
    @model.message_component_limit_violations(components) is [violation, ..] {
    raise Validation(message=violation.message())
  }
}

///|
/// Raises `Validation` for the first value of a modal outside a limit Discord
/// documents. Hidden from the public interface; framework shares this helper.
#doc(hidden)
pub fn validate_modal_limits(
  title : String,
  components : Array[@model.Component],
) -> Unit raise DiscordHttpError {
  if @model.modal_limit_violations(title~, components~) is [violation, ..] {
    raise Validation(message=violation.message())
  }
}

///|
/// Validate the embeds and components of an outgoing message against
/// Discord's documented limits, validate Components V2-exclusive fields, and
/// add the required message flag. Every message-shaped body is built through
/// this helper, so it is the one place the limits are enforced.
/// Hidden from the public interface; framework and app share this wire helper.
#doc(hidden)
pub fn message_flags_with_components_v2(
  flags : @model.MessageFlags?,
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  sticker_ids? : Array[@model.StickerId],
  poll? : @model.Poll,
) -> @model.MessageFlags? raise DiscordHttpError {
  validate_message_limits(embeds, components)
  guard components is Some(values) && @model.requires_components_v2(values) else {
    return flags
  }
  if content is Some(_) ||
    (embeds is Some(values) && values.length() > 0) ||
    (sticker_ids is Some(values) && values.length() > 0) ||
    poll is Some(_) {
    raise Validation(
      message="Components V2 cannot be combined with content, embeds, sticker_ids, or poll",
    )
  }
  Some(
    flags.unwrap_or(@model.MessageFlags::none()) |
    @model.MessageFlags::is_components_v2(),
  )
}
