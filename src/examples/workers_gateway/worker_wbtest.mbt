///|
async test "bot bridge cancels an unreachable connection" {
  let controller = @js_async.AbortController::new()
  let handle = start_bot(
    "test-token",
    "ws://127.0.0.1:9",
    "{}",
    controller.signal(),
  )
  @async.sleep(50)
  controller.abort()
  try handle.finished().wait() catch {
    _ => ()
  } noraise {
    _ => fail("cancelled bot unexpectedly completed")
  }
  inspect(handle.sessions(), content="{}")
}
