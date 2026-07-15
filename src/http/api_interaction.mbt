///|
/// Send the initial response to an interaction. When uploading `files`,
/// include a matching `attachments` array in `response.data` yourself if
/// you need descriptions or ordering (the framework layer does this).
pub async fn Client::create_interaction_response(
  self : Client,
  interaction_id : @model.InteractionId,
  token : String,
  response : @model.InteractionResponse,
  files? : Array[FileUpload],
) -> Unit raise DiscordHttpError {
  self.request(
    CreateInteractionResponse(interaction_id~, token~),
    body=response.to_json(),
    files?,
  )
  |> ignore
}

///|
/// Fetch the original response for an interaction.
pub async fn Client::get_original_response(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
) -> @model.Message raise DiscordHttpError {
  decode(self.request(GetOriginalInteractionResponse(application_id~, token~)))
}

///|
/// Edit the original response for an interaction. When `files` is given,
/// the response's attachments are replaced by the uploaded files.
pub async fn Client::edit_original_response(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  let builder = message_patch_builder(
    content,
    clear_content,
    embeds,
    components,
    None,
  ).opt("allowed_mentions", allowed_mentions)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      EditOriginalInteractionResponse(application_id~, token~),
      body=builder.build(),
      files?,
    ),
  )
}

///|
/// Delete the original response for an interaction.
pub async fn Client::delete_original_response(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
) -> Unit raise DiscordHttpError {
  self.request(DeleteOriginalInteractionResponse(application_id~, token~))
  |> ignore
}

///|
/// Create a followup message for an interaction.
pub async fn Client::create_followup(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[FileUpload],
  flags? : @model.MessageFlags,
  allowed_mentions? : @model.AllowedMentions,
) -> @model.Message raise DiscordHttpError {
  if content is Some(value) && value.length() > 4000 {
    raise Validation(message="content exceeds 4000 UTF-16 units")
  }
  if content is None && embeds is None && components is None && files is None {
    raise Validation(
      message="one of content/embeds/components/files is required",
    )
  }
  let flags = message_flags_with_components_v2(
    flags, content, embeds, components,
  )
  let builder = @model.ObjBuilder()
    .opt("content", content)
    .opt("embeds", embeds)
    .opt("components", components)
    .opt("flags", flags)
    .opt("allowed_mentions", allowed_mentions)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      CreateFollowupMessage(application_id~, token~),
      body=builder.build(),
      files?,
    ),
  )
}

///|
/// Fetch a followup message for an interaction.
pub async fn Client::get_followup(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
  message_id : @model.MessageId,
) -> @model.Message raise DiscordHttpError {
  decode(self.request(GetFollowupMessage(application_id~, token~, message_id~)))
}

///|
/// Edit a followup message for an interaction. When `files` is given, the
/// followup's attachments are replaced by the uploaded files.
pub async fn Client::edit_followup(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
  message_id : @model.MessageId,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  let builder = message_patch_builder(
    content,
    clear_content,
    embeds,
    components,
    None,
  ).opt("allowed_mentions", allowed_mentions)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      EditFollowupMessage(application_id~, token~, message_id~),
      body=builder.build(),
      files?,
    ),
  )
}

///|
/// Delete a followup message for an interaction.
pub async fn Client::delete_followup(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
  message_id : @model.MessageId,
) -> Unit raise DiscordHttpError {
  self.request(DeleteFollowupMessage(application_id~, token~, message_id~))
  |> ignore
}
