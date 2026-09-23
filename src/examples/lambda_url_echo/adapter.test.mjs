import assert from "node:assert/strict";
import { test } from "node:test";
import { createLambdaUrlHandler } from "./adapter.js";

const timestamp = "1787716800";
const hex = (bytes) =>
  Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");

async function signedEvent(body, privateKey, base64) {
  const bytes = new TextEncoder().encode(body);
  const message = new Uint8Array(new TextEncoder().encode(timestamp).length + bytes.length);
  message.set(new TextEncoder().encode(timestamp));
  message.set(bytes, timestamp.length);
  const signature = await crypto.subtle.sign("Ed25519", privateKey, message);
  return {
    version: "2.0",
    rawPath: "/interactions",
    rawQueryString: "",
    headers: {
      "x-signature-ed25519": hex(signature),
      "x-signature-timestamp": timestamp,
    },
    requestContext: { http: { method: "POST" } },
    body: base64 ? Buffer.from(bytes).toString("base64") : body,
    isBase64Encoded: base64,
  };
}

test("Lambda URL adapter preserves raw signed body in both event encodings", async () => {
  const keys = await crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"]);
  const publicKey = hex(await crypto.subtle.exportKey("raw", keys.publicKey));
  const handler = createLambdaUrlHandler({ publicKey, token: "test-token", applicationId: "400000000000000001" });
  const body = JSON.stringify({
    id: "500000000000000201",
    application_id: "400000000000000001",
    type: 1,
    token: "interaction-token",
    version: 1,
  });
  for (const base64 of [false, true]) {
    const event = await signedEvent(body, keys.privateKey, base64);
    const result = await handler(event);
    assert.equal(result.statusCode, 200);
    assert.equal(result.isBase64Encoded, true);
    assert.equal(Buffer.from(result.body, "base64").toString("utf8"), '{"type":1}');

    event.body = base64 ? Buffer.from("{}").toString("base64") : "{}";
    const altered = await handler(event);
    assert.equal(altered.statusCode, 401);
  }

  const file = JSON.stringify({
    ...JSON.parse(body),
    type: 2,
    user: {
      id: "200000000000000001",
      username: "nelly",
      discriminator: "0",
      global_name: "Nelly",
      avatar: null,
    },
    data: { id: "600000000000000201", name: "file", type: 1 },
  });
  const fileResult = await handler(await signedEvent(file, keys.privateKey, true));
  assert.equal(fileResult.statusCode, 200);
  assert.match(fileResult.headers["content-type"], /^multipart\/form-data; boundary=/);
  assert.match(Buffer.from(fileResult.body, "base64").toString("utf8"), /hello from MoonBit/);
});
