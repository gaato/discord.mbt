///|
#external
priv type NodeGatewayFixture

///|
/// Start the same mttp upgrade server tested on native. This test owns the
/// child process; abort during startup and every later exit kill and join it.
extern "js" fn start_node_gateway_fixture(
  mode : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[NodeGatewayFixture] =
  #| async (mode, signal) => {
  #|   const { spawn } = await import('node:child_process');
  #|   const { existsSync, mkdtempSync, readFileSync, rmSync } = await import('node:fs');
  #|   const path = await import('node:path');
  #|   let root = process.cwd();
  #|   while (!existsSync(path.join(root, 'moon.work'))) {
  #|     const parent = path.dirname(root);
  #|     if (parent === root) throw new Error('gateway fixture needs the repository workspace');
  #|     root = parent;
  #|   }
  #|   const directory = mkdtempSync(path.join(root, '_build', 'gateway-node-'));
  #|   const ready = path.join(directory, 'ready');
  #|   return await new Promise((resolve, reject) => {
  #|     const child = spawn('moon', ['test', 'discord/src/gateway', '--target', 'native', '--target-dir', path.join(root, '_build', 'node-gateway-fixture'), '--filter', 'Node WebSocket fixture'], {
  #|       env: { ...process.env, DISCORD_GATEWAY_NODE_FIXTURE: '1', DISCORD_GATEWAY_NODE_MODE: mode, DISCORD_GATEWAY_NODE_READY: ready, MOON_CC: process.env.MOON_CC || 'cc' },
  #|       stdio: ['ignore', 'pipe', 'pipe'],
  #|       cwd: root,
  #|       detached: process.platform !== 'win32',
  #|     });
  #|     let output = '';
  #|     let settled = false;
  #|     const kill = () => {
  #|       if (child.exitCode !== null || child.signalCode !== null) return;
  #|       try { if (process.platform !== 'win32') process.kill(-child.pid, 'SIGTERM'); else child.kill(); } catch (_) {}
  #|     };
  #|     const exited = new Promise(done => child.once('close', done)).then(code => { rmSync(directory, { recursive: true, force: true }); return code; });
  #|     const cleanup = () => { clearTimeout(timer); clearInterval(poll); signal.removeEventListener('abort', abort); };
  #|     const fail = error => {
  #|       if (settled) return;
  #|       settled = true;
  #|       cleanup();
  #|       kill();
  #|       exited.then(() => reject(error));
  #|     };
  #|     const abort = () => fail(new Error('fixture startup cancelled'));
  #|     const timer = setTimeout(() => fail(new Error('fixture startup timeout: ' + output)), 120000);
  #|     const poll = setInterval(() => {
  #|       let url;
  #|       try { url = readFileSync(ready, 'utf8'); } catch (_) { return; }
  #|       if (!/^ws:\/\/127\.0\.0\.1:\d+$/.test(url) || settled) return;
  #|       settled = true;
  #|       cleanup();
  #|       resolve({ url, ready, kill, exited, diagnostics: () => output });
  #|     }, 10);
  #|     signal.addEventListener('abort', abort, { once: true });
  #|     child.once('error', fail);
  #|     child.once('close', code => {
  #|       if (!settled) fail(new Error('fixture exited ' + code + ': ' + output));
  #|     });
  #|     const read = chunk => {
  #|       output = (output + chunk.toString()).slice(-16384);
  #|     };
  #|     child.stdout.on('data', read);
  #|     child.stderr.on('data', read);
  #|     if (signal.aborted) abort();
  #|   });
  #| }

///|
extern "js" fn node_gateway_fixture_url(fixture : NodeGatewayFixture) -> String =
  #| fixture => fixture.url

///|
extern "js" fn stop_node_gateway_fixture(
  fixture : NodeGatewayFixture,
) -> @js_async.Promise[Unit] =
  #| async fixture => { fixture.kill(); await fixture.exited; }

///|
extern "js" fn check_node_gateway_fixture(
  fixture : NodeGatewayFixture,
) -> @js_async.Promise[Unit] =
  #| async fixture => {
  #|   const code = await fixture.exited;
  #|   if (code !== 0) throw new Error('native gateway peer failed: ' + fixture.diagnostics());
  #| }

///|
extern "js" fn acknowledge_gateway_send(
  fixture : NodeGatewayFixture,
) -> @js_async.Promise[Unit] =
  #| async fixture => {
  #|   const { writeFile } = await import('node:fs/promises');
  #|   await writeFile(fixture.ready + '.sent', 'sent');
  #| }

///|
async test "Node host WebSocket carries mttp Gateway hello identify dispatch and Close" {
  let controller = @js_async.AbortController::new()
  let fixture = start_node_gateway_fixture("sequence", controller.signal()).wait(
    abort_controller=controller,
  )
  defer @async.protect_from_cancel(() => {
    stop_node_gateway_fixture(fixture).wait()
  })
  // Bound a hang, not response time: host load slows real I/O across processes.
  exercise_gateway_sequence(
    node_gateway_fixture_url(fixture),
    compress=true,
    watchdog_ms=30000,
    after_send=() => acknowledge_gateway_send(fixture).wait(),
  )
  check_node_gateway_fixture(fixture).wait()
}

///|
#external
priv type InterruptedSendProbe

///|
/// Real Node WebSockets remain in use; only bufferedAmount is held above
/// zero for one command so cancellation reliably interrupts its drain wait.
extern "js" fn install_interrupted_send_probe(
  fixture_url : String,
) -> InterruptedSendProbe =
  #| fixtureUrl => {
  #|   const original = globalThis.WebSocket;
  #|   // Async tests overlap: each fixture owns a distinct loopback origin.
  #|   // Stalling another fixture's command would prevent its .sent handshake.
  #|   const origin = new URL(fixtureUrl).origin;
  #|   let entered;
  #|   const started = new Promise(resolve => { entered = resolve; });
  #|   globalThis.WebSocket = class extends original {
  #|     send(data) {
  #|       super.send(data);
  #|       if (new URL(this.url).origin === origin &&
  #|           typeof data === 'string' && JSON.parse(data).op === 3) {
  #|         this.stalled = true;
  #|         entered();
  #|       }
  #|     }
  #|     get bufferedAmount() { return this.stalled ? 1 : super.bufferedAmount; }
  #|   };
  #|   return { original, started };
  #| }

///|
extern "js" fn interrupted_send_started(
  probe : InterruptedSendProbe,
) -> @js_async.Promise[Unit] =
  #| probe => probe.started

///|
extern "js" fn restore_interrupted_send_probe(
  probe : InterruptedSendProbe,
) -> Unit =
  #| probe => { globalThis.WebSocket = probe.original; }

///|
// Synchronous scope: restore the fake constructor before other async tests
// can start socket work, so this regression test itself cannot contaminate them.
extern "js" fn with_fake_websocket(check : () -> Bool) -> Bool =
  #| check => {
  #|   const original = globalThis.WebSocket;
  #|   globalThis.WebSocket = class {
  #|     constructor(url) { this.url = new URL(url).href; }
  #|     send(_) {}
  #|     get bufferedAmount() { return 0; }
  #|   };
  #|   try { return check(); }
  #|   finally { globalThis.WebSocket = original; }
  #| }

///|
extern "js" fn check_interrupted_probe_scope() -> Bool =
  #| () => {
  #|   const other = new WebSocket('ws://127.0.0.1:2222/?v=10&encoding=json&compress=zlib-stream');
  #|   const owned = new WebSocket('ws://127.0.0.1:1111/?v=10&encoding=json');
  #|   other.send('{"op":3,"d":null}');
  #|   owned.send('{"op":2,"d":{}}');
  #|   if (other.bufferedAmount !== 0 || owned.bufferedAmount !== 0) return false;
  #|   owned.send('{"op":3,"d":null}');
  #|   return other.bufferedAmount === 0 && owned.bufferedAmount === 1;
  #| }

///|
test "interrupted send probe leaves other Gateway connections draining" {
  assert_true(
    with_fake_websocket(() => {
      let probe = install_interrupted_send_probe("ws://127.0.0.1:1111")
      defer restore_interrupted_send_probe(probe)
      check_interrupted_probe_scope()
    }),
  )
}

///|
async test "cancelled JS Gateway send closes without status and reconnects with Resume" {
  let controller = @js_async.AbortController::new()
  let fixture = start_node_gateway_fixture("resume", controller.signal()).wait(
    abort_controller=controller,
  )
  defer @async.protect_from_cancel(() => {
    stop_node_gateway_fixture(fixture).wait()
  })
  let probe = install_interrupted_send_probe(node_gateway_fixture_url(fixture))
  defer restore_interrupted_send_probe(probe)
  let clock = @transport.VirtualClock()
  // Bound a hang, not response time: host load slows real I/O across processes.
  @async.with_timeout(30000, () => {
    @async.with_task_group(group => {
      let shard = @gateway.Shard::start(
        group,
        token="local-test",
        intents=@model.Intents::none(),
        gateway_url=node_gateway_fixture_url(fixture),
        clock~,
      )
      guard! shard.next() is Connected(resumed=false)
      guard! shard.next() is Dispatch(Ready(_))
      let sender = group.spawn(allow_failure=true, () => {
        shard.send({ "op": 3, "d": null })
      })
      interrupted_send_started(probe).wait()
      sender.cancel()
      try sender.wait() catch {
        @async.WaitedTaskAlreadyCancelled => ()
        error => fail("unexpected send cancellation: \{Repr(error)}")
      } noraise {
        _ => fail("interrupted send unexpectedly completed")
      }
      guard! shard.next() is Disconnected(code=None, resuming=true)
      assert_true(shard.session() is Some({ id: "sess-1", sequence: 1L, .. }))
      clock.settle(until=() => clock.pending().length() == 1)
      assert_true(clock.advance_to_next())
      guard! shard.next() is Connected(resumed=true)
      shard.close()
    })
  })
  check_node_gateway_fixture(fixture).wait()
}
