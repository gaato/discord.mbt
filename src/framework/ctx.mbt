///|
/// Build the `data` object of a message-style interaction response.
fn message_response_data(
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
  ephemeral : Bool,
) -> Json {
  let builder = @model.ObjBuilder::new()
    .opt("content", content)
    .opt("embeds", embeds)
    .opt("components", components)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", @dhttp.attachments_json(fs)) |> ignore
  }
  if ephemeral {
    builder.field("flags", @model.MessageFlags::ephemeral()) |> ignore
  }
  builder.build()
}

///|
async fn respond_message(
  gate : ResponseGate,
  typ : @model.InteractionResponseType,
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
  ephemeral : Bool,
) -> Unit {
  gate.send(
    {
      typ,
      data: Some(
        message_response_data(content, embeds, components, files, ephemeral),
      ),
    },
    files?,
  )
}

///|
async fn respond_modal(
  gate : ResponseGate,
  custom_id : String,
  title : String,
  components : Array[@model.Component],
) -> Unit {
  gate.send({
    typ: Modal,
    data: Some(
      @model.ObjBuilder::new()
      .field("custom_id", custom_id)
      .field("title", title)
      .field("components", components)
      .build(),
    ),
  })
}

///|
/// The user who triggered an interaction, whether it arrived from a guild
/// (via the member object) or a DM.
fn invoking_user(interaction : @model.Interaction) -> @model.User? {
  match interaction.user {
    Some(user) => Some(user)
    None => interaction.guild_member.bind(m => m.user)
  }
}

///|
/// Context handed to a slash / context-menu command handler.
pub(all) struct CommandCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.CommandData
  options : @interaction.CommandOptions
  priv gate : ResponseGate
}

///|
/// The invoking user, from either the guild member or the DM user field.
pub fn CommandCtx::user(self : CommandCtx) -> @model.User? {
  invoking_user(self.interaction)
}

///|
/// Decode the submitted options into a typed `CommandModel`.
pub fn[T : @interaction.CommandModel] CommandCtx::model(
  self : CommandCtx,
) -> T raise {
  T::from_options(self.options)
}

///|
/// Send the initial "channel message with source" response.
pub async fn CommandCtx::respond(
  self : CommandCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    ChannelMessageWithSource,
    content,
    embeds,
    components,
    files,
    ephemeral,
  )
}

///|
/// Acknowledge now and reply later via `edit_response` / `followup`.
pub async fn CommandCtx::defer_response(
  self : CommandCtx,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    DeferredChannelMessageWithSource,
    None,
    None,
    None,
    None,
    ephemeral,
  )
}

///|
/// Display a modal as the initial command response.
pub async fn CommandCtx::show_modal(
  self : CommandCtx,
  custom_id~ : String,
  title~ : String,
  components~ : Array[@model.Component],
) -> Unit {
  respond_modal(self.gate, custom_id, title, components)
}

///|
/// Edit the original response (typically after `defer`).
pub async fn CommandCtx::edit_response(
  self : CommandCtx,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
  files? : Array[@dhttp.FileUpload],
) -> @model.Message {
  self.client.edit_original_response(
    self.application_id,
    self.interaction.token,
    content~,
    embeds~,
    components~,
    files?,
  )
}

///|
/// Send a followup message after the initial response.
pub async fn CommandCtx::followup(
  self : CommandCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> @model.Message {
  self.client.create_followup(
    self.application_id,
    self.interaction.token,
    content?,
    embeds?,
    components?,
    files?,
    flags=if ephemeral {
      @model.MessageFlags::ephemeral()
    } else {
      @model.MessageFlags::from_bits(0)
    },
  )
}

///|
/// Context handed to a message-component (button / select) handler.
pub(all) struct ComponentCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.ComponentData
  priv gate : ResponseGate
}

///|
/// The invoking user, from either the guild member or the DM user field.
pub fn ComponentCtx::user(self : ComponentCtx) -> @model.User? {
  invoking_user(self.interaction)
}

///|
/// Send a new "channel message with source" response.
pub async fn ComponentCtx::respond(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    ChannelMessageWithSource,
    content,
    embeds,
    components,
    files,
    ephemeral,
  )
}

///|
/// Edit the message the component is attached to.
pub async fn ComponentCtx::update_message(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
) -> Unit {
  respond_message(
    self.gate,
    UpdateMessage,
    content,
    embeds,
    components,
    None,
    false,
  )
}

