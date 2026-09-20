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
/// Keys whose omitted value Discord derives from state the client cannot see.
/// An omitted `integration_types` becomes the app's supported installation
/// contexts at creation time (`[0]`, or `[0, 1]` once user installs are
/// enabled — observed live), so an undeclared one matches whatever Discord
/// echoes. A declared one is still compared, with an absent echo read as `[0]`.
fn server_derived_default(key : String) -> Bool {
  key == "integration_types"
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
          !server_derived_default(key) &&
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
/// What to do with undeclared remote commands. Entry points are always kept.
pub(all) enum UnownedCommands {
  Delete
  Keep
} derive(Debug, Eq)

///|
/// Changes in one scope. Slash commands use plain names; other commands use
/// `<type int>:<name>`. `None` identifies the global scope.
pub(all) struct ScopeSyncReport {
  guild_id : @model.GuildId?
  created : Array[String]
  updated : Array[String]
  deleted : Array[String]
  unchanged : Array[String]
  preserved : Array[String]
  overwritten : Bool
} derive(Debug)

///|
fn remote_command_identity(
  command : Json,
) -> (@model.ApplicationCommandType, String) {
  let typ = match command {
    { "type": Number(value, ..), .. } =>
      @model.ApplicationCommandType::from_int(value.to_int())
    _ => @model.ApplicationCommandType::ChatInput
  }
  let name = match command {
    { "name": String(value), .. } => value
    _ => ""
  }
  (typ, name)
}

///|
fn command_name(typ : @model.ApplicationCommandType, name : String) -> String {
  if typ.to_int() == 1 {
    name
  } else {
    command_key(typ, name)
  }
}

///|
fn preserved_command(command : Json) -> Json {
  guard command is Object(fields) else { return command }
  let payload : Map[String, Json] = Map([])
  for key, value in fields {
    if !(key
      is ("application_id"
      | "version"
      | "guild_id"
      | "name_localized"
      | "description_localized")) {
      payload[key] = value
    }
  }
  Json::object(payload)
}

///|
/// Plan a bulk overwrite from raw list-endpoint objects without mutating them.
/// Entry points and, under `Keep`, other undeclared commands retain their ids
/// and unknown fields. A matching catalog needs no PUT; duplicate remote keys
/// force one. The payload follows declaration order, then preserved remote order.
///
/// ```mbt check
/// test {
///   let (payload, report) = @framework.plan_command_sync([], [], unowned=Keep)
///   assert_true(payload is None)
///   assert_false(report.overwritten)
/// }
/// ```
pub fn plan_command_sync(
  declared : Array[@interaction.CommandSpec],
  fetched : Array[Json],
  unowned~ : UnownedCommands,
  guild_id? : @model.GuildId,
) -> (Json?, ScopeSyncReport) {
  let by_key : Map[String, Json] = Map([])
  let mut duplicate = false
  for command in fetched {
    let (typ, name) = remote_command_identity(command)
    let key = command_key(typ, name)
    if by_key.contains(key) {
      duplicate = true
    }
    by_key[key] = command
  }
  let created = []
  let updated = []
  let deleted = []
  let unchanged = []
  let preserved = []
  let payload = []
  let declared_keys : Set[String] = Set([])
  for spec in declared {
    let key = command_key(spec.typ, spec.name)
    declared_keys.add(key)
    let name = command_name(spec.typ, spec.name)
    let json = spec.to_json()
    payload.push(json)
    match by_key.get(key) {
      None => created.push(name)
      Some(command) =>
        if declared_json_matches(json, command) {
          unchanged.push(name)
        } else {
          updated.push(name)
        }
    }
  }
  for command in fetched {
    let (typ, name) = remote_command_identity(command)
    if !declared_keys.contains(command_key(typ, name)) {
      let name = command_name(typ, name)
      if typ is PrimaryEntryPoint || unowned is Keep {
        preserved.push(name)
        payload.push(preserved_command(command))
      } else {
        deleted.push(name)
      }
    }
  }
  let overwritten = duplicate ||
    !created.is_empty() ||
    !updated.is_empty() ||
    !deleted.is_empty()
  (
    if overwritten {
      Some(Json::array(payload))
    } else {
      None
    },
    { guild_id, created, updated, deleted, unchanged, preserved, overwritten, },
  )
}

///|
/// Fetch raw commands with localizations, plan changes, and overwrite only
/// when needed. Failures propagate without returning a successful report.
pub async fn sync_command_scope(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  declared : Array[@interaction.CommandSpec],
  unowned? : UnownedCommands = Delete,
  guild_id? : @model.GuildId,
) -> ScopeSyncReport {
  let fetched = match guild_id {
    None =>
      client.get_global_commands_raw(application_id, with_localizations=true)
    Some(guild_id) =>
      client.get_guild_commands_raw(
        application_id,
        guild_id,
        with_localizations=true,
      )
  }
  let (payload, report) = plan_command_sync(
    declared,
    fetched,
    unowned~,
    guild_id?,
  )
  if payload is Some(body) {
    let route = match guild_id {
      None => @dhttp.Route::BulkOverwriteGlobalCommands(application_id~)
      Some(guild_id) =>
        @dhttp.Route::BulkOverwriteGuildCommands(application_id~, guild_id~)
    }
    client.request(route, body~) |> ignore
  }
  report
}
