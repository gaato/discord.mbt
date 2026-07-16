///|
fn command_options(fixture : String) -> @interaction.CommandOptions raise {
  let data : @model.CommandData = @json.from_json(@json.parse(fixture))
  @interaction.CommandOptions::from_data(data)
}

///|
test "slash command registration payload includes every scalar option kind" {
  let spec = @interaction.CommandSpec::slash(
    "configure",
    "Configure the bot",
    options=[
      @interaction.string_option(
        "mode",
        "Operating mode",
        required=true,
        choices=[
          @interaction.string_choice("Fast", "fast"),
          @interaction.string_choice("Safe", "safe"),
        ],
        min_length=1,
        max_length=16,
      ),
      @interaction.integer_option(
        "retries",
        "Retry count",
        required=true,
        choices=[
          @interaction.int_choice("Once", 1L),
          @interaction.int_choice("Three times", 3L),
        ],
        min_value=0L,
        max_value=10L,
      ),
      @interaction.number_option(
        "threshold",
        "Alert threshold",
        choices=[
          @interaction.number_choice("Low", 0.25),
          @interaction.number_choice("High", 0.75),
        ],
        min_value=0.0,
        max_value=1.0,
        autocomplete=false,
      ),
      @interaction.boolean_option("enabled", "Enable alerts", required=true),
      @interaction.user_option("owner", "Configuration owner"),
      @interaction.channel_option(
        "channel",
        "Alert destination",
        required=true,
        channel_types=[GuildText, GuildAnnouncement],
      ),
      @interaction.role_option("role", "Role to notify"),
      @interaction.mentionable_option("target", "User or role to notify"),
      @interaction.attachment_option("template", "Configuration template"),
    ],
    default_member_permissions=@model.Permissions::manage_guild(),
    nsfw=false,
    integration_types=[GuildInstall, UserInstall],
    contexts=[Guild, BotDm, PrivateChannel],
  )
  json_inspect(spec.to_json(), content={
    "name": "configure",
    "description": "Configure the bot",
    "options": [
      {
        "type": 3,
        "name": "mode",
        "description": "Operating mode",
        "required": true,
        "choices": [
          { "name": "Fast", "value": "fast" },
          { "name": "Safe", "value": "safe" },
        ],
        "min_length": 1,
        "max_length": 16,
      },
      {
        "type": 4,
        "name": "retries",
        "description": "Retry count",
        "required": true,
        "choices": [
          { "name": "Once", "value": 1 },
          { "name": "Three times", "value": 3 },
        ],
        "min_value": 0,
        "max_value": 10,
      },
      {
        "type": 10,
        "name": "threshold",
        "description": "Alert threshold",
        "choices": [
          { "name": "Low", "value": 0.25 },
          { "name": "High", "value": 0.75 },
        ],
        "min_value": 0,
        "max_value": 1,
        "autocomplete": false,
      },
      {
        "type": 5,
        "name": "enabled",
        "description": "Enable alerts",
        "required": true,
      },
      { "type": 6, "name": "owner", "description": "Configuration owner" },
      {
        "type": 7,
        "name": "channel",
        "description": "Alert destination",
        "required": true,
        "channel_types": [0, 5],
      },
      { "type": 8, "name": "role", "description": "Role to notify" },
      { "type": 9, "name": "target", "description": "User or role to notify" },
      {
        "type": 11,
        "name": "template",
        "description": "Configuration template",
      },
    ],
    "default_member_permissions": "32",
    "nsfw": false,
    "integration_types": [0, 1],
    "contexts": [0, 1, 2],
  })
}

