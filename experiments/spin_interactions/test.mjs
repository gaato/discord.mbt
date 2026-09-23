import assert from "node:assert/strict";
import { createServer } from "node:net";
import { spawn } from "node:child_process";
import { generateKeyPairSync, sign } from "node:crypto";
import { once } from "node:events";
import { test } from "node:test";

const timestamp = "1787716800";
const encoder = new TextEncoder();
const { privateKey, publicKey } = generateKeyPairSync("ed25519");
const publicKeyHex = publicKey.export({ type: "spki", format: "der" }).subarray(
  -32,
).toString("hex");
const spin = process.env.SPIN_BIN ?? "spin";

async function freePort() {
  const server = createServer();
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const port = server.address().port;
  server.close();
  await once(server, "close");
  return port;
}

function signed(body, key = privateKey) {
  const bytes = typeof body === "string" ? encoder.encode(body) : body;
  return {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-signature-timestamp": timestamp,
      "x-signature-ed25519": sign(
        null,
        Buffer.concat([encoder.encode(timestamp), bytes]),
        key,
      ).toString("hex"),
    },
    body: bytes,
  };
}

function interaction(type, name, options) {
  return JSON.stringify({
    id: "500000000000000201",
    application_id: "400000000000000001",
    type,
    token: "interaction-token",
    version: 1,
    ...(type === 2
      ? {
        user: {
          id: "200000000000000001",
          username: "nelly",
          discriminator: "0",
          global_name: "Nelly",
          avatar: null,
        },
        data: {
          id: "600000000000000201",
          name,
          type: 1,
          ...(options ? { options } : {}),
        },
      }
      : {}),
  });
}

test("Spin 4.1 WASIp2 component handles signed Discord interactions", async () => {
  const port = await freePort();
  const url = `http://127.0.0.1:${port}/interactions`;
  const child = spawn(spin, [
    "up",
    "-f",
    "spin.toml",
    "--listen",
    `127.0.0.1:${port}`,
    "--variable",
    `discord_public_key=${publicKeyHex}`,
  ], { cwd: import.meta.dirname, stdio: ["ignore", "pipe", "pipe"] });
  let stderr = "";
  child.stderr.on("data", (chunk) => {
    stderr += chunk;
  });
  try {
    let ready = false;
    for (let attempt = 0; attempt < 300; attempt++) {
      if (child.exitCode !== null) throw new Error(`Spin exited: ${stderr}`);
      try {
        const response = await fetch(url);
        ready = response.status === 405;
        await response.body?.cancel();
        if (ready) break;
      } catch { /* still starting */ }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.ok(ready, `Spin did not become ready: ${stderr}`);

    const unsigned = await fetch(url, { method: "POST", body: interaction(1) });
    assert.equal(unsigned.status, 401);
    await unsigned.body?.cancel();

    const otherKey = generateKeyPairSync("ed25519").privateKey;
    const wrongSignature = await fetch(url, signed(interaction(1), otherKey));
    assert.equal(wrongSignature.status, 401);
    await wrongSignature.body?.cancel();

    const ping = await fetch(url, signed(interaction(1)));
    const pingText = await ping.text();
    assert.equal(ping.status, 200, pingText);
    assert.equal(pingText, '{"type":1}');

    const echo = await fetch(
      url,
      signed(interaction(2, "echo", [
        { name: "text", type: 3, value: "hello from Spin" },
      ])),
    );
    assert.equal(echo.status, 200);
    assert.equal(
      await echo.text(),
      '{"type":4,"data":{"content":"hello from Spin"}}',
    );

    const badJson = await fetch(url, signed("{"));
    assert.equal(badJson.status, 400);
    await badJson.body?.cancel();

    const invalidInteraction = await fetch(url, signed('{"type":2}'));
    assert.equal(invalidInteraction.status, 400);
    await invalidInteraction.body?.cancel();

    const invalidUtf8 = await fetch(
      url,
      signed(new Uint8Array([0xff, 0x7b, 0x7d])),
    );
    assert.equal(invalidUtf8.status, 400);
    await invalidUtf8.body?.cancel();
  } finally {
    if (child.exitCode === null && child.signalCode === null) {
      child.kill("SIGINT");
      await once(child, "exit");
    }
  }
});
