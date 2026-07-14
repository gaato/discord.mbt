///|
test "application command decodes nested slash options" {
  let fixture =
    #|{
    #|  "id": "107000000000000001",
    #|  "type": 1,
    #|  "application_id": "172150183260323840",
    #|  "guild_id": "81384788765712384",
    #|  "name": "admin",
    #|  "name_localizations": {"ja": "管理"},
    #|  "description": "Administrative tools",
    #|  "description_localizations": null,
    #|  "options": [{
    #|    "type": 2,
    #|    "name": "user",
    #|    "description": "User operations",
    #|    "options": [{
    #|      "type": 1,
    #|      "name": "set-name",
    #|      "description": "Set a display name",
    #|      "options": [{
    #|        "type": 3,
    #|        "name": "name",
    #|        "name_localizations": null,
    #|        "description": "The new name",
    #|        "required": true,
    #|        "min_length": 1,
    #|        "max_length": 32,
    #|        "choices": [
    #|          {"name": "Nelly", "value": "nelly"},
    #|          {"name": "Number", "value": 7}
    #|        ]
    #|      }, {
    #|        "type": 10,
    #|        "name": "weight",
    #|        "description": "Optional weight",
    #|        "min_value": 0.5,
    #|        "max_value": 10,
    #|        "autocomplete": false
    #|      }]
    #|    }]
    #|  }],
    #|  "default_member_permissions": "8",
    #|  "dm_permission": false,
    #|  "nsfw": false,
    #|  "integration_types": [0, 1],
    #|  "contexts": [0, 1, 2],
    #|  "version": "107000000000000002",
    #|  "brand_new_field_from_discord": true
    #|}
  let command : @model.ApplicationCommand = @json.from_json(
    @json.parse(fixture),
  )
  debug_inspect(
    command,
    content=(
      #|{
      #|  id: 107000000000000001,
      #|  typ: Some(ChatInput),
      #|  application_id: 172150183260323840,
      #|  guild_id: Some(81384788765712384),
      #|  name: "admin",
      #|  name_localizations: Some(Value({ "ja": "管理" })),
      #|  description: "Administrative tools",
      #|  description_localizations: Some(Null),
      #|  options: Some(
      #|    [
      #|      {
      #|        typ: SubCommandGroup,
      #|        name: "user",
      #|        name_localizations: None,
      #|        description: "User operations",
      #|        description_localizations: None,
      #|        required: None,
      #|        choices: None,
      #|        options: Some(
      #|          [
      #|            {
      #|              typ: SubCommand,
      #|              name: "set-name",
      #|              name_localizations: None,
      #|              description: "Set a display name",
      #|              description_localizations: None,
      #|              required: None,
      #|              choices: None,
      #|              options: Some(
      #|                [
      #|                  {
      #|                    typ: String,
      #|                    name: "name",
      #|                    name_localizations: Some(Null),
      #|                    description: "The new name",
      #|                    description_localizations: None,
      #|                    required: Some(true),
      #|                    choices: Some(
      #|                      [
      #|                        { name: "Nelly", name_localizations: None, value: String("nelly") },
      #|                        { name: "Number", name_localizations: None, value: Number(7) },
      #|                      ],
      #|                    ),
      #|                    options: None,
      #|                    channel_types: None,
      #|                    min_value: None,
      #|                    max_value: None,
      #|                    min_length: Some(1),
      #|                    max_length: Some(32),
      #|                    autocomplete: None,
      #|                  },
      #|                  {
      #|                    typ: Number,
      #|                    name: "weight",
      #|                    name_localizations: None,
      #|                    description: "Optional weight",
      #|                    description_localizations: None,
      #|                    required: None,
      #|                    choices: None,
      #|                    options: None,
      #|                    channel_types: None,
      #|                    min_value: Some(Number(0.5)),
      #|                    max_value: Some(Number(10)),
      #|                    min_length: None,
      #|                    max_length: None,
      #|                    autocomplete: Some(false),
      #|                  },
      #|                ],
      #|              ),
      #|              channel_types: None,
      #|              min_value: None,
      #|              max_value: None,
      #|              min_length: None,
      #|              max_length: None,
      #|              autocomplete: None,
      #|            },
      #|          ],
      #|        ),
      #|        channel_types: None,
      #|        min_value: None,
      #|        max_value: None,
      #|        min_length: None,
      #|        max_length: None,
      #|        autocomplete: None,
      #|      },
      #|    ],
      #|  ),
      #|  default_member_permissions: Value(8),
      #|  dm_permission: Some(false),
      #|  nsfw: Some(false),
      #|  integration_types: Some([GuildInstall, UserInstall]),
      #|  contexts: Some(Value([Guild, BotDm, PrivateChannel])),
      #|  version: 107000000000000002,
      #|}
    ),
  )
  inspect(
    command.to_json().stringify(),
    content=(
      #|{"id":"107000000000000001","type":1,"application_id":"172150183260323840","guild_id":"81384788765712384","name":"admin","name_localizations":{"ja":"管理"},"description":"Administrative tools","description_localizations":null,"options":[{"type":2,"name":"user","description":"User operations","options":[{"type":1,"name":"set-name","description":"Set a display name","options":[{"type":3,"name":"name","name_localizations":null,"description":"The new name","required":true,"choices":[{"name":"Nelly","value":"nelly"},{"name":"Number","value":7}],"min_length":1,"max_length":32},{"type":10,"name":"weight","description":"Optional weight","min_value":0.5,"max_value":10,"autocomplete":false}]}]}],"default_member_permissions":"8","dm_permission":false,"nsfw":false,"integration_types":[0,1],"contexts":[0,1,2],"version":"107000000000000002"}
    ),
  )
}

///|
test "command option preserves an unknown wire type" {
  let fixture =
    #|{"type":99,"name":"future","description":"A future option","min_value":1.25}
  let option : @model.CommandOption = @json.from_json(@json.parse(fixture))
  debug_inspect(
    option,
    content=(
      #|{
      #|  typ: Unknown(99),
      #|  name: "future",
      #|  name_localizations: None,
      #|  description: "A future option",
      #|  description_localizations: None,
      #|  required: None,
      #|  choices: None,
      #|  options: None,
      #|  channel_types: None,
      #|  min_value: Some(Number(1.25)),
      #|  max_value: None,
      #|  min_length: None,
      #|  max_length: None,
      #|  autocomplete: None,
      #|}
    ),
  )
  let encoded = option.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|{"type":99,"name":"future","description":"A future option","min_value":1.25}
    ),
  )
  let decoded : @model.CommandOption = @json.from_json(@json.parse(encoded))
  assert_true(decoded.typ == @model.CommandOptionType::Unknown(99))
}
