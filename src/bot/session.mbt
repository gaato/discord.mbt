///|
/// Persist a Bot gateway session together with the READY identity needed to
/// restore event and interaction handling before Discord sends RESUMED.
/// Optional cache contents and application-owned state are not restored.
/// Persisting a receive sequence periodically does not guarantee exactly-once
/// event handling after a restart.
pub(all) struct BotSession {
  gateway : @gateway.Session
  ready : @model.Ready
} derive(Debug, ToJson, FromJson)

///|
fn clone_ready(ready : @model.Ready) -> @model.Ready {
  @json.from_json(ready.to_json()) catch {
    _ => abort("a decoded READY failed to round-trip through JSON")
  }
}

///|
fn clone_bot_session(snapshot : BotSession) -> BotSession {
  {
    gateway: {
      id: snapshot.gateway.id,
      resume_url: snapshot.gateway.resume_url,
      sequence: snapshot.gateway.sequence,
    },
    ready: clone_ready(snapshot.ready),
  }
}
