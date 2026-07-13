///|
test "auto moderation rule decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "id": "121000000000000001",
    #|  "guild_id": "81384788765712384",
    #|  "name": "Mention protection",
    #|  "creator_id": "80351110224678912",
    #|  "event_type": 1,
    #|  "trigger_type": 5,
    #|  "trigger_metadata": {
    #|    "mention_total_limit": 5,
    #|    "mention_raid_protection_enabled": true,
    #|    "allow_list": ["trusted"]
    #|  },
    #|  "actions": [{
    #|    "type": 2,
    #|    "metadata": {"channel_id":"41771983423143937"}
    #|  }, {
    #|    "type": 3,
    #|    "metadata": {"duration_seconds":60,"custom_message":"Slow down"}
    #|  }],
    #|  "enabled": true,
    #|  "exempt_roles": ["41771983423143936"],
    #|  "exempt_channels": [],
    #|  "brand_new_field_from_discord": true
    #|}
  let rule : @model.AutoModerationRule = @json.from_json(@json.parse(fixture))
  debug_inspect(
    rule,
    content=(
      #|{
      #|  id: 121000000000000001,
      #|  guild_id: 81384788765712384,
      #|  name: "Mention protection",
      #|  creator_id: 80351110224678912,
      #|  event_type: MessageSend,
      #|  trigger_type: MentionSpam,
      #|  trigger_metadata: {
      #|    keyword_filter: None,
      #|    presets: None,
      #|    allow_list: Some(["trusted"]),
      #|    regex_patterns: None,
      #|    mention_total_limit: Some(5),
      #|    mention_raid_protection_enabled: Some(true),
      #|  },
      #|  actions: [
      #|    {
      #|      typ: SendAlertMessage,
      #|      metadata: Some(
      #|        {
      #|          channel_id: Some(41771983423143937),
      #|          duration_seconds: None,
      #|          custom_message: None,
      #|        },
      #|      ),
      #|    },
      #|    {
      #|      typ: Timeout,
      #|      metadata: Some(
      #|        {
      #|          channel_id: None,
      #|          duration_seconds: Some(60),
      #|          custom_message: Some("Slow down"),
      #|        },
      #|      ),
      #|    },
      #|  ],
      #|  enabled: true,
      #|  exempt_roles: [41771983423143936],
      #|  exempt_channels: [],
      #|}
    ),
  )
}

///|
test "auto moderation enums preserve unknown values" {
  let trigger : @model.AutoModerationTriggerType = @json.from_json(
    @json.parse("99"),
  )
  let action : @model.AutoModerationActionType = @json.from_json(
    @json.parse("98"),
  )
  inspect(
    [trigger.to_json(), action.to_json()].to_json().stringify(),
    content=(
      #|[99,98]
    ),
  )
}
