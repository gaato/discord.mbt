///|
/// One typed input in a modal form.
pub struct ModalField[A] {
  priv definition_ : @model.Component
  priv decode_ : (Array[@model.Component]) -> A raise HandlerError
  priv present_ : (Array[@model.Component]) -> Bool
}

///|
/// A composable collection of typed modal inputs.
pub struct ModalFields[A] {
  priv definitions_ : Array[@model.Component]
  priv decode_ : (Array[@model.Component]) -> A raise HandlerError
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
    _ => false
  }
}

///|
fn set_modal_field_optional(component : @model.Component) -> @model.Component {
  match component {
    Label(label) =>
      Label({ ..label, component: set_modal_field_optional(label.component) })
    TextInput(input) => TextInput({ ..input, required: Some(false) })
    StringSelect(select) => StringSelect({ ..select, min_values: Some(0) })
    other => other
  }
}

///|
/// Define a modern label-wrapped text input.
pub fn text_field(
  custom_id~ : String,
  label~ : String,
  style? : @model.TextInputStyle = Short,
  description? : String,
  placeholder? : String,
  min_length? : Int,
  max_length? : Int,
) -> ModalField[String] {
  let input = @interaction.text_input(
    custom_id~,
    style~,
    placeholder?,
    min_length?,
    max_length?,
    required=true,
  )
  {
    definition_: @interaction.label(label~, component=input, description?),
    present_: components => modal_component_present(components, custom_id),
    decode_: components => {
      match find_modal_component(components, custom_id) {
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
    present_: components => modal_component_present(components, custom_id),
    decode_: components => {
      match find_modal_component(components, custom_id) {
        Some(StringSelect({ values: Some(values), .. })) if !values.is_empty() =>
          values
        _ => raise InvalidArgument("missing modal field: \{custom_id}")
      }
    },
  }
}

///|
/// Make a modal field optional. Missing and empty submissions decode to None.
pub fn[A] ModalField::optional(self : ModalField[A]) -> ModalField[A?] {
  {
    definition_: set_modal_field_optional(self.definition_),
    present_: self.present_,
    decode_: components => {
      if (self.present_)(components) {
        Some((self.decode_)(components))
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
    decode_: components => {
      if (self.present_)(components) {
        (self.decode_)(components)
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
    decode_: components => {
      let value = (self.decode_)(components)
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
    decode_: components => f((self.decode_)(components)),
  }
}

///|
/// Lift a single field into a `ModalFields`; combine further with `zip`
/// and `map`, or use the `mapN` helpers directly.
pub fn[A] ModalFields::of(field : ModalField[A]) -> ModalFields[A] {
  { definitions_: [field.definition_], decode_: field.decode_ }
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
    decode_: components => f((self.decode_)(components)),
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
    decode_: components => {
      ((self.decode_)(components), (other.decode_)(components))
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
///   let app = @app.App(sync=Disabled)
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
  { custom_id_: custom_id, title_: title, fields_: fields }
}

///|
/// Prepare a modal response, optionally appending opaque state after `:`.
pub fn[A] Modal::show(self : Modal[A], state? : String) -> ModalHandle {
  {
    custom_id_: match state {
      Some(value) => "\{self.custom_id_}:\{value}"
      None => self.custom_id_
    },
    title_: self.title_,
    components_: self.fields_.definitions_.copy(),
  }
}

///|
fn[A] Modal::decode(
  self : Modal[A],
  components : Array[@model.Component],
) -> A raise HandlerError {
  (self.fields_.decode_)(components)
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
fn modal_state(base : String, custom_id : String) -> String? raise HandlerError {
  if custom_id == base {
    return None
  }
  let prefix = "\{base}:"
  guard custom_id.has_prefix(prefix) else {
    raise InvalidArgument("modal custom_id does not match \{base}")
  }
  Some(custom_id[prefix.length():].to_owned())
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
/// The guild the interaction was invoked in, or `None` outside guilds.
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
/// The guild the interaction was invoked in, or `None` outside guilds.
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
  let state = modal_state(modal.custom_id_, route) catch {
    source => raise_failure(route, BeforeInitial, source)
  }
  match handler {
    Raw(run) =>
      run(raw) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
    Immediate(run) => {
      let value = modal.decode(raw.data.components) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
      let response = run({ raw_: raw, bot_: bot, state_: state }, value) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
      response.send_modal(raw) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
    }
    Deferred(ephemeral~, run) => {
      let value = modal.decode(raw.data.components) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
      raw.defer_response(ephemeral~) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
      run({ raw_: raw, bot_: bot, state_: state }, value) catch {
        source => raise_failure(route, AfterDeferred, source)
      }
    }
  }
}
