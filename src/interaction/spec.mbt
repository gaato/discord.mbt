///|
/// A declarative description of one application command, used both to
/// register the command (its `ToJson` is the registration payload) and to
/// route incoming interactions by command type and name.
pub(all) struct CommandSpec {
  name : String
  name_localizations : Map[String, String]?
  description : String
  description_localizations : Map[String, String]?
  typ : @model.ApplicationCommandType
  options : Array[@model.CommandOption]
  default_member_permissions : @model.Permissions?
  nsfw : Bool?
  integration_types : Array[@model.ApplicationIntegrationType]?
  contexts : Array[@model.InteractionContextType]?
} derive(Debug)

///|
/// Describe a CHAT_INPUT (slash) command.
pub fn CommandSpec::slash(
  name : String,
  description : String,
  options? : Array[@model.CommandOption] = [],
  default_member_permissions? : @model.Permissions,
  nsfw? : Bool,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> CommandSpec {
  {
    name,
    name_localizations,
    description,
    description_localizations,
    typ: ChatInput,
    options,
    default_member_permissions,
    nsfw,
    integration_types,
    contexts,
  }
}

///|
/// Describe a USER context-menu command (no description, no options).
pub fn CommandSpec::user(
  name : String,
  default_member_permissions? : @model.Permissions,
  nsfw? : Bool,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
  name_localizations? : Map[String, String],
) -> CommandSpec {
  {
    name,
    name_localizations,
    description: "",
    description_localizations: None,
    typ: User,
    options: [],
    default_member_permissions,
    nsfw,
    integration_types,
    contexts,
  }
}

///|
/// Describe a MESSAGE context-menu command (no description, no options).
pub fn CommandSpec::message(
  name : String,
  default_member_permissions? : @model.Permissions,
  nsfw? : Bool,
  integration_types? : Array[@model.ApplicationIntegrationType],
  contexts? : Array[@model.InteractionContextType],
  name_localizations? : Map[String, String],
) -> CommandSpec {
  {
    name,
    name_localizations,
    description: "",
    description_localizations: None,
    typ: Message,
    options: [],
    default_member_permissions,
    nsfw,
    integration_types,
    contexts,
  }
}

///|
/// The command registration payload, omitting fields left at their
/// defaults so command-sync diffs stay minimal.
pub impl ToJson for CommandSpec with fn to_json(self) {
  let builder = @model.ObjBuilder()
    .field("name", self.name)
    .opt("name_localizations", self.name_localizations)
    .field("description", self.description)
    .opt("description_localizations", self.description_localizations)
  if self.typ != ChatInput {
    builder.field("type", self.typ) |> ignore
  }
  if self.options.length() > 0 {
    builder.field("options", self.options) |> ignore
  }
  builder
  .opt("default_member_permissions", self.default_member_permissions)
  .opt("nsfw", self.nsfw)
  .opt("integration_types", self.integration_types)
  .opt("contexts", self.contexts)
  .build()
}
