///|
/// Send the initial response to an interaction.
pub async fn Client::create_interaction_response(
  self : Client,
  interaction_id : @model.InteractionId,
  token : String,
  response : @model.InteractionResponse,
) -> Unit raise DiscordHttpError {
  self.request(
    Route::CreateInteractionResponse(interaction_id~, token~),
    body=response.to_json(),
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
  decode(
    self.request(Route::GetOriginalInteractionResponse(application_id~, token~)),
  )
}

///|
/// Edit the original response for an interaction.
pub async fn Client::edit_original_response(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
) -> @model.Message raise DiscordHttpError {
  if content is Value(value) && value.length() > 4000 {
    raise DiscordHttpError::Validation(
      message="content exceeds 4000 UTF-16 units",
    )
  }
  let body = @model.ObjBuilder::new()
    .und("content", content)
    .und("embeds", embeds)
    .und("components", components)
    .build()
  decode(
    self.request(
      Route::EditOriginalInteractionResponse(application_id~, token~),
      body~,
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
  self.request(
    Route::DeleteOriginalInteractionResponse(application_id~, token~),
  )
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
  flags? : @model.MessageFlags,
) -> @model.Message raise DiscordHttpError {
  if content is Some(value) && value.length() > 4000 {
    raise DiscordHttpError::Validation(
      message="content exceeds 4000 UTF-16 units",
    )
  }
  if content is None && embeds is None && components is None {
    raise DiscordHttpError::Validation(
      message="one of content/embeds/components is required",
    )
  }
  let body = @model.ObjBuilder::new()
    .opt("content", content)
    .opt("embeds", embeds)
    .opt("components", components)
    .opt("flags", flags)
    .build()
  decode(
    self.request(Route::CreateFollowupMessage(application_id~, token~), body~),
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
  decode(
    self.request(
      Route::GetFollowupMessage(application_id~, token~, message_id~),
    ),
  )
}

///|
/// Edit a followup message for an interaction.
pub async fn Client::edit_followup(
  self : Client,
  application_id : @model.ApplicationId,
  token : String,
  message_id : @model.MessageId,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
) -> @model.Message raise DiscordHttpError {
  if content is Value(value) && value.length() > 4000 {
    raise DiscordHttpError::Validation(
      message="content exceeds 4000 UTF-16 units",
    )
  }
  let body = @model.ObjBuilder::new()
    .und("content", content)
    .und("embeds", embeds)
    .und("components", components)
    .build()
  decode(
    self.request(
      Route::EditFollowupMessage(application_id~, token~, message_id~),
      body~,
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
  self.request(
    Route::DeleteFollowupMessage(application_id~, token~, message_id~),
  )
  |> ignore
}
