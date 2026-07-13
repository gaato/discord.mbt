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
