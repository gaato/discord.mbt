// Shared fixtures and signing helpers for the JavaScript host-adapter tests.
// Web APIs only: this file loads unchanged under Node's node:test, vitest
// inside workerd, Deno and Bun.

const encoder = new TextEncoder();

export const TIMESTAMP = "1787716800";
export const APPLICATION_ID = "400000000000000001";

export function hex(bytes) {
  return Array.from(new Uint8Array(bytes), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

// Generates an Ed25519 keypair for signing test requests. `publicKey` is
// returned as the hex string the adapters take as config.
export async function generateSigningKeys() {
  const { privateKey, publicKey } = await crypto.subtle.generateKey(
    "Ed25519",
    true,
    ["sign", "verify"],
  );
  return {
    privateKey,
    publicKey: hex(await crypto.subtle.exportKey("raw", publicKey)),
  };
}

// The shared interaction fixture builder: a superset of the per-file
// variants it replaces. `options` is only ever attached for command
// interactions (type 2) and is omitted entirely when not given.
export function interaction(type, name, options) {
  return JSON.stringify({
    id: "500000000000000201",
    application_id: APPLICATION_ID,
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

function toBytes(body) {
  return typeof body === "string" ? encoder.encode(body) : new Uint8Array(body);
}

// Signs `timestamp + body` with Ed25519 via WebCrypto and returns the two
// Discord signature headers.
export async function signatureHeaders(bodyBytes, privateKey, timestamp = TIMESTAMP) {
  const bytes = toBytes(bodyBytes);
  const timestampBytes = encoder.encode(timestamp);
  const message = new Uint8Array(timestampBytes.length + bytes.length);
  message.set(timestampBytes);
  message.set(bytes, timestampBytes.length);
  const signature = await crypto.subtle.sign("Ed25519", privateKey, message);
  return {
    "x-signature-ed25519": hex(signature),
    "x-signature-timestamp": timestamp,
  };
}

// Builds a signed POST Request. `body` may be a string or raw bytes, and
// `init` may carry `signal`, extra `headers` and a `signingKey` override
// (used by the key-rotation test).
export async function signedRequest(url, body, privateKey, init = {}) {
  const { signal, headers, signingKey } = init;
  const bodyBytes = toBytes(body);
  const sigHeaders = await signatureHeaders(bodyBytes, signingKey ?? privateKey);
  return new Request(url, {
    method: "POST",
    headers: { ...headers, ...sigHeaders },
    body: bodyBytes,
    signal,
  });
}

// The fake Discord message JSON returned by the mocked REST call answering
// the deferred `/slow` PATCH.
export function deferredMessageJson() {
  return {
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
  };
}
