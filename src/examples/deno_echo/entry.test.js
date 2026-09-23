import { createHandler } from "./entry.js";

const encoder = new TextEncoder();
const timestamp = "1787716800";
const applicationId = "400000000000000001";

function hex(bytes) {
  return Array.from(
    new Uint8Array(bytes),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

async function signedRequest(url, body, privateKey) {
  const bytes = typeof body === "string" ? encoder.encode(body) : body;
  const message = new Uint8Array(
    encoder.encode(timestamp).length + bytes.length,
  );
  message.set(encoder.encode(timestamp));
  message.set(bytes, encoder.encode(timestamp).length);
  const signature = await crypto.subtle.sign("Ed25519", privateKey, message);
  return fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-signature-ed25519": hex(signature),
      "x-signature-timestamp": timestamp,
    },
    body: bytes,
  });
}

function interaction(type, name, options) {
  return JSON.stringify({
    id: "500000000000000201",
    application_id: applicationId,
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

Deno.test("Deno.serve uses the shared signed Interaction dispatch", async () => {
  const keys = await crypto.subtle.generateKey("Ed25519", true, [
    "sign",
    "verify",
  ]);
  const publicKey = hex(await crypto.subtle.exportKey("raw", keys.publicKey));
  const restCalls = [];
  const rest = Deno.serve(
    { hostname: "127.0.0.1", port: 0 },
    async (request) => {
      restCalls.push({
        method: request.method,
        path: new URL(request.url).pathname,
        body: await request.text(),
      });
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
  );
  const failures = [];
  const handler = createHandler({
    publicKey,
    token: "test-token",
    applicationId: "400000000000000001",
    apiBaseUrl: `http://127.0.0.1:${rest.addr.port}`,
  }, (error) => failures.push(error));
  const server = Deno.serve({ hostname: "127.0.0.1", port: 0 }, handler);
  const url = `http://127.0.0.1:${server.addr.port}/interactions`;
  try {
    const get = await fetch(url);
    if (get.status !== 405) throw new Error(`GET: ${get.status}`);
    await get.body?.cancel();

    const unsigned = await fetch(url, { method: "POST", body: interaction(1) });
    if (unsigned.status !== 401) {
      throw new Error(`unsigned: ${unsigned.status}`);
    }
    await unsigned.body?.cancel();

    const ping = await signedRequest(url, interaction(1), keys.privateKey);
    if (ping.status !== 200 || await ping.text() !== '{"type":1}') {
      throw new Error("signed PING failed");
    }

    const echo = await signedRequest(
      url,
      interaction(2, "echo", [
        { name: "text", type: 3, value: "hello from Deno" },
      ]),
      keys.privateKey,
    );
    if (
      echo.status !== 200 ||
      await echo.text() !== '{"type":4,"data":{"content":"hello from Deno"}}'
    ) {
      throw new Error("echo response failed");
    }

    const badJson = await signedRequest(url, "{", keys.privateKey);
    if (badJson.status !== 400) {
      throw new Error(`invalid JSON: ${badJson.status}`);
    }
    await badJson.body?.cancel();

    const slow = await signedRequest(
      url,
      interaction(2, "slow"),
      keys.privateKey,
    );
    if (slow.status !== 200 || await slow.text() !== '{"type":5,"data":{}}') {
      throw new Error("deferred ACK failed");
    }
    await handler.whenIdle();
    if (failures.length !== 0) throw failures[0];
    if (
      restCalls.length !== 1 || restCalls[0].method !== "PATCH" ||
      restCalls[0].path !==
        `/api/v10/webhooks/${applicationId}/interaction-token/messages/@original` ||
      JSON.parse(restCalls[0].body).content !== "Finished in the background."
    ) {
      throw new Error(
        `deferred REST call differed: ${JSON.stringify(restCalls)}`,
      );
    }
  } finally {
    await handler.whenIdle();
    await Promise.all([server.shutdown(), rest.shutdown()]);
  }
});
