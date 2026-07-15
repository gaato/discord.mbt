///|
/// Shared skeleton for option builders: every field a builder does not set
/// stays `None` so the registration payload omits it.
fn base_option(
  typ : @model.CommandOptionType,
  name : String,
  description : String,
) -> @model.CommandOption {
  {
    typ,
    name,
    name_localizations: None,
    description,
    description_localizations: None,
    required: None,
    choices: None,
    options: None,
    channel_types: None,
    min_value: None,
    max_value: None,
    min_length: None,
    max_length: None,
    autocomplete: None,
  }
}

///|
/// Describe a STRING option.
pub fn string_option(
  name : String,
  description : String,
  required? : Bool,
  choices? : Array[@model.CommandOptionChoice],
  min_length? : Int,
  max_length? : Int,
  autocomplete? : Bool,
) -> @model.CommandOption {
  {
    ..base_option(String, name, description),
    required,
    choices,
    min_length,
    max_length,
    autocomplete,
  }
}

///|
/// Describe an INTEGER option.
pub fn integer_option(
  name : String,
  description : String,
  required? : Bool,
  choices? : Array[@model.CommandOptionChoice],
  min_value? : Int64,
  max_value? : Int64,
  autocomplete? : Bool,
) -> @model.CommandOption {
  let min_value = min_value.map(value => Json::number(value.to_double()))
  let max_value = max_value.map(value => Json::number(value.to_double()))
  {
    ..base_option(Integer, name, description),
    required,
    choices,
    min_value,
    max_value,
    autocomplete,
  }
}

///|
/// Describe a NUMBER option.
pub fn number_option(
  name : String,
  description : String,
  required? : Bool,
  choices? : Array[@model.CommandOptionChoice],
  min_value? : Double,
  max_value? : Double,
  autocomplete? : Bool,
) -> @model.CommandOption {
  let min_value = min_value.map(value => Json::number(value))
  let max_value = max_value.map(value => Json::number(value))
  {
    ..base_option(Number, name, description),
    required,
    choices,
    min_value,
    max_value,
    autocomplete,
  }
}

///|
/// Describe a BOOLEAN option.
pub fn boolean_option(
  name : String,
  description : String,
  required? : Bool,
) -> @model.CommandOption {
  { ..base_option(Boolean, name, description), required, }
}

///|
/// Describe a USER option.
pub fn user_option(
  name : String,
  description : String,
  required? : Bool,
) -> @model.CommandOption {
  { ..base_option(User, name, description), required, }
}

///|
/// Describe a CHANNEL option.
pub fn channel_option(
  name : String,
  description : String,
  required? : Bool,
  channel_types? : Array[@model.ChannelType],
) -> @model.CommandOption {
  { ..base_option(Channel, name, description), required, channel_types }
}

///|
/// Describe a ROLE option.
pub fn role_option(
  name : String,
  description : String,
  required? : Bool,
) -> @model.CommandOption {
  { ..base_option(Role, name, description), required, }
}

///|
/// Describe a MENTIONABLE option.
pub fn mentionable_option(
  name : String,
  description : String,
  required? : Bool,
) -> @model.CommandOption {
  { ..base_option(Mentionable, name, description), required, }
}

///|
/// Describe an ATTACHMENT option.
pub fn attachment_option(
  name : String,
  description : String,
  required? : Bool,
) -> @model.CommandOption {
  { ..base_option(Attachment, name, description), required, }
}

///|
/// Describe a SUB_COMMAND option.
pub fn sub_command(
  name : String,
  description : String,
  options? : Array[@model.CommandOption] = [],
) -> @model.CommandOption {
  let options = if options.length() > 0 { Some(options) } else { None }
  { ..base_option(SubCommand, name, description), options, }
}

///|
/// Describe a SUB_COMMAND_GROUP option.
pub fn sub_command_group(
  name : String,
  description : String,
  sub_commands : Array[@model.CommandOption],
) -> @model.CommandOption {
  let options = if sub_commands.length() > 0 {
    Some(sub_commands)
  } else {
    None
  }
  { ..base_option(SubCommandGroup, name, description), options, }
}

