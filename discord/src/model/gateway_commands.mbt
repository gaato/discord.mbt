///|
/// An outgoing presence, also usable as the initial Identify presence.
pub(all) struct UpdatePresence {
  status : PresenceStatus
  activities : Array[BotActivity]
  afk : Bool
  since : Int64?
} derive(Debug)

///|
/// Construct a presence; an absent `since` is encoded as null.
pub fn UpdatePresence::UpdatePresence(
  status~ : PresenceStatus = Online,
  activities~ : Array[BotActivity] = [],
  afk~ : Bool = false,
  since? : Int64,
) -> UpdatePresence {
  { status, activities, afk, since, }
}

///|
/// Encode the four required Gateway Presence Update fields.
pub impl ToJson for UpdatePresence with fn to_json(self) {
  {
    "status": self.status.to_json(),
    "activities": Json(self.activities),
    "afk": Json(self.afk),
    "since": match self.since {
      Some(value) => Json::number(value.to_double(), repr=value.to_string())
      None => Json::null()
    },
  }
}

///|
/// The activity fields bot users may send, separate from received activities.
pub(all) struct BotActivity {
  name : String
  type_ : ActivityType
  state : String?
  url : String?
} derive(ToJson(fields(type_(rename="type"))), Debug)

///|
/// Show a playing activity.
pub fn BotActivity::playing(name : String) -> BotActivity {
  { name, type_: Playing, state: None, url: None, }
}

///|
/// Show a streaming activity with a Twitch or YouTube URL.
pub fn BotActivity::streaming(name : String, url : String) -> BotActivity {
  { name, type_: Streaming, state: None, url: Some(url), }
}

///|
/// Show a listening activity.
pub fn BotActivity::listening(name : String) -> BotActivity {
  { name, type_: Listening, state: None, url: None, }
}

///|
/// Show a watching activity.
pub fn BotActivity::watching(name : String) -> BotActivity {
  { name, type_: Watching, state: None, url: None, }
}

///|
/// Show a competing activity.
pub fn BotActivity::competing(name : String) -> BotActivity {
  { name, type_: Competing, state: None, url: None, }
}

///|
/// Show custom status text using the conventional name `Custom Status`.
pub fn BotActivity::custom(state : String) -> BotActivity {
  { name: "Custom Status", type_: Custom, state: Some(state), url: None, }
}

///|
/// Select all members, a nonempty username prefix, or 1 to 100 user ids.
pub(all) enum MemberSelect {
  All
  Prefix(String, limit~ : Int32)
  Ids(Array[UserId])
} derive(Debug)

///|
/// An invalid outgoing Gateway command, with the offending field and reason.
pub(all) suberror GatewayCommandError {
  InvalidCommand(LimitViolation)
} derive(Debug)

///|
/// Request members for one guild. `validate` is called by typed send paths.
pub(all) struct RequestGuildMembers {
  guild_id : GuildId
  select : MemberSelect
  presences : Bool
  nonce : String?
} derive(Debug)

///|
/// Check selection bounds and the nonce's UTF-8 byte length before sending.
pub fn RequestGuildMembers::validate(
  self : RequestGuildMembers,
) -> Unit raise GatewayCommandError {
  let checker = LimitChecker::new()
  match self.select {
    All => ()
    Prefix(query, limit~) => {
      if query.is_empty() {
        checker.report("query", "prefix must be nonempty")
      }
      checker.count("limit", Some(limit), min=1, max=100)
    }
    Ids(ids) => checker.count("user_ids", Some(ids.length()), min=1, max=100)
  }
  if self.nonce is Some(nonce) {
    // Count UTF-8 bytes, rather than the module's usual character limits.
    let mut bytes = 0
    for c in nonce.iter() {
      let code = c.to_int()
      bytes += if code < 0x80 {
        1
      } else if code < 0x800 {
        2
      } else if code < 0x10000 {
        3
      } else {
        4
      }
    }
    if bytes > 32 {
      checker.report("nonce", "\{bytes} UTF-8 bytes (at most 32)")
    }
  }
  if checker.violations.get(0) is Some(violation) {
    raise InvalidCommand(violation)
  }
}

///|
/// Encode exactly one of `query`/`limit` and `user_ids`.
pub impl ToJson for RequestGuildMembers with fn to_json(self) {
  let fields : Map[String, Json] = {
    "guild_id": self.guild_id.to_json(),
    "presences": Json(self.presences),
  }
  match self.select {
    All => {
      fields["query"] = ""
      fields["limit"] = 0
    }
    Prefix(query, limit~) => {
      fields["query"] = Json(query)
      fields["limit"] = Json(limit)
    }
    Ids(ids) => fields["user_ids"] = Json(ids)
  }
  if self.nonce is Some(nonce) {
    fields["nonce"] = Json(nonce)
  }
  Json::object(fields)
}

///|
/// Request soundboard sounds for each listed guild.
pub(all) struct RequestSoundboardSounds {
  guild_ids : Array[GuildId]
} derive(ToJson, Debug)

///|
/// An ephemeral channel field; `Other` preserves future field names.
#non_exhaustive
pub(all) enum ChannelInfoField {
  Status
  VoiceStartTime
  Other(String)
} derive(Eq, Debug)

///|
/// Encode a requested channel field name.
pub impl ToJson for ChannelInfoField with fn to_json(self) {
  match self {
    Status => "status"
    VoiceStartTime => "voice_start_time"
    Other(value) => Json(value)
  }
}

///|
/// Request ephemeral channel data for a guild.
pub(all) struct RequestChannelInfo {
  guild_id : GuildId
  fields : Array[ChannelInfoField]
} derive(ToJson, Debug)
