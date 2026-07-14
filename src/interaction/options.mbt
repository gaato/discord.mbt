///|
/// Errors raised while reading typed values out of submitted command options.
pub(all) suberror OptionError {
  MissingOption(name~ : String)
  WrongType(name~ : String, expected~ : String)
  MissingResolved(name~ : String, kind~ : String)
} derive(Debug)

///|
/// Typed reader over the options submitted with an application command.
///
/// Subcommand and subcommand-group levels are flattened away on
/// construction: `path()` reports the traversed names and the value
/// accessors see only the leaf options. Required accessors raise
/// `OptionError`; `_opt` variants return `None` when the option is absent
/// but still raise if a present option has an unexpected shape.
pub struct CommandOptions {
  priv path : Array[String]
  priv leaves : Map[String, @model.CommandDataOption]
  priv resolved : @model.ResolvedData?
}

///|
pub fn CommandOptions::from_data(data : @model.CommandData) -> CommandOptions {
  let path = []
  let mut options = data.options
  for ;; {
    match options {
      Some([only]) if only.typ is (SubCommand | SubCommandGroup) => {
        path.push(only.name)
        options = only.options
      }
      _ => break
    }
  }
  let leaves = {}
  if options is Some(list) {
    for opt in list {
      leaves[opt.name] = opt
    }
  }
  { path, leaves, resolved: data.resolved }
}

///|
/// The subcommand-group / subcommand names traversed during flattening,
/// outermost first (empty for a plain command).
pub fn CommandOptions::path(self : CommandOptions) -> Array[String] {
  self.path
}

///|
pub fn CommandOptions::has(self : CommandOptions, name : String) -> Bool {
  self.leaves.contains(name)
}

///|
/// The name of the option currently focused for autocomplete, if any.
pub fn CommandOptions::focused(self : CommandOptions) -> String? {
  for name, opt in self.leaves {
    if opt.focused is Some(true) {
      return Some(name)
    }
  }
  None
}

///|
/// The focused option and its raw partial value, when present.
pub fn CommandOptions::focused_input(self : CommandOptions) -> SuggestInput? {
  for name, opt in self.leaves {
    if opt.focused is Some(true) {
      return Some({
        name_: name,
        value_: opt.value.unwrap_or_else(() => Json::null()),
      })
    }
  }
  None
}

///|
fn CommandOptions::raw_value(
  self : CommandOptions,
  name : String,
  expected : String,
) -> Json? raise OptionError {
  guard self.leaves.get(name) is Some(opt) else { return None }
  guard opt.value is Some(value) else {
    raise OptionError::WrongType(name~, expected~)
  }
  Some(value)
}

///|
fn CommandOptions::required(
  self : CommandOptions,
  name : String,
  expected : String,
) -> Json raise OptionError {
  guard self.raw_value(name, expected) is Some(value) else {
    raise OptionError::MissingOption(name~)
  }
  value
}

///|
fn json_string(
  value : Json,
  name : String,
  expected : String,
) -> String raise OptionError {
  guard value is String(s) else {
    raise OptionError::WrongType(name~, expected~)
  }
  s
}

///|
fn json_int64(
  value : Json,
  name : String,
  expected : String,
) -> Int64 raise OptionError {
  match value {
    Number(_, repr=Some(r)) =>
      @string.parse_int64(r.to_string()) catch {
        _ => raise OptionError::WrongType(name~, expected~)
      }
    Number(n, repr=None) => n.to_int64()
    _ => raise OptionError::WrongType(name~, expected~)
  }
}

///|
fn json_double(
  value : Json,
  name : String,
  expected : String,
) -> Double raise OptionError {
  guard value is Number(n, ..) else {
    raise OptionError::WrongType(name~, expected~)
  }
  n
}

///|
fn json_bool(
  value : Json,
  name : String,
  expected : String,
) -> Bool raise OptionError {
  match value {
    True => true
    False => false
    _ => raise OptionError::WrongType(name~, expected~)
  }
}

///|
fn[M] json_id(
  value : Json,
  name : String,
  expected : String,
) -> @model.Id[M] raise OptionError {
  guard value is String(s) else {
    raise OptionError::WrongType(name~, expected~)
  }
  @model.Id::parse(s.view()) catch {
    _ => raise OptionError::WrongType(name~, expected~)
  }
}

///|
pub fn CommandOptions::string(
  self : CommandOptions,
  name : String,
) -> String raise OptionError {
  json_string(self.required(name, "string"), name, "string")
}

///|
pub fn CommandOptions::string_opt(
  self : CommandOptions,
  name : String,
) -> String? raise OptionError {
  match self.raw_value(name, "string") {
    Some(value) => Some(json_string(value, name, "string"))
    None => None
  }
}

///|
pub fn CommandOptions::int(
  self : CommandOptions,
  name : String,
) -> Int64 raise OptionError {
  json_int64(self.required(name, "integer"), name, "integer")
}

