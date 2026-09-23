///|
extern "js" fn start_echo_server() -> @js_async.Promise[Int] =
  #| () => new Promise((resolve, reject) => {
  #|   const http = require('node:http');
  #|   const crypto = require('node:crypto');
  #|   const servers = globalThis.__moonbit_ws_echo_servers ||= new Map();
  #|   const server = http.createServer();
  #|   const clients = new Set();
  #|   server.on('upgrade', (req, socket) => {
  #|     clients.add(socket);
  #|     socket.on('close', () => clients.delete(socket));
  #|     socket.on('error', () => {});
  #|     const key = req.headers['sec-websocket-key'];
  #|     const accept = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  #|     socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ' + accept + '\r\n\r\n');
  #|     let pending = Buffer.alloc(0), fragments = [], fragmentOp = 0;
  #|     const send = (op, data) => {
  #|       if (socket.destroyed || socket.writableEnded) return;
  #|       const len = data.length;
  #|       const head = len < 126 ? Buffer.from([0x80 | op, len]) : len < 65536 ? Buffer.from([0x80 | op, 126, len >> 8, len & 255]) : Buffer.from([0x80 | op, 127, 0, 0, 0, 0, (len / 0x1000000) & 255, (len >>> 16) & 255, (len >>> 8) & 255, len & 255]);
  #|       socket.write(Buffer.concat([head, data]));
  #|     };
  #|     const processFrame = (op, fin, data) => {
  #|       if (op === 8) { send(8, data); socket.end(); return; }
  #|       if (op === 9) { send(10, data); return; }
  #|       if (op === 10) return;
  #|       if (op === 1 || op === 2) { fragmentOp = op; fragments = [data]; }
  #|       else if (op === 0) fragments.push(data);
  #|       else return;
  #|       if (!fin) return;
  #|       const payload = Buffer.concat(fragments), kind = fragmentOp;
  #|       fragments = []; fragmentOp = 0;
  #|       const text = kind === 1 ? payload.toString('utf8') : '';
  #|       const close = /^close ([0-9]+) (.*)$/.exec(text);
  #|       if (close) { const reason = Buffer.from(close[2]); const frame = Buffer.alloc(2 + reason.length); frame.writeUInt16BE(Number(close[1]), 0); reason.copy(frame, 2); send(8, frame); socket.end(); }
  #|       else send(kind, payload);
  #|     };
  #|     socket.on('data', (chunk) => {
  #|       pending = Buffer.concat([pending, chunk]);
  #|       while (pending.length >= 2) {
  #|         const first = pending[0], second = pending[1], op = first & 15, fin = !!(first & 128), masked = !!(second & 128);
  #|         let len = second & 127, offset = 2;
  #|         if (len === 126) { if (pending.length < 4) return; len = pending.readUInt16BE(2); offset = 4; }
  #|         else if (len === 127) { if (pending.length < 10) return; const high = pending.readUInt32BE(2); const low = pending.readUInt32BE(6); len = high * 0x100000000 + low; offset = 10; }
  #|         const mask = masked ? 4 : 0;
  #|         if (pending.length < offset + mask + len) return;
  #|         const payload = Buffer.from(pending.subarray(offset + mask, offset + mask + len));
  #|         if (masked) for (let i = 0; i < len; i++) payload[i] ^= pending[offset + (i & 3)];
  #|         pending = pending.subarray(offset + mask + len);
  #|         processFrame(op, fin, payload);
  #|       }
  #|     });
  #|   });
  #|   server.once('error', reject);
  #|   server.listen(0, '127.0.0.1', () => { const port = server.address().port; servers.set(port, {server, clients}); resolve(port); });
  #| })

///|
extern "js" fn stop_echo_server(port : Int) =
  #| (port) => {
  #|   const state = globalThis.__moonbit_ws_echo_servers.get(port);
  #|   if (state) { for (const client of state.clients) client.destroy(); state.server.close(); globalThis.__moonbit_ws_echo_servers.delete(port); }
  #| }

///|
async test "text echo" {
  let port = start_echo_server().wait()
  defer stop_echo_server(port)
  let conn = @websocket.connect("ws://127.0.0.1:\{port}")
  defer conn.close()
  conn.send_text("hello")
  let message = conn.recv()
  assert_true(message.kind is Text)
  assert_eq(message.read_all().text(), "hello")
}

///|
async test "binary echo" {
  let port = start_echo_server().wait()
  defer stop_echo_server(port)
  let conn = @websocket.connect("ws://127.0.0.1:\{port}")
  defer conn.close()
  conn.send_binary(b"\x00\x01\xff")
  let message = conn.recv()
  assert_true(message.kind is Binary)
  assert_eq(message.read_all().binary(), b"\x00\x01\xff")
}

///|
async test "streaming write" {
  let port = start_echo_server().wait()
  defer stop_echo_server(port)
  let conn = @websocket.connect("ws://127.0.0.1:\{port}")
  defer conn.close()
  conn.start_message(Text)
  conn.write(b"ab")
  conn.write(b"cd")
  conn.end_message()
  assert_eq(conn.recv().read_all().text(), "abcd")
}

///|
async test "server close is sticky" {
  let port = start_echo_server().wait()
  defer stop_echo_server(port)
  let conn = @websocket.connect("ws://127.0.0.1:\{port}")
  defer conn.close()
  conn.send_text("close 4001 bye")
  for _ in 0..<2 {
    try {
      ignore(conn.recv())
      fail("expected closed connection")
    } catch {
      @websocket.WebSocketError::ConnectionClosed(Other(4001), Some("bye")) =>
        ()
      error => raise error
    }
  }
}

///|
async test "client close" {
  let port = start_echo_server().wait()
  defer stop_echo_server(port)
  let conn = @websocket.connect("ws://127.0.0.1:\{port}")
  defer conn.close()
  conn.send_close(code=Normal)
  try {
    ignore(conn.recv())
    fail("expected closed connection")
  } catch {
    @websocket.WebSocketError::ConnectionClosed(Normal, _) => ()
    error => raise error
  }
}

///|
async test "refused connection" {
  try {
    ignore(@websocket.connect("ws://127.0.0.1:9"))
    fail("expected refusal")
  } catch {
    @websocket.WebSocketError::InvalidHandshake(_) => ()
    error => raise error
  }
}

///|
async test "cancelled recv loses nothing" {
  let port = start_echo_server().wait()
  defer stop_echo_server(port)
  let conn = @websocket.connect("ws://127.0.0.1:\{port}")
  defer conn.close()
  try {
    ignore(@async.with_timeout(50, () => conn.recv()))
    fail("expected timeout")
  } catch {
    @async.TimeoutError => ()
    error => raise error
  }
  conn.send_text("later")
  assert_eq(conn.recv().read_all().text(), "later")
}

///|
async test "headers rejected" {
  let port = start_echo_server().wait()
  defer stop_echo_server(port)
  defer stop_echo_server(port)
  let headers : Map[@http.CaseInsensitiveString, String] = { "X-A": "b" }
  try {
    ignore(@websocket.connect("ws://127.0.0.1:\{port}", headers~))
    fail("expected rejection")
  } catch {
    @websocket.WebSocketError::InvalidHandshake(_) => ()
    error => raise error
  }
}
