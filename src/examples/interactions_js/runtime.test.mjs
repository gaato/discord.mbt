import { handleInteraction } from "./handler.js";

const encoder = new TextEncoder();
const timestamp = "1787716800";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function hex(bytes) {
  return Array.from(new Uint8Array(bytes), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
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

async function signedRequest(body, privateKey) {
  const bodyBytes = encoder.encode(body);
  const message = encoder.encode(timestamp + body);
  const signature = await crypto.subtle.sign("Ed25519", privateKey, message);
  return new Request("https://example.test/interactions", {
    method: "POST",
    headers: {
      "x-signature-ed25519": hex(signature),
      "x-signature-timestamp": timestamp,
    },
    body: bodyBytes,
  });
}

const keys = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]);
const publicKey = hex(await crypto.subtle.exportKey("raw", keys.publicKey));
const config = { publicKey, token: "test-token", applicationId: "400000000000000001" };
const background = [];
const dispatch = (request) =>
  handleInteraction(request, config, (promise) => background.push(promise));

const ping = await dispatch(await signedRequest(interaction(1), keys.privateKey));
assert(ping.status === 200 && await ping.text() === '{"type":1}', "signed PING failed");

const echo = await dispatch(await signedRequest(
  interaction(2, "echo", [{ name: "text", type: 3, value: "JS runtimes" }]),
  keys.privateKey,
));
assert(
  echo.status === 200 &&
    await echo.text() === '{"type":4,"data":{"content":"JS runtimes"}}',
  "echo failed",
);

const unsigned = await dispatch(new Request("https://example.test/interactions", {
  method: "POST",
  body: interaction(1),
}));
assert(unsigned.status === 401, "unsigned PING was accepted");

const calls = [];
const originalFetch = globalThis.fetch;
globalThis.fetch = async (input, init) => {
  const url = typeof input === "string" ? input : input.url;
  calls.push({ url, method: init?.method ?? input.method, body: await new Response(init?.body).text() });
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
  const slow = await dispatch(await signedRequest(interaction(2, "slow"), keys.privateKey));
  assert(slow.status === 200 && await slow.text() === '{"type":5,"data":{}}', "deferred ACK failed");
  await Promise.all(background);
  assert(calls.length === 1, "deferred REST count differs");
  assert(calls[0].method === "PATCH", "deferred REST method differs");
  assert(calls[0].url === "https://discord.com/api/v10/webhooks/400000000000000001/interaction-token/messages/@original", "deferred REST URL differs");
  assert(JSON.parse(calls[0].body).content === "Finished in the background.", "deferred REST payload differs");
} finally {
  globalThis.fetch = originalFetch;
}

console.log("Shared MoonBit interaction dispatch passed");
