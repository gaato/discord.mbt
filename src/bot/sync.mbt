///|
/// Compare one declared JSON subtree with the corresponding Discord value.
/// Discord may add fields to response objects; only keys emitted by the
/// declaration participate in equality. The three optional container/value
/// fields below are normalized because Discord commonly omits their defaults.
fn declared_json_matches(declared : Json, fetched : Json) -> Bool {
  match (declared, fetched) {
    (Object(expected), Object(actual)) => {
      for key, value in expected {
        match actual.get(key) {
          Some(other) =>
            if !declared_json_matches(value, other) {
              return false
            }
          None =>
            if !((key == "required" && value == Json::boolean(false)) ||
              (
                (key == "options" || key == "choices") &&
                value == Json::array([])
              )) {
              return false
            }
        }
      }
      // These are declaration-owned fields even when their default is omitted
      // from CommandSpec JSON, so fetched non-default values must not be
      // mistaken for harmless server metadata.
      for
        entry in [
          ("required", Json::boolean(false)),
          ("options", Json::array([])),
          ("choices", Json::array([])),
        ] {
        let (key, fallback) = entry
        if !expected.contains(key) &&
          actual.get(key) is Some(value) &&
          !declared_json_matches(fallback, value) {
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
        if !declared_json_matches(value, actual[i]) {
          return false
        }
      }
      true
    }
    _ => declared == fetched
  }
}

///|
/// Whether Discord's registered commands already match the declarations.
///
/// Command names must form the same set. For each command, comparison follows
/// the declaration shape recursively, ignoring server-owned fields such as
/// ids and versions while preserving option and choice order.
pub fn commands_in_sync(
  declared : Array[@interaction.CommandSpec],
  fetched : Array[@model.ApplicationCommand],
) -> Bool {
  if declared.length() != fetched.length() {
    return false
  }
  let by_name : Map[String, @model.ApplicationCommand] = {}
  for command in fetched {
    if by_name.contains(command.name) {
      return false
    }
    by_name[command.name] = command
  }
  let declared_names : Set[String] = Set([])
  for spec in declared {
    if declared_names.contains(spec.name) {
      return false
    }
    declared_names.add(spec.name)
    guard by_name.get(spec.name) is Some(command) else { return false }
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
  let fetched = client.get_global_commands(application_id)
  if commands_in_sync(specs, fetched) {
    println("commands in sync, skipping PUT")
  } else {
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
  let fetched = client.get_guild_commands(application_id, guild_id)
  if commands_in_sync(specs, fetched) {
    println("commands in sync, skipping PUT")
  } else {
    client.bulk_overwrite_guild_commands(
      application_id,
      guild_id,
      command_payload(specs),
    )
    |> ignore
  }
}
