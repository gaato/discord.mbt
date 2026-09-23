import { expect, test } from "bun:test";
import { createHandler } from "./entry.js";

const timestamp = "1787716800";
const applicationId = "400000000000000001";
const hex = (bytes) =>
  Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");

function interaction(type, name) {
  return JSON.stringify({
    id: "500000000000000201",
    application_id: applicationId,
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

async function signedRequest(url, body, privateKey) {
  const signature = await crypto.subtle.sign(
    "Ed25519",
    privateKey,
    new TextEncoder().encode(timestamp + body),
  );
  return fetch(url, {
    method: "POST",
    headers: {
      "x-signature-ed25519": hex(signature),
      "x-signature-timestamp": timestamp,
    },
    body,
  });
}

test("Bun.serve runs signed MoonBit interactions and deferred REST", async () => {
  const keys = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]);
  const publicKey = hex(await crypto.subtle.exportKey("raw", keys.publicKey));
  const calls = [];
  const rest = Bun.serve({
    hostname: "127.0.0.1",
    port: 0,
    async fetch(request) {
      calls.push({ method: request.method, path: new URL(request.url).pathname });
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
    },
  });
  const failures = [];
  const handler = createHandler({
    publicKey,
    token: "test-token",
    applicationId: "400000000000000001",
    apiBaseUrl: `http://127.0.0.1:${rest.port}`,
  }, (error) => failures.push(error));
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, fetch: handler });
  const url = `http://127.0.0.1:${server.port}/interactions`;
  try {
    expect((await fetch(url)).status).toBe(405);
    expect((await fetch(url, { method: "POST", body: interaction(1) })).status).toBe(401);

    const ping = await signedRequest(url, interaction(1), keys.privateKey);
    expect(ping.status).toBe(200);
    expect(await ping.text()).toBe('{"type":1}');

    const slow = await signedRequest(url, interaction(2, "slow"), keys.privateKey);
    expect(slow.status).toBe(200);
    expect(await slow.text()).toBe('{"type":5,"data":{}}');
    await handler.whenIdle();
    expect(failures).toEqual([]);
    expect(calls).toEqual([{
      method: "PATCH",
      path: `/api/v10/webhooks/${applicationId}/interaction-token/messages/@original`,
    }]);
  } finally {
    await handler.whenIdle();
    server.stop(true);
    rest.stop(true);
  }
});
