///|
/// One typed input in a modal form.
pub struct ModalField[A] {
  priv definition_ : @model.Component
  priv decode_ : (ModalSubmission) -> A raise HandlerError
  priv present_ : (ModalSubmission) -> Bool
}

///|
/// A composable collection of typed modal inputs.
pub struct ModalFields[A] {
  priv definitions_ : Array[@model.Component]
  priv decode_ : (ModalSubmission) -> A raise HandlerError
}

///|
/// What a submitted modal carries: its component tree plus the entities
/// Discord resolved for it (file uploads resolve to attachments).
priv struct ModalSubmission {
  components : Array[@model.Component]
  resolved : @model.ResolvedData?
}

///|
/// A typed modal definition. The field decoder is retained for the matching
/// `on_modal` registration while `show` erases it into a `ModalHandle`.
pub struct Modal[A] {
  priv custom_id_ : String
  priv title_ : String
  priv fields_ : ModalFields[A]
}

///|
/// A type-erased modal response ready to be returned by a command or component
/// handler.
pub struct ModalHandle {
  priv custom_id_ : String
  priv title_ : String
  priv components_ : Array[@model.Component]
}

///|
/// Invalid per-show text-input prefill configuration.
pub(all) suberror ModalPrefillError {
  UnknownCustomId(custom_id~ : String)
  NonTextInput(custom_id~ : String)
} derive(Debug)

///|
fn find_modal_component(
  components : Array[@model.Component],
  custom_id : String,
) -> @model.Component? {
  for component in components {
    match component {
      ActionRow(row) =>
        if find_modal_component(row.components, custom_id) is Some(found) {
          return Some(found)
        }
      Label(label) =>
        if find_modal_component([label.component], custom_id) is Some(found) {
          return Some(found)
        }
      TextInput(input) if input.custom_id == custom_id => return Some(component)
      StringSelect(select) if select.custom_id == custom_id =>
        return Some(component)
      FileUpload(upload) if upload.custom_id == custom_id =>
        return Some(component)
      _ => ()
    }
  }
  None
}

///|
fn modal_component_present(
  components : Array[@model.Component],
  custom_id : String,
) -> Bool {
  match find_modal_component(components, custom_id) {
    Some(TextInput(input)) => input.value is Some(value) && !value.is_empty()
    Some(StringSelect(select)) =>
      select.values is Some(values) && !values.is_empty()
    Some(FileUpload(upload)) =>
      upload.values is Some(values) && !values.is_empty()
    _ => false
  }
}

///|
fn set_modal_field_optional(component : @model.Component) -> @model.Component {
  match component {
    Label(label) =>
      Label({ ..label, component: set_modal_field_optional(label.component), })
    TextInput(input) => TextInput({ ..input, required: Some(false), })
    StringSelect(select) => StringSelect({ ..select, min_values: Some(0), })
    FileUpload(upload) =>
      FileUpload({ ..upload, required: Some(false), min_values: Some(0), })
    other => other
  }
}

///|
fn modal_text_input_ids(components : Array[@model.Component]) -> Array[String] {
  let result = []
  for component in components {
    match component {
      ActionRow(row) => result.append(modal_text_input_ids(row.components))
      Label(label) => result.append(modal_text_input_ids([label.component]))
      TextInput(input) => result.push(input.custom_id)
      _ => ()
    }
  }
  result
}

///|
fn modal_file_type_filters(
  components : Array[@model.Component],
) -> Array[(String, Array[@model.FileTypeFilter])] {
  let result = []
  for component in components {
    match component {
      ActionRow(row) => result.append(modal_file_type_filters(row.components))
      Label(label) => result.append(modal_file_type_filters([label.component]))
      FileUpload({ custom_id, file_types: Some(filters), .. }) =>
        result.push((custom_id, filters))
      _ => ()
    }
  }
  result
}

///|
fn prefill_modal_component(
  component : @model.Component,
  values : Map[String, String],
) -> @model.Component {
  match component {
    ActionRow(row) =>
      ActionRow({
        ..row,
        components: row.components.map(component => {
          prefill_modal_component(component, values)
        }),
      })
    Label(label) =>
      Label({
        ..label,
        component: prefill_modal_component(label.component, values),
      })
    TextInput(input) =>
      match values.get(input.custom_id) {
        Some(value) => TextInput({ ..input, value: Some(value), })
        None => component
      }
    _ => component
  }
}

