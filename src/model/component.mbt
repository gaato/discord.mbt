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
  Section(Section)
  TextDisplay(TextDisplay)
  Thumbnail(Thumbnail)
  MediaGallery(MediaGallery)
  File(FileComponent)
  Separator(Separator)
  Container(Container)
  Label(Label)
  FileUpload(FileUpload)
  RadioGroup(RadioGroup)
  CheckboxGroup(CheckboxGroup)
  Checkbox(Checkbox)
  Unknown(Json)
} derive(Debug)

///|
/// Whether any top-level component requires Discord's Components V2 message
/// flag.
///
/// ```mbt check
/// test "detect top-level Components V2 layouts" {
///   let row : @model.Component = ActionRow({ id: None, components: [], })
///   let container : @model.Component = Container({
///     id: None,
///     components: [],
///     accent_color: None,
///     spoiler: None,
///   })
///   assert_false(@model.requires_components_v2([row]))
///   assert_true(@model.requires_components_v2([row, container]))
/// }
/// ```
pub fn requires_components_v2(components : Array[Component]) -> Bool {
  components.any(component => {
    match component {
      Section(_)
      | TextDisplay(_)
      | MediaGallery(_)
      | File(_)
      | Separator(_)
      | Container(_) => true
      _ => false
    }
  })
}

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
    ActionRow(value) => component_payload(ToJson::to_json(value), 1)
    Button(value) => component_payload(ToJson::to_json(value), 2)
    StringSelect(value) => component_payload(ToJson::to_json(value), 3)
    TextInput(value) => component_payload(ToJson::to_json(value), 4)
    UserSelect(value) => component_payload(ToJson::to_json(value), 5)
    RoleSelect(value) => component_payload(ToJson::to_json(value), 6)
    MentionableSelect(value) => component_payload(ToJson::to_json(value), 7)
    ChannelSelect(value) => component_payload(ToJson::to_json(value), 8)
    Section(value) => component_payload(ToJson::to_json(value), 9)
    TextDisplay(value) => component_payload(ToJson::to_json(value), 10)
    Thumbnail(value) => component_payload(ToJson::to_json(value), 11)
    MediaGallery(value) => component_payload(ToJson::to_json(value), 12)
    File(value) => component_payload(ToJson::to_json(value), 13)
    Separator(value) => component_payload(ToJson::to_json(value), 14)
    Container(value) => component_payload(ToJson::to_json(value), 17)
    Label(value) => component_payload(ToJson::to_json(value), 18)
    FileUpload(value) => component_payload(ToJson::to_json(value), 19)
    RadioGroup(value) => component_payload(ToJson::to_json(value), 21)
    CheckboxGroup(value) => component_payload(ToJson::to_json(value), 22)
    Checkbox(value) => component_payload(ToJson::to_json(value), 23)
    Unknown(value) => value
  }
}

///|
pub impl @json.FromJson for Component with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected a component (object)"))
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
        9 => Section(@json.from_json(json, path~))
        10 => TextDisplay(@json.from_json(json, path~))
        11 => Thumbnail(@json.from_json(json, path~))
        12 => MediaGallery(@json.from_json(json, path~))
        13 => File(@json.from_json(json, path~))
        14 => Separator(@json.from_json(json, path~))
        17 => Container(@json.from_json(json, path~))
        18 => Label(@json.from_json(json, path~))
        19 => FileUpload(@json.from_json(json, path~))
        21 => RadioGroup(@json.from_json(json, path~))
        22 => CheckboxGroup(@json.from_json(json, path~))
        23 => Checkbox(@json.from_json(json, path~))
        _ => Unknown(json)
      }
    _ => Unknown(json)
  }
}

///|
/// A layout row containing nested interactive components.
pub(all) struct ActionRow {
  id : Int?
  components : Array[Component]
} derive(ToJson, FromJson, Debug)

///|
/// A clickable button component.
pub(all) struct Button {
  id : Int?
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
    _ => raise JsonDecodeError((path, "expected a button style (number)"))
  }
}