///|
/// Describe a string-valued option choice.
pub fn string_choice(
  name : String,
  value : String,
) -> @model.CommandOptionChoice {
  { name, name_localizations: None, value: Json::string(value) }
}

///|
/// Describe an integer-valued option choice.
pub fn int_choice(name : String, value : Int64) -> @model.CommandOptionChoice {
  { name, name_localizations: None, value: Json::number(value.to_double()) }
}

///|
/// Describe a number-valued option choice.
pub fn number_choice(
  name : String,
  value : Double,
) -> @model.CommandOptionChoice {
  { name, name_localizations: None, value: Json::number(value) }
}

///|
/// Build a message component row.
pub fn action_row(components : Array[@model.Component]) -> @model.Component {
  ActionRow({ id: None, components })
}

///|
/// Build an interactive button.
pub fn button(
  custom_id~ : String,
  label? : String,
  style? : @model.ButtonStyle = Primary,
  emoji? : @model.Emoji,
  disabled? : Bool,
) -> @model.Component {
  Button({
    id: None,
    style,
    label,
    emoji,
    custom_id: Some(custom_id),
    sku_id: None,
    url: None,
    disabled,
  })
}

///|
/// Build a link button.
pub fn link_button(
  url~ : String,
  label? : String,
  emoji? : @model.Emoji,
  disabled? : Bool,
) -> @model.Component {
  Button({
    id: None,
    style: Link,
    label,
    emoji,
    custom_id: None,
    sku_id: None,
    url: Some(url),
    disabled,
  })
}

///|
/// Build an option for a string select menu.
pub fn select_option(
  label~ : String,
  value~ : String,
  description? : String,
  emoji? : @model.Emoji,
  default? : Bool,
) -> @model.SelectOption {
  { label, value, description, emoji, default }
}

///|
/// Build a string select menu.
pub fn string_select(
  custom_id~ : String,
  options~ : Array[@model.SelectOption],
  placeholder? : String,
  min_values? : Int,
  max_values? : Int,
  disabled? : Bool,
) -> @model.Component {
  StringSelect({
    id: None,
    custom_id,
    placeholder,
    min_values,
    max_values,
    disabled,
    options: Some(options),
    channel_types: None,
    default_values: None,
    values: None,
  })
}

///|
fn auto_select(
  typ : Int,
  custom_id : String,
  placeholder : String?,
  min_values : Int?,
  max_values : Int?,
  disabled : Bool?,
  channel_types : Array[@model.ChannelType]?,
) -> @model.Component {
  let menu : @model.SelectMenu = {
    id: None,
    custom_id,
    placeholder,
    min_values,
    max_values,
    disabled,
    options: None,
    channel_types,
    default_values: None,
    values: None,
  }
  match typ {
    5 => UserSelect(menu)
    6 => RoleSelect(menu)
    7 => MentionableSelect(menu)
    _ => ChannelSelect(menu)
  }
}

///|
/// Build a user select menu; the chosen users arrive in
/// `resolved` and via the component context's `selected_users`.
pub fn user_select(
  custom_id~ : String,
  placeholder? : String,
  min_values? : Int,
  max_values? : Int,
  disabled? : Bool,
) -> @model.Component {
  auto_select(5, custom_id, placeholder, min_values, max_values, disabled, None)
}

///|
/// Build a role select menu; the chosen roles arrive via the component
/// context's `selected_roles`.
pub fn role_select(
  custom_id~ : String,
  placeholder? : String,
  min_values? : Int,
  max_values? : Int,
  disabled? : Bool,
) -> @model.Component {
  auto_select(6, custom_id, placeholder, min_values, max_values, disabled, None)
}

///|
/// Build a mentionable select menu accepting both users and roles.
pub fn mentionable_select(
  custom_id~ : String,
  placeholder? : String,
  min_values? : Int,
  max_values? : Int,
  disabled? : Bool,
) -> @model.Component {
  auto_select(7, custom_id, placeholder, min_values, max_values, disabled, None)
}