///|
test "choice builders serialize name localizations" {
  json_inspect(
    [
      @interaction.string_choice("Fast", "fast", name_localizations={
        "ja": "高速",
      }).to_json(),
      @interaction.int_choice("Once", 1L, name_localizations={ "ja": "1回" }).to_json(),
      @interaction.number_choice("Low", 0.25, name_localizations={ "ja": "低" }).to_json(),
    ],
    content=[
      {
        "name": "Fast",
        "name_localizations": { "ja": "高速" },
        "value": "fast",
      },
      { "name": "Once", "name_localizations": { "ja": "1回" }, "value": 1 },
      { "name": "Low", "name_localizations": { "ja": "低" }, "value": 0.25 },
    ],
  )
}

///|
test "subcommand and context-menu registration payloads" {
  let spec = @interaction.CommandSpec::slash("admin", "Administrative tools", options=[
    @interaction.sub_command_group("member", "Member administration", [
      @interaction.sub_command("rename", "Rename a member", options=[
        @interaction.user_option("user", "Member", required=true),
        @interaction.string_option("name", "New display name", required=true),
      ]),
      @interaction.sub_command("list", "List members"),
    ]),
  ])
  json_inspect(spec.to_json(), content={
    "name": "admin",
    "description": "Administrative tools",
    "options": [
      {
        "type": 2,
        "name": "member",
        "description": "Member administration",
        "options": [
          {
            "type": 1,
            "name": "rename",
            "description": "Rename a member",
            "options": [
              {
                "type": 6,
                "name": "user",
                "description": "Member",
                "required": true,
              },
              {
                "type": 3,
                "name": "name",
                "description": "New display name",
                "required": true,
              },
            ],
          },
          { "type": 1, "name": "list", "description": "List members" },
        ],
      },
    ],
  })
  json_inspect(
    @interaction.sub_command_group("empty", "No commands yet", []).to_json(),
    content={ "type": 2, "name": "empty", "description": "No commands yet" },
  )
  json_inspect(
    @interaction.CommandSpec::user(
      "View profile",
      default_member_permissions=@model.Permissions::view_channel(),
      contexts=[Guild, BotDm],
    ).to_json(),
    content={
      "name": "View profile",
      "description": "",
      "type": 2,
      "default_member_permissions": "1024",
      "contexts": [0, 1],
    },
  )
  json_inspect(
    @interaction.CommandSpec::message("Archive message", nsfw=true, integration_types=[
      GuildInstall,
    ]).to_json(),
    content={
      "name": "Archive message",
      "description": "",
      "type": 3,
      "nsfw": true,
      "integration_types": [0],
    },
  )
}

