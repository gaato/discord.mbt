import assert from "node:assert/strict";
import { test } from "node:test";
import { createVercelHandler } from "./adapter.js";
import {
  deferredMessageJson,
  generateSigningKeys,
  interaction,
  signedRequest,
} from "../interactions_js/test_support.mjs";

const url = "https://example.test/api/interactions";

test("Vercel fetch adapter passes deferred work to waitUntil", async () => {
  const { privateKey, publicKey } = await generateSigningKeys();
  const pending = [];
  const failures = [];
  const handler = createVercelHandler(
    { publicKey, token: "test-token", applicationId: "400000000000000001" },
    (background) => pending.push(background),
    (error) => failures.push(error),
  );

  const ping = await handler.fetch(await signedRequest(url, interaction(1), privateKey));
  assert.equal(ping.status, 200);
  assert.equal(await ping.text(), '{"type":1}');

  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const requestUrl = typeof input === "string" ? input : input.url;
    calls.push({ url: requestUrl, method: init?.method ?? input.method });
    return Response.json(deferredMessageJson());
  };
  try {
    const slow = await handler.fetch(await signedRequest(url, interaction(2, "slow"), privateKey));
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
