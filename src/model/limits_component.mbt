///|
/// The limits Discord documents for the components of one message, for both
/// action-row layouts and Components V2.
pub fn message_component_limit_violations(
  components : Array[Component],
) -> Array[LimitViolation] {
  let checker = LimitChecker::new()
  if !requires_components_v2(components) {
    let rows = components.filter(component => component is ActionRow(_))
    checker.count("components", Some(rows.length()), min=0, max=5)
  }
  let mut total = 0
  for index, component in components {
    total += checker.message_component("components[\{index}]", component)
  }
  if requires_components_v2(components) && total > 40 {
    checker.report(
      "components",
      "\{total} total components including nested components (at most 40)",
    )
  }
  checker.violations
}

///|
fn LimitChecker::message_component(
  self : LimitChecker,
  path : String,
  component : Component,
) -> Int {
  let mut total = 1
  match component {
    Unknown(_) => return 0
    ActionRow(row) => {
      let mut buttons = 0
      let mut selects = 0
      for child in row.components {
        match child {
          Button(_) => buttons += 1
          StringSelect(_)
          | UserSelect(_)
          | RoleSelect(_)
          | MentionableSelect(_)
          | ChannelSelect(_) => selects += 1
          _ => ()
        }
      }
      self.count(
        "\{path}.components",
        Some(buttons + selects),
        min=0,
        max=if selects > 0 { 1 } else { 5 },
      )
      for index, child in row.components {
        total += self.message_component("\{path}.components[\{index}]", child)
      }
    }
    Button(button) => {
      let custom_id = button.custom_id
      self.text("\{path}.label", button.label, max=80, custom_id?)
      self.text("\{path}.custom_id", custom_id, min=1, max=100, custom_id?)
      self.text("\{path}.url", button.url, max=512, custom_id?)
    }
    StringSelect(select) =>
      self.select_component(path, select, string_select=true)
    UserSelect(select)
    | RoleSelect(select)
    | MentionableSelect(select)
    | ChannelSelect(select) =>
      self.select_component(path, select, string_select=false)
    Section(section) => {
      self.count(
        "\{path}.components",
        Some(section.components.length()),
        min=1,
        max=3,
      )
      for index, child in section.components {
        total += self.message_component("\{path}.components[\{index}]", child)
      }
      total += self.message_component("\{path}.accessory", section.accessory)
    }
    Thumbnail(thumbnail) =>
      self.text(
        "\{path}.description",
        thumbnail.description.bind(value => value.to_option()),
        max=1024,
      )
    MediaGallery(gallery) => {
      self.count("\{path}.items", Some(gallery.items.length()), min=1, max=10)
      for index, item in gallery.items {
        self.text(
          "\{path}.items[\{index}].description",
          item.description.bind(value => value.to_option()),
          max=1024,
        )
      }
    }
    Separator(separator) =>
      self.count("\{path}.spacing", separator.spacing, min=1, max=2)
    Container(container) => {
      self.count(
        "\{path}.accent_color",
        container.accent_color.bind(value => value.to_option()),
        min=0,
        max=0xFFFFFF,
      )
      for index, child in container.components {
        total += self.message_component("\{path}.components[\{index}]", child)
      }
    }
    Label(label) =>
      total += self.message_component("\{path}.component", label.component)
    _ => ()
  }
  total
}

///|
/// The select limits are the same in messages and modals.
fn LimitChecker::select_component(
  self : LimitChecker,
  path : String,
  select : SelectMenu,
  string_select~ : Bool,
) -> Unit {
  let custom_id = select.custom_id
  self.text("\{path}.custom_id", Some(custom_id), min=1, max=100, custom_id~)
  if string_select {
    self.count(
      "\{path}.options",
      select.options.map(options => options.length()),
      min=0,
      max=25,
      custom_id~,
    )
  }
  self.text("\{path}.placeholder", select.placeholder, max=150, custom_id~)
  self.count("\{path}.min_values", select.min_values, min=0, max=25, custom_id~)
  self.count("\{path}.max_values", select.max_values, min=0, max=25, custom_id~)
  self.ordered(
    "\{path}.min_values",
    select.min_values,
    select.max_values,
    custom_id~,
  )
  if string_select {
    if select.options is Some(options) {
      for index, option in options {
        let path = "\{path}.options[\{index}]"
        self.text("\{path}.label", Some(option.label), max=100, custom_id~)
        self.text("\{path}.value", Some(option.value), max=100, custom_id~)
        self.text(
          "\{path}.description",
          option.description,
          max=100,
          custom_id~,
        )
      }
    }
  } else if select.default_values is Some(values) && !values.is_empty() {
    // An empty list preselects nothing, like an omitted one.
    self.count(
      "\{path}.default_values",
      Some(values.length()),
      min=select.min_values.unwrap_or(1),
      max=select.max_values.unwrap_or(1),
      custom_id~,
    )
  }
}
