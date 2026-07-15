///|
/// Validate Components V2-exclusive fields and add the required message flag.
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