///|
/// Build a channel select menu, optionally restricted to `channel_types`;
/// the chosen channels arrive via the component context's
/// `selected_channels`.
pub fn channel_select(
  custom_id~ : String,
  placeholder? : String,
  min_values? : Int,
  max_values? : Int,
  disabled? : Bool,
  channel_types? : Array[@model.ChannelType],
) -> @model.Component {
  auto_select(
    8, custom_id, placeholder, min_values, max_values, disabled, channel_types,
  )
}

///|
/// Build a text display block (components v2): markdown `content` rendered
/// in the message body. Requires the `IS_COMPONENTS_V2` message flag.
pub fn text_display(content : String) -> @model.Component {
  TextDisplay({ id: None, content })
}

///|
/// Build a section (components v2): up to three text displays laid out next
/// to an `accessory` (a thumbnail or button).
pub fn section(
  components~ : Array[@model.Component],
  accessory~ : @model.Component,
) -> @model.Component {
  Section({ id: None, components, accessory })
}

///|
/// Build a thumbnail accessory (components v2) from an image `url`
/// (`https://...` or `attachment://<filename>`).
pub fn thumbnail(
  url~ : String,
  description? : String,
  spoiler? : Bool,
) -> @model.Component {
  Thumbnail({
    id: None,
    media: {
      url,
      proxy_url: None,
      height: None,
      width: None,
      placeholder: None,
      placeholder_version: None,
      content_type: None,
      flags: None,
      attachment_id: None,
    },
    description,
    spoiler,
  })
}

///|
/// Build a container (components v2): groups child components in a rounded
/// box with an optional `accent_color` (`0xRRGGBB`) stripe, similar to an
/// embed.
pub fn container(
  components~ : Array[@model.Component],
  accent_color? : Int,
  spoiler? : Bool,
) -> @model.Component {
  Container({
    id: None,
    components,
    accent_color: accent_color.map(value => Value(value)),
    spoiler,
  })
}

///|
/// Build a separator (components v2): vertical padding between components,
/// with an optional visible `divider` line and `spacing` size (1 = small,
/// 2 = large).
pub fn separator(divider? : Bool, spacing? : Int) -> @model.Component {
  Separator({ id: None, divider, spacing })
}

///|
/// Build one media gallery entry from an image or video `url`
/// (`https://...` or `attachment://<filename>`), for use with
/// `media_gallery`.
pub fn media_item(
  url~ : String,
  description? : String,
  spoiler? : Bool,
) -> @model.MediaGalleryItem {
  {
    media: {
      url,
      proxy_url: None,
      height: None,
      width: None,
      placeholder: None,
      placeholder_version: None,
      content_type: None,
      flags: None,
      attachment_id: None,
    },
    description,
    spoiler,
  }
}

///|
/// Build a media gallery (components v2): a grid of 1–10 media items.
pub fn media_gallery(
  items : Array[@model.MediaGalleryItem],
) -> @model.Component {
  MediaGallery({ id: None, items })
}

///|
/// Wrap a modal component with a `label` and optional `description`. Modals
/// require every input to be wrapped in a label; the typed `ModalField`
/// builders do this automatically.
pub fn label(
  label~ : String,
  component~ : @model.Component,
  description? : String,
) -> @model.Component {
  Label({ id: None, label: Some(label), description, component })
}

///|
/// Build a modal text input. `style` picks single-line `Short` (default) or
/// multi-line `Paragraph`; `value` prefills the field. Wrap it with `label`
/// before placing it in a modal (the typed `ModalField` builders handle
/// this).
pub fn text_input(
  custom_id~ : String,
  style? : @model.TextInputStyle = Short,
  placeholder? : String,
  min_length? : Int,
  max_length? : Int,
  required? : Bool,
  value? : String,
) -> @model.Component {
  TextInput({
    id: None,
    custom_id,
    style: Some(style),
    label: None,
    min_length,
    max_length,
    required,
    value,
    placeholder,
  })
}
