///|
/// Wraps the bot's identify queue with Discord's daily session start limit.
/// After the queue grants a slot, the live `session_start_limit` is read from
/// `GET /gateway/bot`; a shard whose IDENTIFY would exceed it is held while
/// `Bot::run` ends with `SessionStartLimitExceeded`. Exceeding that limit
/// resets the bot token, so an exhausted limit fails closed. A limit that
/// cannot be read is reported through the app's warning hook and the shard
/// identifies anyway, because a REST outage must not stop a running bot.
priv struct IdentifyGuard {
  bot : Bot
  client : @dhttp.Client
  inner : &@queue.IdentifyQueue
  refusals : @aqueue.Queue[ManagedShardEvent]
}

///|
impl @queue.IdentifyQueue for IdentifyGuard with fn wait_for_identify(
  self,
  shard_id,
) {
  self.inner.wait_for_identify(shard_id)
  let info = self.bot.gateway_bot_info(self.client) catch {
    error => {
      self.bot.app_.warn(
        "identifying shard \{shard_id} without reading the session start limit: \{Repr(error)}",
      )
      return
    }
  }
  let limit = info.session_start_limit
  if limit.remaining <= 0 {
    self.refusals.put(
      IdentifyRefused(
        BotError::SessionStartLimitExceeded(
          required=1,
          remaining=limit.remaining,
          reset_after_ms=limit.reset_after,
        ),
      ),
    )
    // Hold the shard here; `Bot::run` raises the error and cancels the task
    // group, which tears this shard down without sending IDENTIFY.
    let parked : @async.Semaphore = Semaphore(1, initial_value=0)
    parked.acquire()
  }
}