///|
fn prefill_modal_components(
  components : Array[@model.Component],
  values : Map[String, String],
) -> Array[@model.Component] raise ModalPrefillError {
  for custom_id, _ in values {
    match find_modal_component(components, custom_id) {
      Some(TextInput(_)) => ()
      Some(_) => raise NonTextInput(custom_id~)
      None => raise UnknownCustomId(custom_id~)
    }
  }
  components.map(component => prefill_modal_component(component, values))
}

///|
/// Define a modern label-wrapped text input. `value` is its static prefill;
/// `Modal::show(values=...)` can override it for one response.
pub fn text_field(
  custom_id~ : String,
  label~ : String,
  style? : @model.TextInputStyle = Short,
  description? : String,
  placeholder? : String,
  min_length? : Int,
  max_length? : Int,
  value? : String,
) -> ModalField[String] {
  let input = @interaction.text_input(
    custom_id~,
    style~,
    placeholder?,
    min_length?,
    max_length?,
    required=true,
    value?,
  )
  {
    definition_: @interaction.label(label~, component=input, description?),
    present_: submission => {
      modal_component_present(submission.components, custom_id)
    },
    decode_: submission => {
      match find_modal_component(submission.components, custom_id) {
        Some(TextInput({ value: Some(value), .. })) if !value.is_empty() =>
          value
        _ => raise InvalidArgument("missing modal field: \{custom_id}")
      }
    },
  }
}

///|
/// Define a modern label-wrapped string select.
pub fn select_field(
  custom_id~ : String,
  label~ : String,
  options~ : Array[@model.SelectOption],
  description? : String,
  placeholder? : String,
  min_values? : Int,
  max_values? : Int,
) -> ModalField[Array[String]] {
  let select = @interaction.string_select(
    custom_id~,
    options~,
    placeholder?,
    min_values?,
    max_values?,
  )
  {
    definition_: @interaction.label(label~, component=select, description?),
    present_: submission => {
      modal_component_present(submission.components, custom_id)
    },
    decode_: submission => {
      match find_modal_component(submission.components, custom_id) {
        Some(StringSelect({ values: Some(values), .. })) if !values.is_empty() =>
          values
        _ => raise InvalidArgument("missing modal field: \{custom_id}")
      }
    },
  }
}

///|
/// Define a modern label-wrapped file upload. Decodes to the uploaded files'
/// attachment objects (resolved by Discord alongside the submission).
/// `file_types` filters selectable files by extension only — validate the
/// contents yourself. `min_values`/`max_values` bound the file count.
pub fn file_field(
  custom_id~ : String,
  label~ : String,
  description? : String,
  min_values? : Int,
  max_values? : Int,
  file_types? : Array[@model.FileTypeFilter],
) -> ModalField[Array[@model.Attachment]] {
  let upload = @interaction.file_upload(
    custom_id~,
    min_values?,
    max_values?,
    required=true,
    file_types?,
  )
  {
    definition_: @interaction.label(label~, component=upload, description?),
    present_: submission => {
      modal_component_present(submission.components, custom_id)
    },
    decode_: submission => {
      guard find_modal_component(submission.components, custom_id)
        is Some(FileUpload({ values: Some(ids), .. })) &&
        !ids.is_empty() else {
        raise InvalidArgument("missing modal field: \{custom_id}")
      }
      let attachments = submission.resolved
        .bind(resolved => resolved.attachments)
        .unwrap_or({})
      ids.map(id => {
        guard attachments.get(id) is Some(attachment) else {
          raise InvalidArgument(
            "unresolved attachment \{id} in modal field: \{custom_id}",
          )
        }
        attachment
      })
    },
  }
}

///|
/// Make a modal field optional. Missing and empty submissions decode to None.
pub fn[A] ModalField::optional(self : ModalField[A]) -> ModalField[A?] {
  {
    definition_: set_modal_field_optional(self.definition_),
    present_: self.present_,
    decode_: submission => {
      if (self.present_)(submission) {
        Some((self.decode_)(submission))
      } else {
        None
      }
    },
  }
}

