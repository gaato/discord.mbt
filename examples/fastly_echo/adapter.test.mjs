import assert from "node:assert/strict";
import { test } from "node:test";
import { respondToFetchEvent } from "./adapter.js";
import {
  deferredMessageJson,
  generateSigningKeys,
  interaction,
  signedRequest,
} from "../interactions_js/test_support.mjs";

const url = "https://example.test/interactions";

test("Fastly registers lifetime synchronously and waits for deferred work", async () => {
  const { privateKey, publicKey } = await generateSigningKeys();
  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    calls.push({ url: typeof input === "string" ? input : input.url, method: init.method });
    return Response.json(deferredMessageJson());
  };
  try {
    const order = [];
    let responding;
    let lifetime;
    const event = {
      request: await signedRequest(url, interaction(2, "slow"), privateKey),
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
