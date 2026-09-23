import { handleInteraction } from "./handler.js";
import {
  deferredMessageJson,
  generateSigningKeys,
  interaction,
  signedRequest,
} from "./test_support.mjs";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const { privateKey, publicKey } = await generateSigningKeys();
const config = { publicKey, token: "test-token", applicationId: "400000000000000001" };
const background = [];
const dispatch = (request) =>
  handleInteraction(request, config, (promise) => background.push(promise));

const url = "https://example.test/interactions";

const ping = await dispatch(await signedRequest(url, interaction(1), privateKey));
assert(ping.status === 200 && await ping.text() === '{"type":1}', "signed PING failed");

const echo = await dispatch(await signedRequest(
  url,
  interaction(2, "echo", [{ name: "text", type: 3, value: "JS runtimes" }]),
  privateKey,
));
assert(
  echo.status === 200 &&
    await echo.text() === '{"type":4,"data":{"content":"JS runtimes"}}',
  "echo failed",
);

const unsigned = await dispatch(new Request(url, {
  method: "POST",
  body: interaction(1),
}));
assert(unsigned.status === 401, "unsigned PING was accepted");

const calls = [];
const originalFetch = globalThis.fetch;
globalThis.fetch = async (input, init) => {
  const requestUrl = typeof input === "string" ? input : input.url;
  calls.push({ url: requestUrl, method: init?.method ?? input.method, body: await new Response(init?.body).text() });
  return Response.json(deferredMessageJson());
};
try {
  const slow = await dispatch(await signedRequest(url, interaction(2, "slow"), privateKey));
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