///|
/// Use a default when a modal field is missing or empty.
pub fn[A] ModalField::with_default(
  self : ModalField[A],
  value : A,
) -> ModalField[A] {
  {
    definition_: set_modal_field_optional(self.definition_),
    present_: self.present_,
    decode_: submission => {
      if (self.present_)(submission) {
        (self.decode_)(submission)
      } else {
        value
      }
    },
  }
}

///|
/// Validate a decoded field. Returning a message rejects the submission.
pub fn[A] ModalField::validate(
  self : ModalField[A],
  check : (A) -> String?,
) -> ModalField[A] {
  {
    definition_: self.definition_,
    present_: self.present_,
    decode_: submission => {
      let value = (self.decode_)(submission)
      match check(value) {
        Some(message) => raise InvalidArgument(message)
        None => value
      }
    },
  }
}

///|
/// Transform a decoded modal field without changing its emitted component.
pub fn[A, B] ModalField::map(
  self : ModalField[A],
  f : (A) -> B,
) -> ModalField[B] {
  {
    definition_: self.definition_,
    present_: self.present_,
    decode_: submission => f((self.decode_)(submission)),
  }
}

///|
/// Lift a single field into a `ModalFields`; combine further with `zip`
/// and `map`, or use the `mapN` helpers directly.
pub fn[A] ModalFields::of(field : ModalField[A]) -> ModalFields[A] {
  { definitions_: [field.definition_], decode_: field.decode_, }
}

///|
/// Transform the decoded value without changing the emitted
/// components.
pub fn[A, B] ModalFields::map(
  self : ModalFields[A],
  f : (A) -> B,
) -> ModalFields[B] {
  {
    definitions_: self.definitions_,
    decode_: submission => f((self.decode_)(submission)),
  }
}

///|
/// Concatenate two field sets and pair their decoded values.
pub fn[A, B] ModalFields::zip(
  self : ModalFields[A],
  other : ModalFields[B],
) -> ModalFields[(A, B)] {
  let definitions = self.definitions_.copy()
  definitions.append(other.definitions_)
  {
    definitions_: definitions,
    decode_: submission => {
      ((self.decode_)(submission), (other.decode_)(submission))
    },
  }
}

///|
/// Build a modal's field set from one field, mapping its decoded
/// value into the handler's argument type.
pub fn[A, Z] ModalFields::map1(
  a : ModalField[A],
  f : (A) -> Z,
) -> ModalFields[Z] {
  ModalFields::of(a).map(f)
}

///|
/// Build a modal's field set from two fields, combining their
/// decoded values with the final function argument.
pub fn[A, B, Z] ModalFields::map2(
  a : ModalField[A],
  b : ModalField[B],
  f : (A, B) -> Z,
) -> ModalFields[Z] {
  ModalFields::of(a).zip(ModalFields::of(b)).map(pair => f(pair.0, pair.1))
}

///|
/// Build a modal's field set from three fields, combining their
/// decoded values with the final function argument.
pub fn[A, B, C, Z] ModalFields::map3(
  a : ModalField[A],
  b : ModalField[B],
  c : ModalField[C],
  f : (A, B, C) -> Z,
) -> ModalFields[Z] {
  ModalFields::map2(a, b, (a, b) => (a, b))
  .zip(ModalFields::of(c))
  .map(value => f(value.0.0, value.0.1, value.1))
}

///|
/// Build a modal's field set from four fields, combining their
/// decoded values with the final function argument.
pub fn[A, B, C, D, Z] ModalFields::map4(
  a : ModalField[A],
  b : ModalField[B],
  c : ModalField[C],
  d : ModalField[D],
  f : (A, B, C, D) -> Z,
) -> ModalFields[Z] {
  ModalFields::map3(a, b, c, (a, b, c) => (a, b, c))
  .zip(ModalFields::of(d))
  .map(value => f(value.0.0, value.0.1, value.0.2, value.1))
}

///|
/// Build a modal's field set from five fields, combining their
/// decoded values with the final function argument.
pub fn[A, B, C, D, E, Z] ModalFields::map5(
  a : ModalField[A],
  b : ModalField[B],
  c : ModalField[C],
  d : ModalField[D],
  e : ModalField[E],
  f : (A, B, C, D, E) -> Z,
) -> ModalFields[Z] {
  ModalFields::map4(a, b, c, d, (a, b, c, d) => (a, b, c, d))
  .zip(ModalFields::of(e))
  .map(value => f(value.0.0, value.0.1, value.0.2, value.0.3, value.1))
}

