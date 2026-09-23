///|
#external
priv type WsHandle

///|
priv struct WsEvent {
  kind : Int
  text : String
  data : Bytes
  code : Int
  reason : String
}

///|
extern "js" fn ws_open(
  url : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[WsHandle] =
  #| (url, signal) => new Promise((resolve, reject) => {
  #|   let socket;
  #|   try { socket = new WebSocket(url); } catch (e) { reject(new Error(String(e))); return; }
  #|   try { socket.binaryType = 'arraybuffer'; } catch (_) {}
  #|   const handle = { socket, queue: [], waiter: null, terminal: null };
  #|   let opened = false;
  #|   let settled = false;
  #|   const abortError = () => { const e = new Error('aborted'); e.name = 'AbortError'; return e; };
  #|   const fail = (message) => { if (!settled) { settled = true; cleanup(); reject(new Error(message)); } };
  #|   const onAbort = () => { try { socket.close(); } catch (_) {} if (!settled) { settled = true; cleanup(); reject(abortError()); } };
  #|   const cleanup = () => signal.removeEventListener('abort', onAbort);
  #|   if (signal.aborted) { onAbort(); return; }
  #|   signal.addEventListener('abort', onAbort, { once: true });
  #|   const empty = new Uint8Array(0);
  #|   const deliver = (event) => {
  #|     if (handle.waiter) { const waiter = handle.waiter; handle.waiter = null; waiter.cleanup(); waiter.resolve(event); }
  #|     else handle.queue.push(event);
  #|   };
  #|   socket.addEventListener('open', () => { opened = true; settled = true; cleanup(); resolve(handle); });
  #|   socket.addEventListener('message', (e) => {
  #|     const data = e.data;
  #|     if (typeof data === 'string') deliver({ kind: 0, text: data, data: empty, code: 0, reason: '' });
  #|     else if (data instanceof ArrayBuffer) deliver({ kind: 1, text: '', data: new Uint8Array(data), code: 0, reason: '' });
  #|     else if (ArrayBuffer.isView(data)) deliver({ kind: 1, text: '', data: new Uint8Array(data.buffer, data.byteOffset, data.byteLength).slice(), code: 0, reason: '' });
  #|     else deliver({ kind: 3, text: '', data: empty, code: 0, reason: '' });
  #|   });
  #|   socket.addEventListener('close', (e) => {
  #|     if (!opened) { fail(e.reason || 'connection failed'); return; }
  #|     handle.terminal = { kind: 2, text: '', data: empty, code: e.code, reason: e.reason || '' };
  #|     deliver(handle.terminal);
  #|   });
  #|   socket.addEventListener('error', () => { if (!opened) fail('connection failed'); });
  #| })

///|
extern "js" fn ws_next(
  handle : WsHandle,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[WsEvent] =
  #| (handle, signal) => new Promise((resolve, reject) => {
  #|   if (handle.queue.length) { resolve(handle.queue.shift()); return; }
  #|   if (handle.terminal) { resolve(handle.terminal); return; }
  #|   if (handle.waiter) { reject(new Error('concurrent recv')); return; }
  #|   const onAbort = () => {
  #|     if (handle.waiter === waiter) { handle.waiter = null; reject(Object.assign(new Error('aborted'), { name: 'AbortError' })); }
  #|   };
  #|   const waiter = { resolve, reject, cleanup: () => signal.removeEventListener('abort', onAbort) };
  #|   handle.waiter = waiter;
  #|   if (signal.aborted) onAbort();
  #|   else signal.addEventListener('abort', onAbort, { once: true });
  #| })

///|
extern "js" fn ws_send_text(handle : WsHandle, text : String) -> String =
  #| (handle, text) => { try { handle.socket.send(text); return ''; } catch (e) { return String(e); } }

///|
extern "js" fn ws_send_binary(handle : WsHandle, data : Bytes) -> String =
  #| (handle, data) => { try { handle.socket.send(data); return ''; } catch (e) { return String(e); } }

///|
extern "js" fn ws_close(handle : WsHandle, code : Int, reason : String) =
  #| (handle, code, reason) => {
  #|   const socket = handle.socket;
  #|   try {
  #|     if (code < 0 || !(code === 1000 || (code >= 3000 && code <= 4999))) { socket.close(); return; }
  #|     const bytes = new TextEncoder().encode(reason);
  #|     if (bytes.length > 123) reason = new TextDecoder().decode(bytes.subarray(0, 123));
  #|     socket.close(code, reason);
  #|   } catch (_) { try { socket.close(); } catch (_) {} }
  #| }

///|
extern "js" fn ws_ready_state(handle : WsHandle) -> Int =
  #| (handle) => handle.socket.readyState

///|
extern "js" fn utf8_encode(text : String) -> Bytes =
  #| (text) => new TextEncoder().encode(text)
