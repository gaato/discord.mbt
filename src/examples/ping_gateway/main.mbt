///|
/// Example bot on the full library stack: gateway `Shard` + REST `Client`.
/// Replies "pong" to any message whose content is "ping".
///
/// Run: DISCORD_TOKEN=... moon run --release src/examples/ping_gateway
/// Without DISCORD_TOKEN it still exercises the stack live: the gateway
/// rejects the empty identify with close code 4004, which the shard
/// classifies as fatal. RUN_SECONDS overrides the default 60s window.
const DEFAULT_RUN_SECONDS : Int = 60

///|
async fn main {
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  let run_seconds = match @env.get_env_var("RUN_SECONDS") {
    Some(s) => @string.parse_int(s) catch { _ => DEFAULT_RUN_SECONDS }
    None => DEFAULT_RUN_SECONDS
  }
  let client = @dhttp.Client(token)
  let gateway_url = client.get_gateway()
  println("[rest] gateway url: \{gateway_url}")
  let intents = @model.Intents::guilds() |
    @model.Intents::guild_messages() |
    @model.Intents::direct_messages() |
    @model.Intents::message_content()
  @async.with_timeout_opt(run_seconds * 1000, () => {
    @async.with_task_group((group : @async.TaskGroup[Unit]) => {
      let shard = @gateway.Shard::start(group, token~, intents~, gateway_url~)
      for ;; {
        match shard.next() {
          Connected(resumed~) =>
            println("[shard] connected (resumed=\{resumed})")
          Dispatch(Ready(ready)) =>
            println(
              "[shard] ready as \{ready.user.username} in \{ready.guilds.length()} guilds",
            )
          Dispatch(MessageCreate(event)) => {
            let message = event.message
            println(
              "[shard] #\{message.channel_id} <\{message.author.username}> \{message.content}",
            )
            if message.content == "ping" {
              let sent = client.create_message(
                message.channel_id,
                content="pong",
                reply_to=message.id,
              ) catch {
                e => {
                  println("[rest] reply failed: \{to_repr(e)}")
                  continue
                }
              }
              println("[rest] replied with message \{sent.id}")
            }
          }
          Dispatch(event) => println("[shard] event: \{to_repr(event)}")
          Disconnected(code~, resuming~) =>
            println(
              "[shard] disconnected code=\{to_repr(code)} resuming=\{resuming}",
            )
          FatallyClosed(code~) => {
            println("[shard] fatally closed: code=\{code}")
            break
          }
        }
      }
    })
  })
  |> ignore
  println("[done]")
}
