import assert from "node:assert/strict";
import { test } from "node:test";
import { createLambdaUrlHandler } from "./adapter.js";
import {
  generateSigningKeys,
  interaction,
  signatureHeaders,
} from "../interactions_js/test_support.mjs";

async function signedEvent(body, privateKey, base64) {
  const bytes = new TextEncoder().encode(body);
  const headers = await signatureHeaders(bytes, privateKey);
  return {
    version: "2.0",
    rawPath: "/interactions",
    rawQueryString: "",
    headers,
    requestContext: { http: { method: "POST" } },
    body: base64 ? Buffer.from(bytes).toString("base64") : body,
    isBase64Encoded: base64,
  };
}

test("Lambda URL adapter preserves raw signed body in both event encodings", async () => {
  const { privateKey, publicKey } = await generateSigningKeys();
  const handler = createLambdaUrlHandler({ publicKey, token: "test-token", applicationId: "400000000000000001" });
  const body = interaction(1);
  for (const base64 of [false, true]) {
    const event = await signedEvent(body, privateKey, base64);
    const result = await handler(event);
    assert.equal(result.statusCode, 200);
    assert.equal(result.isBase64Encoded, true);
    assert.equal(Buffer.from(result.body, "base64").toString("utf8"), '{"type":1}');

    event.body = base64 ? Buffer.from("{}").toString("base64") : "{}";
    const altered = await handler(event);
    assert.equal(altered.statusCode, 401);
  }

  const file = interaction(2, "file");
  const fileResult = await handler(await signedEvent(file, privateKey, true));
  assert.equal(fileResult.statusCode, 200);
  assert.match(fileResult.headers["content-type"], /^multipart\/form-data; boundary=/);
  assert.match(Buffer.from(fileResult.body, "base64").toString("utf8"), /hello from MoonBit/);
});
