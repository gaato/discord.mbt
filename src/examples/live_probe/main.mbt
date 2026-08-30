///|
/// Live REST/gateway probe: exercises every typed endpoint against the real
/// Discord API, in dependency order, and prints a classification report.
///
/// Run: DISCORD_TOKEN=... GUILD_ID=... moon run --release src/examples/live_probe
/// The target guild is assumed to be disposable: channels, roles, emojis,
/// stickers, events, webhooks etc. are created and (best-effort) deleted.
///
/// Outcomes:
///   PASS         2xx and response decoded
///   PASS-ERR     endpoint intentionally called with a bogus target and the
///                expected API error came back (wiring/serialization verified)
///   ENV-LIMITED  the endpoint needs environment we don't have (community
///                feature, OAuth bearer token, monetized app, ...) and Discord
///                refused as expected
///   FAIL         anything unexpected, including decode errors
///   SKIP         not called (reason recorded)
enum Outcome {
  Pass
  PassErr
  EnvLimited
  Fail
  Skip
} derive(Eq)

///|
fn Outcome::label(self : Outcome) -> String {
  match self {
    Pass => "PASS"
    PassErr => "PASS-ERR"
    EnvLimited => "ENV-LIMITED"
    Fail => "FAIL"
    Skip => "SKIP"
  }
}

///|
struct Entry {
  name : String
  outcome : Outcome
  note : String
}

///|
/// Shared ids created along the way; sections depend on earlier sections.
struct S {
  mut category : @model.ChannelId?
  mut text : @model.ChannelId?
  mut text2 : @model.ChannelId?
  mut voice : @model.ChannelId?
  mut stage : @model.ChannelId?
  mut forum : @model.ChannelId?
  mut announcement : @model.ChannelId?
  mut community_enabled : Bool
  mut role : @model.RoleId?
  mut emoji : @model.EmojiId?
  mut emoji_name : String
  mut sticker : @model.StickerId?
  mut sound : @model.SoundboardSoundId?
  mut message : @model.MessageId?
  mut webhook : @model.WebhookId?
  mut original_features : Array[@model.GuildFeature]
}

///|
fn S::S() -> S {
  {
    category: None,
    text: None,
    text2: None,
    voice: None,
    stage: None,
    forum: None,
    announcement: None,
    community_enabled: false,
    role: None,
    emoji: None,
    emoji_name: "",
    sticker: None,
    sound: None,
    message: None,
    webhook: None,
    original_features: [],
  }
}

///|
struct P {
  client : @dhttp.Client
  mut app_id : @model.ApplicationId
  guild_id : @model.GuildId
  mut bot_id : @model.UserId
  mut owner_id : @model.UserId
  report : Array[Entry]
  payloads : Array[String]
  s : S
}

///|
fn P::push(self : P, name : String, outcome : Outcome, note : String) -> Unit {
  self.report.push({ name, outcome, note, })
  println("\{outcome.label()} \{name} — \{note}")
}

///|
/// Expect success.
async fn P::probe(self : P, name : String, f : async () -> String) -> Unit {
  try {
    let note = f()
    self.push(name, Pass, note)
  } catch {
    err => self.push(name, Fail, describe(err))
  }
}

///|
/// Expect a specific API refusal (bogus target / impossible state): the
/// endpoint's URL, auth, serialization and error decoding are still verified.
async fn P::probe_err(
  self : P,
  name : String,
  expect~ : Array[Int],
  f : async () -> Unit,
) -> Unit {
  try {
    f()
    self.push(name, Fail, "expected an API error but the call succeeded")
  } catch {
    @dhttp.Api(status~, error~) =>
      if expect.contains(status) {
        self.push(name, PassErr, "status=\{status} code=\{error.code}")
      } else {
        self.push(
          name,
          Fail,
          "unexpected status=\{status} code=\{error.code} \{error.message}",
        )
      }
    err => self.push(name, Fail, describe(err))
  }
}

///|
/// Success is PASS; an API refusal is ENV-LIMITED (feature/entitlement gated).
async fn P::probe_env(self : P, name : String, f : async () -> String) -> Unit {
  try {
    let note = f()
    self.push(name, Pass, note)
  } catch {
    @dhttp.Api(status~, error~) =>
      self.push(
        name,
        EnvLimited,
        "status=\{status} code=\{error.code} \{error.message}",
      )
    ProbeError(msg) => self.push(name, EnvLimited, "probe: \{msg}")
    err => self.push(name, Fail, describe(err))
  }
}

///|
suberror ProbeError {
  ProbeError(String)
}

///|
fn[T] need(x : T?, what : String) -> T raise {
  match x {
    Some(v) => v
    None => raise ProbeError("missing prerequisite: \{what}")
  }
}

///|
fn[T : Show] nul(n : @model.Nullable[T]) -> String {
  match n {
    Null => "null"
    Value(v) => v.to_string()
  }
}

///|
fn[T : Show] optnul(n : @model.Nullable[T]?) -> String {
  match n {
    Some(Value(v)) => v.to_string()
    Some(Null) => "null"
    None => "absent"
  }
}

