///|
#external
pub type BotHandle

///|
extern "js" fn BotHandle::BotHandle(
  finished : @js_async.Promise[Unit],
  sessions : () -> String,
) -> BotHandle =
  #| (finished, sessions) => ({ finished, sessions })

///|
pub extern "js" fn BotHandle::finished(
  self : BotHandle,
) -> @js_async.Promise[Unit] =
  #| (handle) => handle.finished

///|
pub extern "js" fn BotHandle::sessions(self : BotHandle) -> String =
  #| (handle) => handle.sessions()

///|
extern "js" fn wake_on_abort(
  signal : @js_async.AbortSignal,
  wake : () -> Unit,
  finished : @js_async.Promise[Unit],
) -> Unit =
  #| (signal, wake, finished) => {
  #|   const onAbort = () => queueMicrotask(wake);
  #|   signal.addEventListener("abort", onAbort);
  #|   if (signal.aborted) onAbort();
  #|   finished.then(
  #|     () => signal.removeEventListener("abort", onAbort),
  #|     () => signal.removeEventListener("abort", onAbort),
  #|   );
  #| }

///|
/// Start the bot. Its promise settles on graceful return or failure, while
/// `sessions()` returns a fresh JSON snapshot for Durable Object storage.
pub fn start_bot(
  token : String,
  gateway_url : String,
  sessions_json : String,
  abort_signal : @js_async.AbortSignal,
) -> BotHandle {
  let bot = build_bot(token, gateway_url, decode_sessions(sessions_json))
  let finished = @js_async.Promise::from_async(() => bot.run(), abort_signal~)
  // async 0.22.1 queues cancellation from plain JS without scheduling a turn.
  // A no-op exported coroutine wakes that scheduler after the abort event.
  wake_on_abort(
    abort_signal,
    () => {
      let _ = @js_async.Promise::from_async(() => ())
    },
    finished,
  )
  BotHandle(finished, () => encode_sessions(bot.sessions()))
}