///|
/// Define a typed modal.
///
/// ```mbt check
/// test "construct and validate a typed modal" {
///   let feedback = @app.modal(
///     custom_id="feedback",
///     title="Feedback",
///     fields=@app.ModalFields::of(
///       @app.text_field(custom_id="details", label="Details").optional(),
///     ),
///   )
///   let app = @app.App()
///   app.on_modal(feedback, Raw(_ => ()))
///   app.validate()
///   let _ : @app.ModalHandle = feedback.show(state="draft")
/// }
/// ```
pub fn[A] modal(
  custom_id~ : String,
  title~ : String,
  fields~ : ModalFields[A],
) -> Modal[A] {
  { custom_id_: custom_id, title_: title, fields_: fields, }
}

///|
/// Prepare a modal response, optionally appending opaque state after `:` and
/// overriding text-input defaults by `custom_id` for this response only.
/// Raises `ModalPrefillError` when an override key is unknown or does not name
/// a text input.
/// Raises `CustomIdError::TooLong` when the complete id exceeds 100 UTF-16 units.
pub fn[A] Modal::show(
  self : Modal[A],
  state? : String,
  values? : Map[String, String],
) -> ModalHandle raise {
  let custom_id = match state {
    Some(value) => "\{self.custom_id_}:\{value}"
    None => self.custom_id_
  }
  check_custom_id_length(custom_id)
  let components = match values {
    Some(overrides) =>
      prefill_modal_components(self.fields_.definitions_, overrides)
    None => self.fields_.definitions_.copy()
  }
  { custom_id_: custom_id, title_: self.title_, components_: components, }
}

///|
fn[A] Modal::decode(
  self : Modal[A],
  components : Array[@model.Component],
  resolved? : @model.ResolvedData,
) -> A raise HandlerError {
  (self.fields_.decode_)({ components, resolved, })
}

///|
async fn ModalHandle::send_command(
  self : ModalHandle,
  ctx : @framework.CommandCtx,
) -> Unit {
  ctx.show_modal(
    custom_id=self.custom_id_,
    title=self.title_,
    components=self.components_,
  )
}

///|
async fn ModalHandle::send_component(
  self : ModalHandle,
  ctx : @framework.ComponentCtx,
) -> Unit {
  ctx.show_modal(
    custom_id=self.custom_id_,
    title=self.title_,
    components=self.components_,
  )
}

///|
/// Execution strategy for a typed modal submission.
pub(all) enum ModalSubmitHandler[A] {
  Immediate(async (ModalImmediateCtx, A) -> InitialResponse)
  Deferred(ephemeral~ : Bool, async (ModalDeferredCtx, A) -> Unit)
  Raw(async (@framework.ModalCtx) -> Unit)
}

///|
/// Read-only modal-submit context for handlers returning an initial message.
pub struct ModalImmediateCtx {
  priv raw_ : @framework.ModalCtx
  priv bot_ : AppCtx
  priv state_ : String?
}

///|
/// Modal-submit context available after a deferred response.
pub struct ModalDeferredCtx {
  priv raw_ : @framework.ModalCtx
  priv bot_ : AppCtx
  priv state_ : String?
}

///|
fn modal_state(base : String, custom_id : String) -> String? {
  if custom_id == base {
    return None
  }
  Some(custom_id[base.length() + 1:].to_owned())
}