///|
pub fn CommandOptions::int_opt(
  self : CommandOptions,
  name : String,
) -> Int64? raise OptionError {
  match self.raw_value(name, "integer") {
    Some(value) => Some(json_int64(value, name, "integer"))
    None => None
  }
}

///|
pub fn CommandOptions::number(
  self : CommandOptions,
  name : String,
) -> Double raise OptionError {
  json_double(self.required(name, "number"), name, "number")
}

///|
pub fn CommandOptions::number_opt(
  self : CommandOptions,
  name : String,
) -> Double? raise OptionError {
  match self.raw_value(name, "number") {
    Some(value) => Some(json_double(value, name, "number"))
    None => None
  }
}

///|
pub fn CommandOptions::bool(
  self : CommandOptions,
  name : String,
) -> Bool raise OptionError {
  json_bool(self.required(name, "boolean"), name, "boolean")
}

///|
pub fn CommandOptions::bool_opt(
  self : CommandOptions,
  name : String,
) -> Bool? raise OptionError {
  match self.raw_value(name, "boolean") {
    Some(value) => Some(json_bool(value, name, "boolean"))
    None => None
  }
}

///|
pub fn CommandOptions::user(
  self : CommandOptions,
  name : String,
) -> @model.UserId raise OptionError {
  json_id(self.required(name, "user id"), name, "user id")
}

///|
pub fn CommandOptions::user_opt(
  self : CommandOptions,
  name : String,
) -> @model.UserId? raise OptionError {
  match self.raw_value(name, "user id") {
    Some(value) => Some(json_id(value, name, "user id"))
    None => None
  }
}

///|
pub fn CommandOptions::channel(
  self : CommandOptions,
  name : String,
) -> @model.ChannelId raise OptionError {
  json_id(self.required(name, "channel id"), name, "channel id")
}

///|
pub fn CommandOptions::channel_opt(
  self : CommandOptions,
  name : String,
) -> @model.ChannelId? raise OptionError {
  match self.raw_value(name, "channel id") {
    Some(value) => Some(json_id(value, name, "channel id"))
    None => None
  }
}

///|
pub fn CommandOptions::role(
  self : CommandOptions,
  name : String,
) -> @model.RoleId raise OptionError {
  json_id(self.required(name, "role id"), name, "role id")
}

///|
pub fn CommandOptions::role_opt(
  self : CommandOptions,
  name : String,
) -> @model.RoleId? raise OptionError {
  match self.raw_value(name, "role id") {
    Some(value) => Some(json_id(value, name, "role id"))
    None => None
  }
}

///|
pub fn CommandOptions::mentionable(
  self : CommandOptions,
  name : String,
) -> @model.GenericId raise OptionError {
  json_id(self.required(name, "mentionable id"), name, "mentionable id")
}

///|
pub fn CommandOptions::mentionable_opt(
  self : CommandOptions,
  name : String,
) -> @model.GenericId? raise OptionError {
  match self.raw_value(name, "mentionable id") {
    Some(value) => Some(json_id(value, name, "mentionable id"))
    None => None
  }
}

///|
/// Look up an attachment option through the interaction's resolved data.
pub fn CommandOptions::attachment(
  self : CommandOptions,
  name : String,
) -> @model.Attachment raise OptionError {
  let id : @model.AttachmentId = json_id(
    self.required(name, "attachment id"),
    name,
    "attachment id",
  )
  guard self.resolved is Some(resolved) &&
    resolved.attachments is Some(map) &&
    map.get(id.to_string()) is Some(attachment) else {
    raise OptionError::MissingResolved(name~, kind="attachment")
  }
  attachment
}

///|
/// The resolved `User` for a user option, when Discord included it.
pub fn CommandOptions::resolved_user(
  self : CommandOptions,
  id : @model.UserId,
) -> @model.User? {
  guard self.resolved is Some(resolved) && resolved.users is Some(map) else {
    return None
  }
  map.get(id.to_string())
}

///|
/// The resolved partial `GuildMember` for a user option, when available.
pub fn CommandOptions::resolved_member(
  self : CommandOptions,
  id : @model.UserId,
) -> @model.GuildMember? {
  guard self.resolved is Some(resolved) && resolved.members is Some(map) else {
    return None
  }
  map.get(id.to_string())
}

///|
/// The resolved partial `Channel` for a channel option, when available.
pub fn CommandOptions::resolved_channel(
  self : CommandOptions,
  id : @model.ChannelId,
) -> @model.Channel? {
  guard self.resolved is Some(resolved) && resolved.channels is Some(map) else {
    return None
  }
  map.get(id.to_string())
}

///|
/// The resolved `Role` for a role option, when available.
pub fn CommandOptions::resolved_role(
  self : CommandOptions,
  id : @model.RoleId,
) -> @model.Role? {
  guard self.resolved is Some(resolved) && resolved.roles is Some(map) else {
    return None
  }
  map.get(id.to_string())
}
