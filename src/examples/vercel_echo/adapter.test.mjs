import assert from "node:assert/strict";
import { test } from "node:test";
import { createVercelHandler } from "./adapter.js";

const encoder = new TextEncoder();
const timestamp = "1787716800";

function hex(bytes) {
  return Array.from(new Uint8Array(bytes), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

async function signedRequest(body, privateKey) {
  const signature = await crypto.subtle.sign(
    "Ed25519",
    privateKey,
    encoder.encode(timestamp + body),
  );
  return new Request("https://example.test/api/interactions", {
    method: "POST",
    headers: {
      "x-signature-ed25519": hex(signature),
      "x-signature-timestamp": timestamp,
    },
    body,
  });
}

function interaction(type, name) {
  return JSON.stringify({
    id: "500000000000000201",
    application_id: "400000000000000001",
    type,
    token: "interaction-token",
    version: 1,
    ...(type === 2 ? {
      user: {
        id: "200000000000000001",
        username: "nelly",
        discriminator: "0",
        global_name: "Nelly",
        avatar: null,
      },
      data: { id: "600000000000000201", name, type: 1 },
    } : {}),
  });
}

test("Vercel fetch adapter passes deferred work to waitUntil", async () => {
  const keys = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]);
  const publicKey = hex(await crypto.subtle.exportKey("raw", keys.publicKey));
  const pending = [];
  const failures = [];
  const handler = createVercelHandler(
    { publicKey, token: "test-token", applicationId: "400000000000000001" },
    (background) => pending.push(background),
    (error) => failures.push(error),
  );

  const ping = await handler.fetch(await signedRequest(interaction(1), keys.privateKey));
  assert.equal(ping.status, 200);
  assert.equal(await ping.text(), '{"type":1}');

  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const url = typeof input === "string" ? input : input.url;
    calls.push({ url, method: init?.method ?? input.method });
    return Response.json({
      id: "700000000000000009",
      channel_id: "800000000000000001",
      author: { id: "1", username: "bot", discriminator: "0", avatar: null },
      content: "Finished in the background.",
      timestamp: "2025-06-01T10:00:00.000000+00:00",
      edited_timestamp: null,
      tts: false,
      mention_everyone: false,
      mentions: [],
      mention_roles: [],
      attachments: [],
      embeds: [],
      pinned: false,
      type: 0,
    });
  };
  try {
    const slow = await handler.fetch(await signedRequest(interaction(2, "slow"), keys.privateKey));
    assert.equal(slow.status, 200);
    assert.equal(await slow.text(), '{"type":5,"data":{}}');
    assert.equal(pending.length, 2);
    await Promise.all(pending);
    assert.deepEqual(failures, []);
    assert.deepEqual(calls, [{
      url: "https://discord.com/api/v10/webhooks/400000000000000001/interaction-token/messages/@original",
      method: "PATCH",
    }]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
