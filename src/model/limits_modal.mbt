///|
/// The limits Discord documents for a modal: its title, its top-level
/// component count, and every component it carries.
pub fn modal_limit_violations(
  title~ : String,
  components~ : Array[Component],
) -> Array[LimitViolation] {
  let checker = LimitChecker::new()
  checker.text("title", Some(title), max=45)
  checker.count("components", Some(components.length()), min=1, max=5)
  for index, component in components {
    checker.modal_component("components[\{index}]", component)
  }
  checker.violations
}

///|
/// Discord's upper bound for a text input's `min_length`, `max_length`, and
/// `value`, in UTF-16 units.
pub let text_input_max_length : Int = 4000

///|
fn LimitChecker::modal_component(
  self : LimitChecker,
  path : String,
  component : Component,
) -> Unit {
  match component {
    ActionRow(row) =>
      for index, child in row.components {
        self.modal_component("\{path}.components[\{index}]", child)
      }
    Label(label) => {
      let custom_id = component_custom_id(label.component)
      self.text("\{path}.label", label.label, max=45, custom_id?)
      self.text("\{path}.description", label.description, max=100, custom_id?)
      self.modal_component("\{path}.component", label.component)
    }
    TextInput(input) => {
      let custom_id = input.custom_id
      self.text(
        "\{path}.custom_id",
        Some(custom_id),
        min=1,
        max=100,
        custom_id~,
      )
      self.count(
        "\{path}.min_length",
        input.min_length,
        min=0,
        max=text_input_max_length,
        custom_id~,
      )
      self.count(
        "\{path}.max_length",
        input.max_length,
        min=1,
        max=text_input_max_length,
        custom_id~,
      )
      self.ordered(
        "\{path}.min_length",
        input.min_length,
        input.max_length,
        custom_id~,
      )
      self.text(
        "\{path}.value",
        input.value,
        max=text_input_max_length,
        custom_id~,
      )
      self.text("\{path}.placeholder", input.placeholder, max=100, custom_id~)
    }
    StringSelect(select) =>
      self.select_component(path, select, string_select=true)
    UserSelect(select)
    | RoleSelect(select)
    | MentionableSelect(select)
    | ChannelSelect(select) =>
      self.select_component(path, select, string_select=false)
    FileUpload(upload) => {
      let custom_id = upload.custom_id
      self.text(
        "\{path}.custom_id",
        Some(custom_id),
        min=1,
        max=100,
        custom_id~,
      )
      self.count(
        "\{path}.min_values",
        upload.min_values,
        min=0,
        max=10,
        custom_id~,
      )
      self.count(
        "\{path}.max_values",
        upload.max_values,
        min=0,
        max=10,
        custom_id~,
      )
      self.ordered(
        "\{path}.min_values",
        upload.min_values,
        upload.max_values,
        custom_id~,
      )
      self.count(
        "\{path}.file_types",
        upload.file_types.map(types => types.length()),
        min=0,
        max=10,
        custom_id~,
      )
    }
    RadioGroup(group) => {
      let custom_id = group.custom_id
      self.text(
        "\{path}.custom_id",
        Some(custom_id),
        min=1,
        max=100,
        custom_id~,
      )
      self.count(
        "\{path}.options",
        Some(group.options.length()),
        min=2,
        max=10,
        custom_id~,
      )
      self.radio_options(path, group.options, custom_id~)
    }
    CheckboxGroup(group) => {
      let custom_id = group.custom_id
      self.text(
        "\{path}.custom_id",
        Some(custom_id),
        min=1,
        max=100,
        custom_id~,
      )
      self.count(
        "\{path}.options",
        Some(group.options.length()),
        min=1,
        max=10,
        custom_id~,
      )
      self.count(
        "\{path}.min_values",
        group.min_values,
        min=if group.required == Some(false) { 0 } else { 1 },
        max=10,
        custom_id~,
      )
      self.count(
        "\{path}.max_values",
        group.max_values,
        min=1,
        max=10,
        custom_id~,
      )
      self.ordered(
        "\{path}.min_values",
        group.min_values,
        group.max_values,
        custom_id~,
      )
      self.radio_options(path, group.options, custom_id~)
    }
    Checkbox(checkbox) =>
      self.text(
        "\{path}.custom_id",
        Some(checkbox.custom_id),
        min=1,
        max=100,
        custom_id=checkbox.custom_id,
      )
    // The reference gives Text Display no content length limit.
    TextDisplay(_) => ()
    _ => ()
  }
}

///|
fn LimitChecker::radio_options(
  self : LimitChecker,
  path : String,
  options : Array[RadioOption],
  custom_id~ : String,
) -> Unit {
  for index, option in options {
    let path = "\{path}.options[\{index}]"
    self.text("\{path}.label", Some(option.label), max=100, custom_id~)
    self.text("\{path}.value", Some(option.value), max=100, custom_id~)
    self.text("\{path}.description", option.description, max=100, custom_id~)
  }
}

///|
/// The custom id of an interactive component, if it has one.
fn component_custom_id(component : Component) -> String? {
  match component {
    Button({ custom_id, .. }) => custom_id
    StringSelect({ custom_id, .. })
    | UserSelect({ custom_id, .. })
    | RoleSelect({ custom_id, .. })
    | MentionableSelect({ custom_id, .. })
    | ChannelSelect({ custom_id, .. }) => Some(custom_id)
    TextInput({ custom_id, .. }) => Some(custom_id)
    FileUpload({ custom_id, .. }) => Some(custom_id)
    RadioGroup({ custom_id, .. }) => Some(custom_id)
    CheckboxGroup({ custom_id, .. }) => Some(custom_id)
    Checkbox({ custom_id, .. }) => Some(custom_id)
    _ => None
  }
}