///|
/// Display a modal as the initial component response.
pub async fn ComponentCtx::show_modal(
  self : ComponentCtx,
  custom_id~ : String,
  title~ : String,
  components~ : Array[@model.Component],
) -> Unit {
  respond_modal(self.gate, custom_id, title, components)
}

///|
/// Acknowledge now and send a message later through webhook methods.
pub async fn ComponentCtx::defer_response(
  self : ComponentCtx,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    DeferredChannelMessageWithSource,
    None,
    None,
    None,
    None,
    ephemeral,
  )
}

///|
/// Acknowledge without any visible change (edit later if needed).
pub async fn ComponentCtx::defer_update(self : ComponentCtx) -> Unit {
  self.gate.send({ typ: DeferredUpdateMessage, data: None })
}

///|
/// Edit the original interaction response after deferring.
pub async fn ComponentCtx::edit_response(
  self : ComponentCtx,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
  files? : Array[@dhttp.FileUpload],
) -> @model.Message {
  self.client.edit_original_response(
    self.application_id,
    self.interaction.token,
    content~,
    embeds~,
    components~,
    files?,
  )
}

///|
/// Send a component-interaction followup message.
pub async fn ComponentCtx::followup(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> @model.Message {
  self.client.create_followup(
    self.application_id,
    self.interaction.token,
    content?,
    embeds?,
    components?,
    files?,
    flags=if ephemeral {
      @model.MessageFlags::ephemeral()
    } else {
      @model.MessageFlags::from_bits(0)
    },
  )
}

///|
/// Context handed to a modal-submit handler.
pub(all) struct ModalCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.ModalData
  priv gate : ResponseGate
}

///|
/// The invoking user, from either the guild member or the DM user field.
pub fn ModalCtx::user(self : ModalCtx) -> @model.User? {
  invoking_user(self.interaction)
}

///|
/// The submitted value of the text input with the given custom id.
pub fn ModalCtx::text_value(self : ModalCtx, custom_id : String) -> String? {
  fn walk(components : Array[@model.Component]) -> String? {
    for component in components {
      match component {
        ActionRow(row) =>
          if walk(row.components) is Some(value) {
            return Some(value)
          }
        Label(label) =>
          if walk([label.component]) is Some(value) {
            return Some(value)
          }
        TextInput(input) =>
          if input.custom_id == custom_id {
            return input.value
          }
        _ => ()
      }
    }
    None
  }

  walk(self.data.components)
}

///|
/// Send a "channel message with source" response to the modal.
pub async fn ModalCtx::respond(
  self : ModalCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    ChannelMessageWithSource,
    content,
    embeds,
    components,
    files,
    ephemeral,
  )
}

///|
/// Acknowledge now and reply later via a followup.
pub async fn ModalCtx::defer_response(
  self : ModalCtx,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    DeferredChannelMessageWithSource,
    None,
    None,
    None,
    None,
    ephemeral,
  )
}

///|
/// Edit the original modal interaction response after deferring.
pub async fn ModalCtx::edit_response(
  self : ModalCtx,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
  files? : Array[@dhttp.FileUpload],
) -> @model.Message {
  self.client.edit_original_response(
    self.application_id,
    self.interaction.token,
    content~,
    embeds~,
    components~,
    files?,
  )
}

///|
/// Send a modal-interaction followup message.
pub async fn ModalCtx::followup(
  self : ModalCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> @model.Message {
  self.client.create_followup(
    self.application_id,
    self.interaction.token,
    content?,
    embeds?,
    components?,
    files?,
    flags=if ephemeral {
      @model.MessageFlags::ephemeral()
    } else {
      @model.MessageFlags::from_bits(0)
    },
  )
}

///|
/// Context handed to an autocomplete handler.
pub(all) struct AutocompleteCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.CommandData
  options : @interaction.CommandOptions
  priv gate : ResponseGate
}

///|
/// Send autocomplete suggestions (at most 25 choices).
pub async fn AutocompleteCtx::suggest(
  self : AutocompleteCtx,
  choices : Array[@model.CommandOptionChoice],
) -> Unit {
  self.gate.send({
    typ: Autocomplete,
    data: Some(@model.ObjBuilder::new().field("choices", choices).build()),
  })
}
