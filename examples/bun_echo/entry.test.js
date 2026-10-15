import { expect, test } from "bun:test";
import { createHandler } from "./entry.js";
import {
  deferredMessageJson,
  generateSigningKeys,
  interaction,
  signedRequest,
} from "../interactions_js/test_support.mjs";

const applicationId = "400000000000000001";

test("Bun.serve runs signed MoonBit interactions and deferred REST", async () => {
  const { privateKey, publicKey } = await generateSigningKeys();
  const calls = [];
  const rest = Bun.serve({
    hostname: "127.0.0.1",
    port: 0,
    async fetch(request) {
      calls.push({ method: request.method, path: new URL(request.url).pathname });
      return Response.json(deferredMessageJson());
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

    const ping = await fetch(await signedRequest(url, interaction(1), privateKey));
    expect(ping.status).toBe(200);
    expect(await ping.text()).toBe('{"type":1}');

    const slow = await fetch(await signedRequest(url, interaction(2, "slow"), privateKey));
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
