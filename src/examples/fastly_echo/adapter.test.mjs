import assert from "node:assert/strict";
import { test } from "node:test";
import { respondToFetchEvent } from "./adapter.js";

const timestamp = "1787716800";
const hex = (bytes) =>
  Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");

async function signedRequest(body, privateKey) {
  const signature = await crypto.subtle.sign(
    "Ed25519",
    privateKey,
    new TextEncoder().encode(timestamp + body),
  );
  return new Request("https://example.test/interactions", {
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

test("Fastly registers lifetime synchronously and waits for deferred work", async () => {
  const keys = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]);
  const publicKey = hex(await crypto.subtle.exportKey("raw", keys.publicKey));
  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    calls.push({ url: typeof input === "string" ? input : input.url, method: init.method });
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
    const order = [];
    let responding;
    let lifetime;
    const event = {
      request: await signedRequest(interaction(2, "slow"), keys.privateKey),
      waitUntil(promise) {
        order.push("waitUntil");
        lifetime = promise;
      },
      respondWith(promise) {
        order.push("respondWith");
        responding = promise;
      },
    };
    respondToFetchEvent(event, { publicKey, token: "test-token", applicationId: "400000000000000001" });
    assert.deepEqual(order, ["waitUntil", "respondWith"]);
    const response = await responding;
    assert.equal(await response.text(), '{"type":5,"data":{}}');
    await lifetime;
    assert.deepEqual(calls, [{
      url: "https://discord.com/api/v10/webhooks/400000000000000001/interaction-token/messages/@original",
      method: "PATCH",
    }]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