///|
/// Emoji.id is `Nullable[Id]?` on the wire; flatten to a plain option.
fn emoji_id_of(e : @model.Emoji) -> @model.EmojiId? {
  match e.id {
    Some(Value(id)) => Some(id)
    _ => None
  }
}

///|
fn describe(err : Error) -> String {
  match err {
    @dhttp.Api(status~, error~) =>
      "status=\{status} code=\{error.code} \{error.message} \{error.errors.map_or("", e => e.stringify())}"
    ProbeError(msg) => "probe: \{msg}"
    _ => Repr(err).to_string()
  }
}

///|
/// Redact webhook/interaction tokens in paths before logging.
fn redact_path(path : String) -> String {
  path
  .split("/")
  .map(seg => if seg.length() > 40 { "<token>" } else { seg.to_owned() })
  .collect()
  .join("/")
}

///|
fn attach_payload_log(p : P) -> Unit {
  p.client.middleware((request, next) => {
    let response = next(request)
    let line = @model.ObjBuilder()
      .field("method", Repr(request.route.method_()).to_string())
      .field("path", redact_path(request.route.path()))
      .field("bucket", redact_path(request.route.bucket()))
      .field("request", request.body.unwrap_or(Json::null()))
      .field("status", response.status)
      .field("response", response.body)
      .build()
    p.payloads.push(line.stringify())
    response
  })
}

///|
fn pad(n : Int64, width : Int) -> String {
  let s = n.to_string()
  let mut out = s
  while out.length() < width {
    out = "0" + out
  }
  out
}

///|
/// ISO8601 UTC from unix milliseconds (civil-from-days).
fn iso8601(ms : Int64) -> @model.Timestamp {
  let secs = ms / 1000
  let days = secs / 86400
  let rem = secs % 86400
  let hh = rem / 3600
  let mi = rem % 3600 / 60
  let ss = rem % 60
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = mp + (if mp < 10L { 3L } else { -9L })
  let y = yoe + era * 400L + (if m <= 2L { 1L } else { 0L })
  Timestamp(
    "\{pad(y, 4)}-\{pad(m, 2)}-\{pad(d, 2)}T\{pad(hh, 2)}:\{pad(mi, 2)}:\{pad(ss, 2)}Z",
  )
}

///|
fn now_ms() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
fn print_summary(p : P) -> Unit {
  let counts : Map[String, Int] = Map([])
  for e in p.report {
    let key = e.outcome.label()
    counts[key] = counts.get(key).unwrap_or(0) + 1
  }
  println("")
  println("=== live probe summary ===")
  for key in ["PASS", "PASS-ERR", "ENV-LIMITED", "FAIL", "SKIP"] {
    println("\{key}: \{counts.get(key).unwrap_or(0)}")
  }
  println("total: \{p.report.length()}")
  let fails = p.report.filter(e => e.outcome == Fail)
  if fails.length() > 0 {
    println("")
    println("=== failures ===")
    for e in fails {
      println("FAIL \{e.name} — \{e.note}")
    }
  }
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  if token == "" {
    println("DISCORD_TOKEN is required")
    return
  }
  // POST /guilds/{id}/prune has been observed to take >30s even on a tiny
  // guild; give the whole probe a roomier request timeout.
  let client = @dhttp.Client(token, request_timeout_ms=60_000)
  defer client.close()
  // The probe mutates the guild heavily; require an explicit GUILD_ID so it
  // can never pick up an unintended guild by discovery.
  guard @env.get_env_var("GUILD_ID") is Some(raw_guild) else {
    println("GUILD_ID is required (the probe rewrites the target guild)")
    return
  }
  let guild_id : @model.GuildId = @model.Id::parse(raw_guild) catch {
    _ => {
      println("invalid GUILD_ID")
      return
    }
  }
  println("target guild: \{guild_id}")
  let p = P::{
    client,
    app_id: Id(0UL),
    guild_id,
    bot_id: Id(0UL),
    owner_id: Id(0UL),
    report: [],
    payloads: [],
    s: S(),
  }
  attach_payload_log(p)
  try {
    sec_core(p)
    sec_base_channels(p)
    sec_guild(p)
    sec_expressions(p)
    sec_messages(p)
    sec_threads(p)
    sec_members(p)
    sec_webhooks(p)
    sec_events(p)
    sec_templates(p)
    sec_commands(p)
    sec_monetization(p)
    sec_gateway(p)
    sec_cleanup(p)
  } catch {
    err => println("!! probe aborted: \{describe(err)}")
  }
  print_summary(p)
  let log_path = @env.get_env_var("PAYLOAD_LOG").unwrap_or(
    "live_probe_payloads.jsonl",
  )
  let body = p.payloads.join("\n") + "\n"
  @fs.write_file(log_path, body, create_mode=CreateOrTruncate) catch {
    err => println("payload log write failed: \{Repr(err)}")
  }
  println("payload log: \{log_path} (\{p.payloads.length()} calls)")
}
