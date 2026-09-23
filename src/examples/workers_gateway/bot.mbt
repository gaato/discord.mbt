///|
/// Build one gateway bot. Slash commands need no gateway intents.
pub fn build_bot(
  token : String,
  gateway_url : String,
  saved_sessions : Map[Int, @discord.BotSession],
) -> @discord.Bot {
  let bot = @discord.Bot(
    worker_app(),
    token~,
    gateway_url~,
    resume=saved_sessions,
    intents=@model.Intents::none(),
    sync=Global,
    sync_unowned=Keep,
  )
  bot.on(@discord.Events::ready(), (_, ready) => {
    println("[gateway] ready as \{ready.user.username}")
  })
  bot.on_telemetry(event => println("[gateway] \{Repr(event)}"))
  bot
}

///|
/// Encode Bot snapshots as an object keyed by decimal shard id.
pub fn encode_sessions(sessions : Map[Int, @discord.BotSession]) -> String {
  let object : Map[String, Json] = Map([])
  for id, session in sessions {
    object[id.to_string()] = session.to_json()
  }
  Json::object(object).stringify()
}

///|
/// Decode persisted Bot snapshots. An invalid object yields no snapshots.
pub fn decode_sessions(text : String) -> Map[Int, @discord.BotSession] {
  let empty : Map[Int, @discord.BotSession] = Map([])
  let parsed = @json.parse(text) catch { _ => return empty }
  guard parsed is Object(object) else { return empty }
  let sessions : Map[Int, @discord.BotSession] = Map([])
  for shard_id, value in object {
    let id = @string.parse_int(shard_id) catch { _ => return empty }
    if id < 0 {
      return empty
    }
    let session : @discord.BotSession = @json.from_json(value) catch {
      _ => return empty
    }
    if session.gateway.id != session.ready.session_id {
      return empty
    }
    sessions[id] = session
  }
  sessions
}