///|
test "command options decode scalars ids and resolved values" {
  let fixture =
    #|{
    #|  "id": "107000000000000001",
    #|  "name": "inspect",
    #|  "type": 1,
    #|  "resolved": {
    #|    "users": {
    #|      "80351110224678912": {
    #|        "id": "80351110224678912",
    #|        "username": "Nelly",
    #|        "discriminator": "0",
    #|        "global_name": "Nelly",
    #|        "avatar": null
    #|      }
    #|    },
    #|    "members": {
    #|      "80351110224678912": {
    #|        "nick": "Nelly in guild",
    #|        "roles": ["41771983423143936"],
    #|        "joined_at": null,
    #|        "deaf": false,
    #|        "mute": false,
    #|        "flags": 0
    #|      }
    #|    },
    #|    "channels": {
    #|      "41771983423143937": {
    #|        "id": "41771983423143937",
    #|        "type": 0,
    #|        "name": "bot-commands"
    #|      }
    #|    },
    #|    "roles": {
    #|      "41771983423143936": {
    #|        "id": "41771983423143936",
    #|        "name": "Operators",
    #|        "color": 0,
    #|        "hoist": false,
    #|        "position": 1,
    #|        "permissions": "0",
    #|        "managed": false,
    #|        "mentionable": true,
    #|        "flags": 0
    #|      }
    #|    },
    #|    "attachments": {
    #|      "109000000000000001": {
    #|        "id": "109000000000000001",
    #|        "filename": "settings.json",
    #|        "size": 128,
    #|        "url": "https://cdn.discordapp.com/attachments/settings.json",
    #|        "proxy_url": "https://media.discordapp.net/attachments/settings.json"
    #|      }
    #|    }
    #|  },
    #|  "options": [
    #|    {"name": "text", "type": 3, "value": "hello"},
    #|    {"name": "count", "type": 4, "value": 42},
    #|    {"name": "precise", "type": 4, "value": 9007199254740993},
    #|    {"name": "ratio", "type": 10, "value": 1.25},
    #|    {"name": "enabled", "type": 5, "value": true},
    #|    {"name": "user", "type": 6, "value": "80351110224678912"},
    #|    {"name": "channel", "type": 7, "value": "41771983423143937"},
    #|    {"name": "role", "type": 8, "value": "41771983423143936"},
    #|    {"name": "target", "type": 9, "value": "80351110224678912"},
    #|    {"name": "file", "type": 11, "value": "109000000000000001"},
    #|    {"name": "lost_file", "type": 11, "value": "109000000000000002"}
    #|  ]
    #|}
  let options = command_options(fixture)
  inspect(
    options.string("text"),
    content=(
      #|hello
    ),
  )
  debug_inspect(
    options.string_opt("text"),
    content=(
      #|Some("hello")
    ),
  )
  debug_inspect(
    options.string_opt("missing"),
    content=(
      #|None
    ),
  )
  inspect(
    options.int("count"),
    content=(
      #|42
    ),
  )
  debug_inspect(
    options.int_opt("count"),
    content=(
      #|Some(42)
    ),
  )
  debug_inspect(
    options.int_opt("missing"),
    content=(
      #|None
    ),
  )
  inspect(
    options.int("precise"),
    content=(
      #|9007199254740993
    ),
  )
  inspect(
    options.number("ratio"),
    content=(
      #|1.25
    ),
  )
  debug_inspect(
    options.number_opt("ratio"),
    content=(
      #|Some(1.25)
    ),
  )
  debug_inspect(
    options.number_opt("missing"),
    content=(
      #|None
    ),
  )
  inspect(
    options.bool("enabled"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    options.bool_opt("enabled"),
    content=(
      #|Some(true)
    ),
  )
  debug_inspect(
    options.bool_opt("missing"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    options.path(),
    content=(
      #|[]
    ),
  )
  assert_true(options.has("text"))
  assert_false(options.has("missing"))
  let user_id = options.user("user")
  let channel_id = options.channel("channel")
  let role_id = options.role("role")
  inspect(
    user_id.to_string(),
    content=(
      #|80351110224678912
    ),
  )
  debug_inspect(
    options.user_opt("user").map(id => id.to_string()),
    content=(
      #|Some("80351110224678912")
    ),
  )
  debug_inspect(
    options.user_opt("missing").map(id => id.to_string()),
    content=(
      #|None
    ),
  )
  inspect(
    channel_id.to_string(),
    content=(
      #|41771983423143937
    ),
  )
  debug_inspect(
    options.channel_opt("channel").map(id => id.to_string()),
    content=(
      #|Some("41771983423143937")
    ),
  )
  debug_inspect(
    options.channel_opt("missing").map(id => id.to_string()),
    content=(
      #|None
    ),
  )
  inspect(
    role_id.to_string(),
    content=(
      #|41771983423143936
    ),
  )
  debug_inspect(
    options.role_opt("role").map(id => id.to_string()),
    content=(
      #|Some("41771983423143936")
    ),
  )
  debug_inspect(
    options.role_opt("missing").map(id => id.to_string()),
    content=(
      #|None
    ),
  )
  inspect(
    options.mentionable("target").to_string(),
    content=(
      #|80351110224678912
    ),
  )
  debug_inspect(
    options.mentionable_opt("target").map(id => id.to_string()),
    content=(
      #|Some("80351110224678912")
    ),
  )
  debug_inspect(
    options.mentionable_opt("missing").map(id => id.to_string()),
    content=(
      #|None
    ),
  )
  debug_inspect(
    options.resolved_user(user_id).map(user => user.username),
    content=(
      #|Some("Nelly")
    ),
  )
  debug_inspect(
    options
    .resolved_member(user_id)
    .map(guild_member => guild_member.roles.length()),
    content=(
      #|Some(1)
    ),
  )
  debug_inspect(
    options.resolved_channel(channel_id).map(channel => channel.typ),
    content=(
      #|Some(GuildText)
    ),
  )
  debug_inspect(
    options.resolved_role(role_id).map(role => role.name),
    content=(
      #|Some("Operators")
    ),
  )
  inspect(
    options.attachment("file").filename,
    content=(
      #|settings.json
    ),
  )
}

///|
test "command options flatten subcommand groups" {
  let nested_fixture =
    #|{
    #|  "id": "107000000000000002",
    #|  "name": "admin",
    #|  "type": 1,
    #|  "options": [{
    #|    "name": "member",
    #|    "type": 2,
    #|    "options": [{
    #|      "name": "rename",
    #|      "type": 1,
    #|      "options": [
    #|        {"name": "name", "type": 3, "value": "Nelly"},
    #|        {"name": "times", "type": 4, "value": 2}
    #|      ]
    #|    }]
    #|  }]
    #|}
  let options = command_options(nested_fixture)
  debug_inspect(
    options.path(),
    content=(
      #|["member", "rename"]
    ),
  )
  inspect(
    options.string("name"),
    content=(
      #|Nelly
    ),
  )
  inspect(
    options.int("times"),
    content=(
      #|2
    ),
  )
  let plain_fixture =
    #|{
    #|  "id": "107000000000000003",
    #|  "name": "ping",
    #|  "type": 1,
    #|  "options": [{"name": "message", "type": 3, "value": "pong"}]
    #|}
  debug_inspect(
    command_options(plain_fixture).path(),
    content=(
      #|[]
    ),
  )
}

///|
test "command options report the focused autocomplete option" {
  let fixture =
    #|{
    #|  "id": "107000000000000004",
    #|  "name": "search",
    #|  "type": 1,
    #|  "options": [
    #|    {"name": "scope", "type": 3, "value": "docs"},
    #|    {"name": "query", "type": 3, "value": "moon", "focused": true}
    #|  ]
    #|}
  debug_inspect(
    command_options(fixture).focused(),
    content=(
      #|Some("query")
    ),
  )
}

///|
test "command option access errors identify the failure" {
  let fixture =
    #|{
    #|  "id": "107000000000000005",
    #|  "name": "inspect",
    #|  "type": 1,
    #|  "resolved": {"attachments": {}},
    #|  "options": [
    #|    {"name": "text", "type": 3, "value": "hello"},
    #|    {"name": "file", "type": 11, "value": "109000000000000099"}
    #|  ]
    #|}
  let options = command_options(fixture)
  try options.string("missing") catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|MissingOption(name="missing")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
  try options.int("text") catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|WrongType(name="text", expected="integer")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
  try options.attachment("file") catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|MissingResolved(name="file", kind="attachment")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
struct ExampleCommand {
  query : String
  limit : Int64?
} derive(Debug)

///|
impl @interaction.CommandModel for ExampleCommand with fn from_options(options) {
  { query: options.string("query"), limit: options.int_opt("limit") }
}

///|
test "command model decodes a typed command value" {
  let fixture =
    #|{
    #|  "id": "107000000000000006",
    #|  "name": "search",
    #|  "type": 1,
    #|  "options": [
    #|    {"name": "query", "type": 3, "value": "MoonBit"},
    #|    {"name": "limit", "type": 4, "value": 25}
    #|  ]
    #|}
  let command : ExampleCommand = @interaction.CommandModel::from_options(
    command_options(fixture),
  )
  debug_inspect(
    command,
    content=(
      #|{ query: "MoonBit", limit: Some(25) }
    ),
  )
}
