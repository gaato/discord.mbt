///|
/// A Discord message component dispatched by its numeric wire discriminator.
pub(all) enum Component {
  ActionRow(ActionRow)
  Button(Button)
  StringSelect(SelectMenu)
  TextInput(TextInput)
  UserSelect(SelectMenu)
  RoleSelect(SelectMenu)
  MentionableSelect(SelectMenu)
  ChannelSelect(SelectMenu)
  Unknown(Json)
  // TODO(components-v2): Port component payloads with type values 9 through 17.
} derive(Debug)

///|
fn component_payload(payload : Json, typ : Int) -> Json {
  match payload {
    Object(fields) => {
      fields["type"] = Json::number(typ.to_double())
      Json::object(fields)
    }
    value => value
  }
}

///|
pub impl ToJson for Component with fn to_json(self) {
  match self {
    ActionRow(value) => component_payload(value.to_json(), 1)
    Button(value) => component_payload(value.to_json(), 2)
    StringSelect(value) => component_payload(value.to_json(), 3)
    TextInput(value) => component_payload(value.to_json(), 4)
    UserSelect(value) => component_payload(value.to_json(), 5)
    RoleSelect(value) => component_payload(value.to_json(), 6)
    MentionableSelect(value) => component_payload(value.to_json(), 7)
    ChannelSelect(value) => component_payload(value.to_json(), 8)
    Unknown(value) => value
  }
}

///|
pub impl @json.FromJson for Component with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected a component (object)"))
  }
  match fields.get("type") {
    Some(Number(value, ..)) =>
      match value.to_int() {
        1 => ActionRow(@json.from_json(json, path~))
        2 => Button(@json.from_json(json, path~))
        3 => StringSelect(@json.from_json(json, path~))
        4 => TextInput(@json.from_json(json, path~))
        5 => UserSelect(@json.from_json(json, path~))
        6 => RoleSelect(@json.from_json(json, path~))
        7 => MentionableSelect(@json.from_json(json, path~))
        8 => ChannelSelect(@json.from_json(json, path~))
        _ => Unknown(json)
      }
    _ => Unknown(json)
  }
}

///|
/// A layout row containing nested interactive components.
pub(all) struct ActionRow {
  components : Array[Component]
} derive(ToJson, FromJson, Debug)

///|
/// A clickable button component.
pub(all) struct Button {
  style : ButtonStyle
  label : String?
  emoji : Emoji?
  custom_id : String?
  sku_id : SkuId?
  url : String?
  disabled : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// The visual and behavioral style of a button.
pub(all) enum ButtonStyle {
  Primary
  Secondary
  Success
  Danger
  Link
  Premium
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ButtonStyle::to_int(self : ButtonStyle) -> Int {
  match self {
    Primary => 1
    Secondary => 2
    Success => 3
    Danger => 4
    Link => 5
    Premium => 6
    Unknown(value) => value
  }
}

///|
pub fn ButtonStyle::from_int(value : Int) -> ButtonStyle {
  match value {
    1 => Primary
    2 => Secondary
    3 => Success
    4 => Danger
    5 => Link
    6 => Premium
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ButtonStyle with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ButtonStyle with fn from_json(json, path) {
  match json {
    Number(value, ..) => ButtonStyle::from_int(value.to_int())
    _ => raise @json.JsonDecodeError((path, "expected a button style (number)"))
  }
}

///|
/// A text or auto-populated select menu component.
pub(all) struct SelectMenu {
  custom_id : String
  placeholder : String?
  min_values : Int?
  max_values : Int?
  disabled : Bool?
  options : Array[SelectOption]?
  channel_types : Array[ChannelType]?
  default_values : Array[SelectDefaultValue]?
} derive(ToJson, FromJson, Debug)

///|
/// A selectable option in a string select menu.
pub(all) struct SelectOption {
  label : String
  value : String
  description : String?
  emoji : Emoji?
  default : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// A preselected entity in an auto-populated select menu.
pub(all) struct SelectDefaultValue {
  id : GenericId
  typ : String
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// A free-form text input component used in a modal.
pub(all) struct TextInput {
  custom_id : String
  style : TextInputStyle
  label : String
  min_length : Int?
  max_length : Int?
  required : Bool?
  value : String?
  placeholder : String?
} derive(ToJson, FromJson, Debug)

///|
/// The single-line or multi-line style of a text input.
pub(all) enum TextInputStyle {
  Short
  Paragraph
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn TextInputStyle::to_int(self : TextInputStyle) -> Int {
  match self {
    Short => 1
    Paragraph => 2
    Unknown(value) => value
  }
}

///|
pub fn TextInputStyle::from_int(value : Int) -> TextInputStyle {
  match value {
    1 => Short
    2 => Paragraph
    value => Unknown(value)
  }
}

///|
pub impl ToJson for TextInputStyle with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for TextInputStyle with fn from_json(json, path) {
  match json {
    Number(value, ..) => TextInputStyle::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected a text input style (number)"),
      )
  }
}
