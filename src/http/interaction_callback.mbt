///|
/// The `data` object of a message-bearing interaction callback
/// (`CHANNEL_MESSAGE_WITH_SOURCE`, `UPDATE_MESSAGE`, and the deferred message
/// acknowledgement). Every callback message is built here so it gets the same
/// limits, Components V2 flag, and attachment handling as the REST edit and
/// create paths.
///
/// `clear_content` sends `content: null`; it only means something for
/// `UPDATE_MESSAGE`, which otherwise leaves omitted fields unchanged.
/// `keep_attachments` lists the existing attachments an update retains,
/// merged with the new `files` exactly as a REST edit merges them.
/// Hidden from the public interface; framework and app share this wire helper.
#doc(hidden)
pub fn interaction_message_data(
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Json raise DiscordHttpError {
  let flags = if ephemeral {
    Some(@model.MessageFlags::ephemeral())
  } else {
    None
  }
  edit_attachments_field(
    message_patch_builder(
      content,
      clear_content,
      embeds,
      components,
      flags,
      has_poll=poll is Some(_),
    )
    .opt("allowed_mentions", allowed_mentions)
    .opt("poll", poll),
    keep_attachments,
    files,
  ).build()
}
