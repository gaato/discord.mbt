///|
test "developer team decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "icon":null,"id":"127000000000000001","name":"Example Team",
    #|  "owner_user_id":"80351110224678912",
    #|  "members":[{
    #|    "membership_state":2,"permissions":["*"],
    #|    "team_id":"127000000000000001",
    #|    "user":{"id":"80351110224678912","username":"Nelly","discriminator":"0","global_name":"Nelly","avatar":null},
    #|    "role":"admin","future":true
    #|  }],
    #|  "brand_new_field_from_discord":true
    #|}
  let team : @model.Team = @json.from_json(@json.parse(fixture))
  debug_inspect(
    team,
    content=(
      #|{
      #|  icon: Null,
      #|  id: 127000000000000001,
      #|  members: [
      #|    {
      #|      membership_state: Accepted,
      #|      team_id: 127000000000000001,
      #|      user: {
      #|        id: 80351110224678912,
      #|        username: "Nelly",
      #|        discriminator: "0",
      #|        global_name: Some(Value("Nelly")),
      #|        avatar: Null,
      #|        bot: None,
      #|        system: None,
      #|        mfa_enabled: None,
      #|        banner: None,
      #|        accent_color: None,
      #|        locale: None,
      #|        verified: None,
      #|        email: None,
      #|        flags: None,
      #|        premium_type: None,
      #|        public_flags: None,
      #|        avatar_decoration: None,
      #|        avatar_decoration_data: None,
      #|        collectibles: None,
      #|        primary_guild: None,
      #|      },
      #|      role: Some("admin"),
      #|    },
      #|  ],
      #|  name: "Example Team",
      #|  owner_user_id: 80351110224678912,
      #|}
    ),
  )
}

///|
test "team membership state preserves an unknown value" {
  let state : @model.TeamMembershipState = @json.from_json(@json.parse("99"))
  debug_inspect(
    state,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    state.to_json().stringify(),
    content=(
      #|99
    ),
  )
}