///|
/// A text or auto-populated select menu component.
pub(all) struct SelectMenu {
  id : Int?
  custom_id : String
  placeholder : String?
  min_values : Int?
  max_values : Int?
  disabled : Bool?
  options : Array[SelectOption]?
  channel_types : Array[ChannelType]?
  default_values : Array[SelectDefaultValue]?
  values : Array[String]?
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
/// A section containing text components and a button or thumbnail accessory.
pub(all) struct Section {
  id : Int?
  components : Array[Component]
  accessory : Component
} derive(ToJson, FromJson, Debug)

///|
/// A markdown text block displayed in a Components v2 layout.
pub(all) struct TextDisplay {
  id : Int?
  content : String
} derive(ToJson, FromJson, Debug)

///|
/// A thumbnail accessory rendered from an unfurled media item.
pub(all) struct Thumbnail {
  id : Int?
  media : UnfurledMediaItem
  description : Nullable[String]?
  spoiler : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// A gallery containing one to ten media items.
pub(all) struct MediaGallery {
  id : Int?
  items : Array[MediaGalleryItem]
} derive(ToJson, FromJson, Debug)

///|
/// One item in a media gallery.
pub(all) struct MediaGalleryItem {
  media : UnfurledMediaItem
  description : Nullable[String]?
  spoiler : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// A file attachment rendered as a Components v2 file component.
pub(all) struct FileComponent {
  id : Int?
  file : UnfurledMediaItem
  spoiler : Bool?
  name : String?
  size : Int?
} derive(ToJson, FromJson, Debug)

///|
/// A visual separator between Components v2 content blocks.
pub(all) struct Separator {
  id : Int?
  divider : Bool?
  spacing : Int?
} derive(ToJson, FromJson, Debug)

///|
/// A Components v2 container with an optional accent color.
pub(all) struct Container {
  id : Int?
  components : Array[Component]
  accent_color : Nullable[Int]?
  spoiler : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// A modal label wrapping one interactive component.
pub(all) struct Label {
  id : Int?
  // Required when sending a modal; omitted in modal-submit payloads.
  label : String?
  description : String?
  component : Component
} derive(ToJson, FromJson, Debug)

///|
/// A modal file upload component.
pub(all) struct FileUpload {
  id : Int?
  custom_id : String
  min_values : Int?
  max_values : Int?
  required : Bool?
  values : Array[String]?
  file_types : Array[FileTypeFilter]?
} derive(ToJson, FromJson, Debug)

///|
/// A modal radio group accepting one option.
pub(all) struct RadioGroup {
  id : Int?
  custom_id : String
  options : Array[RadioOption]
  required : Bool?
  value : String?
} derive(ToJson, FromJson, Debug)

///|
/// A selectable option shared by radio and checkbox groups.
pub(all) struct RadioOption {
  value : String
  label : String
  description : String?
  default : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// A modal checkbox group accepting zero or more options.
pub(all) struct CheckboxGroup {
  id : Int?
  custom_id : String
  options : Array[RadioOption]
  min_values : Int?
  max_values : Int?
  required : Bool?
  values : Array[String]?
} derive(ToJson, FromJson, Debug)

///|
/// A single modal checkbox.
pub(all) struct Checkbox {
  id : Int?
  custom_id : String
  default : Bool?
  value : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// Media metadata used by thumbnail, gallery, and file components.
pub(all) struct UnfurledMediaItem {
  url : String
  proxy_url : String?
  height : Nullable[Int]?
  width : Nullable[Int]?
  placeholder : String?
  placeholder_version : Int?
  content_type : String?
  flags : Int?
  attachment_id : String?
} derive(ToJson, FromJson, Debug)

///|
/// A free-form text input component used in a modal.
pub(all) struct TextInput {
  id : Int?
  custom_id : String
  // Required when sending a modal; omitted in modal-submit payloads.
  style : TextInputStyle?
  label : String?
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
    _ => raise JsonDecodeError((path, "expected a text input style (number)"))
  }
}
