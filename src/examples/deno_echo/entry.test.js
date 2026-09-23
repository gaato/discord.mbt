import { createHandler } from "./entry.js";
import {
  deferredMessageJson,
  generateSigningKeys,
  interaction,
  signedRequest,
} from "../interactions_js/test_support.mjs";

const applicationId = "400000000000000001";

Deno.test("Deno.serve uses the shared signed Interaction dispatch", async () => {
  const { privateKey, publicKey } = await generateSigningKeys();
  const restCalls = [];
  const rest = Deno.serve(
    { hostname: "127.0.0.1", port: 0 },
    async (request) => {
      restCalls.push({
        method: request.method,
        path: new URL(request.url).pathname,
        body: await request.text(),
      });
      return Response.json(deferredMessageJson());
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

    const ping = await fetch(await signedRequest(url, interaction(1), privateKey));
    if (ping.status !== 200 || await ping.text() !== '{"type":1}') {
      throw new Error("signed PING failed");
    }

    const echo = await fetch(await signedRequest(
      url,
      interaction(2, "echo", [
        { name: "text", type: 3, value: "hello from Deno" },
      ]),
      privateKey,
    ));
    if (
      echo.status !== 200 ||
      await echo.text() !== '{"type":4,"data":{"content":"hello from Deno"}}'
    ) {
      throw new Error("echo response failed");
    }

    const badJson = await fetch(await signedRequest(url, "{", privateKey));
    if (badJson.status !== 400) {
      throw new Error(`invalid JSON: ${badJson.status}`);
    }
    await badJson.body?.cancel();

    const slow = await fetch(await signedRequest(
      url,
      interaction(2, "slow"),
      privateKey,
    ));
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