///|
/// The app-level services: the REST client and application id.
pub fn ModalImmediateCtx::app(self : ModalImmediateCtx) -> AppCtx {
  self.bot_
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn ModalImmediateCtx::scope(
  self : ModalImmediateCtx,
) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn ModalImmediateCtx::guild_scope(
  self : ModalImmediateCtx,
) -> @framework.GuildInvocation raise HandlerError {
  require_guild(self.raw_.guild_scope())
}

///|
/// The invoking user.
pub fn ModalImmediateCtx::user(self : ModalImmediateCtx) -> @model.User {
  self.raw_.user()
}

///|
/// What opened the modal: a component (with its host message) or a
/// command.
pub fn ModalImmediateCtx::origin(
  self : ModalImmediateCtx,
) -> @framework.ModalOrigin {
  self.raw_.origin()
}

///|
/// The full interaction payload.
pub fn ModalImmediateCtx::interaction(
  self : ModalImmediateCtx,
) -> @model.Interaction {
  self.raw_.interaction
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn ModalImmediateCtx::guild_id(self : ModalImmediateCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// The opaque state string passed to `Modal::show`, if any.
pub fn ModalImmediateCtx::state(self : ModalImmediateCtx) -> String? {
  self.state_
}

///|
/// Escape hatch for advanced inspection. Calling response methods on the
/// raw value opts out of this wrapper's response discipline.
/// Failure handling still follows the gate's real response state.
pub fn ModalImmediateCtx::raw(self : ModalImmediateCtx) -> @framework.ModalCtx {
  self.raw_
}

///|
/// The app-level services: the REST client and application id.
pub fn ModalDeferredCtx::app(self : ModalDeferredCtx) -> AppCtx {
  self.bot_
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn ModalDeferredCtx::scope(
  self : ModalDeferredCtx,
) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn ModalDeferredCtx::guild_scope(
  self : ModalDeferredCtx,
) -> @framework.GuildInvocation raise HandlerError {
  require_guild(self.raw_.guild_scope())
}

///|
/// The invoking user.
pub fn ModalDeferredCtx::user(self : ModalDeferredCtx) -> @model.User {
  self.raw_.user()
}

///|
/// What opened the modal: a component (with its host message) or a
/// command.
pub fn ModalDeferredCtx::origin(
  self : ModalDeferredCtx,
) -> @framework.ModalOrigin {
  self.raw_.origin()
}

///|
/// The full interaction payload.
pub fn ModalDeferredCtx::interaction(
  self : ModalDeferredCtx,
) -> @model.Interaction {
  self.raw_.interaction
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn ModalDeferredCtx::guild_id(self : ModalDeferredCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// The opaque state string passed to `Modal::show`, if any.
pub fn ModalDeferredCtx::state(self : ModalDeferredCtx) -> String? {
  self.state_
}

///|
/// Escape hatch for advanced inspection. Calling response methods on the
/// raw value opts out of this wrapper's response discipline.
/// Failure handling still follows the gate's real response state.
pub fn ModalDeferredCtx::raw(self : ModalDeferredCtx) -> @framework.ModalCtx {
  self.raw_
}

///|
/// Edit the original response after deferring.
pub async fn ModalDeferredCtx::edit_original(
  self : ModalDeferredCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
) -> @model.Message {
  self.raw_.edit_response(
    content?,
    clear_content~,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
  )
}

///|
/// Send a followup message after the initial deferred response.
pub async fn ModalDeferredCtx::followup(
  self : ModalDeferredCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  ephemeral? : Bool = false,
) -> @model.Message {
  self.raw_.followup(
    content?,
    embeds?,
    components?,
    files?,
    allowed_mentions?,
    ephemeral~,
  )
}

///|
async fn InitialResponse::send_modal(
  self : InitialResponse,
  ctx : @framework.ModalCtx,
) -> Unit {
  ctx.respond(
    content?=self.content_,
    embeds?=self.embeds_,
    components?=self.components_,
    files?=self.files_,
    allowed_mentions?=self.allowed_mentions_,
    ephemeral=self.ephemeral_,
  )
}

///|
async fn[A] dispatch_modal_handler(
  modal : Modal[A],
  handler : ModalSubmitHandler[A],
  bot : AppCtx,
  raw : @framework.ModalCtx,
) -> Unit {
  let route = raw.data.custom_id
  let state = modal_state(modal.custom_id_, route)
  match handler {
    Raw(run) => run(raw)
    Immediate(run) => {
      let value = modal.decode(raw.data.components, resolved?=raw.data.resolved)
      let response = run({ raw_: raw, bot_: bot, state_: state, }, value)
      response.send_modal(raw)
    }
    Deferred(ephemeral~, run) => {
      let value = modal.decode(raw.data.components, resolved?=raw.data.resolved)
      raw.defer_response(ephemeral~)
      run({ raw_: raw, bot_: bot, state_: state, }, value)
    }
  }
}
