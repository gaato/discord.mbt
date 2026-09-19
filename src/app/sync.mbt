///|
/// Defaults that Discord may add to or omit from response objects.
fn object_defaults(command_root : Bool) -> Array[(String, Json)] {
  let defaults = [
    ("required", Json::boolean(false)),
    ("options", Json::array([])),
    ("choices", Json::array([])),
  ]
  if command_root {
    defaults.push(("type", Json::number(1.0)))
    defaults.push(("nsfw", Json::boolean(false)))
    defaults.push(("dm_permission", Json::boolean(true)))
    defaults.push(("integration_types", Json::array([Json::number(0.0)])))
    defaults.push(("contexts", Json::null()))
    defaults.push(("default_member_permissions", Json::null()))
  }
  defaults
}

///|
fn object_default(key : String, command_root : Bool) -> Json? {
  for entry in object_defaults(command_root) {
    let (candidate, value) = entry
    if candidate == key {
      return Some(value)
    }
  }
  None
}

///|
/// Command fields Discord stores as sets: it may echo them in any order
/// (observed live for `file_types`), so they compare as multisets. Options
/// and choices stay order-sensitive because their order is user-visible.
fn unordered_key(key : String) -> Bool {
  key is ("file_types" | "channel_types" | "contexts" | "integration_types")
}

///|
fn same_elements(expected : Array[Json], actual : Array[Json]) -> Bool {
  if expected.length() != actual.length() {
    return false
  }
  let used = Array::make(actual.length(), false)
  for value in expected {
    let mut matched = false
    for i, other in actual {
      if !used[i] && declared_json_matches_at(value, other, false) {
        used[i] = true
        matched = true
        break
      }
    }
    if !matched {
      return false
    }
  }
  true
}

///|
fn declared_value_matches(
  key : String,
  declared : Json,
  fetched : Json,
) -> Bool {
  match (declared, fetched) {
    (Array(expected), Array(actual)) if unordered_key(key) =>
      same_elements(expected, actual)
    _ => declared_json_matches_at(declared, fetched, false)
  }
}

///|
/// Compare one declared JSON subtree with the corresponding Discord value.
/// Discord may add fields to response objects; only keys emitted by the
/// declaration and known declaration defaults participate in equality.
fn declared_json_matches_at(
  declared : Json,
  fetched : Json,
  command_root : Bool,
) -> Bool {
  match (declared, fetched) {
    (Object(expected), Object(actual)) => {
      for key, value in expected {
        match actual.get(key) {
          Some(other) =>
            if !declared_value_matches(key, value, other) {
              return false
            }
          None => {
            guard object_default(key, command_root) is Some(fallback) else {
              return false
            }
            if !declared_value_matches(key, value, fallback) {
              return false
            }
          }
        }
      }
      for entry in object_defaults(command_root) {
        let (key, fallback) = entry
        if !expected.contains(key) &&
          actual.get(key) is Some(value) &&
          !declared_value_matches(key, fallback, value) {
          return false
        }
      }
      true
    }
    (Array(expected), Array(actual)) => {
      if expected.length() != actual.length() {
        return false
      }
      for i, value in expected {
        if !declared_json_matches_at(value, actual[i], false) {
          return false
        }
      }
      true
    }
    _ => declared == fetched
  }
}

///|
fn declared_json_matches(declared : Json, fetched : Json) -> Bool {
  declared_json_matches_at(declared, fetched, true)
}

///|
fn command_key(typ : @model.ApplicationCommandType, name : String) -> String {
  "\{typ.to_int()}:\{name}"
}

///|
/// Whether Discord's registered commands already match the declarations.
///
/// Command `(type, name)` pairs must form the same set. For each command,
/// comparison follows the declaration shape recursively, ignoring server-owned
/// fields such as ids and versions while preserving option and choice order;
/// set-valued fields (`file_types`, `channel_types`, `contexts`,
/// `integration_types`) match in any order.
pub fn commands_in_sync(
  declared : Array[@interaction.CommandSpec],
  fetched : Array[@model.ApplicationCommand],
) -> Bool {
  if declared.length() != fetched.length() {
    return false
  }
  let by_key : Map[String, @model.ApplicationCommand] = Map([])
  for command in fetched {
    let typ = command.typ.unwrap_or(ChatInput)
    let key = command_key(typ, command.name)
    if by_key.contains(key) {
      return false
    }
    by_key[key] = command
  }
  let declared_keys : Set[String] = Set([])
  for spec in declared {
    let key = command_key(spec.typ, spec.name)
    if declared_keys.contains(key) {
      return false
    }
    declared_keys.add(key)
    guard by_key.get(key) is Some(command) else { return false }
    if !declared_json_matches(spec.to_json(), command.to_json()) {
      return false
    }
  }
  true
}

///|
fn command_payload(specs : Array[@interaction.CommandSpec]) -> Json {
  Json::array(specs.map(spec => spec.to_json()))
}

///|
async fn sync_global_commands(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  specs : Array[@interaction.CommandSpec],
) -> Unit {
  let fetched = client.get_global_commands(
    application_id,
    with_localizations=true,
  )
  if !commands_in_sync(specs, fetched) {
    client.bulk_overwrite_global_commands(
      application_id,
      command_payload(specs),
    )
    |> ignore
  }
}

///|
async fn sync_guild_commands(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  guild_id : @model.GuildId,
  specs : Array[@interaction.CommandSpec],
) -> Unit {
  let fetched = client.get_guild_commands(
    application_id,
    guild_id,
    with_localizations=true,
  )
  if !commands_in_sync(specs, fetched) {
    client.bulk_overwrite_guild_commands(
      application_id,
      guild_id,
      command_payload(specs),
    )
    |> ignore
  }
}
