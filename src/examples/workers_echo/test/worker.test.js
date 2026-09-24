import {
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import worker from "../entry.js";
import {
  deferredMessageJson,
  generateSigningKeys,
  interaction,
  signedRequest as sharedSignedRequest,
  TIMESTAMP,
} from "../../interactions_js/test_support.mjs";

const workerUrl = "https://worker.example/interactions";

let privateKey;
let publicKeyHex;
let rotatedPrivateKey;
let rotatedPublicKeyHex;

beforeAll(async () => {
  const keys = await generateSigningKeys();
  privateKey = keys.privateKey;
  publicKeyHex = keys.publicKey;
  const rotatedKeys = await generateSigningKeys();
  rotatedPrivateKey = rotatedKeys.privateKey;
  rotatedPublicKeyHex = rotatedKeys.publicKey;
});

afterEach(() => {
  vi.unstubAllGlobals();
});

async function signedRequest(body, { signal, signingKey = privateKey } = {}) {
  return sharedSignedRequest(workerUrl, body, privateKey, {
    signal,
    signingKey,
    headers: { "content-type": "application/json" },
  });
}

async function dispatch(request, env = {}) {
  const ctx = createExecutionContext();
  const response = await worker.fetch(
    request,
    {
      DISCORD_PUBLIC_KEY: publicKeyHex,
      DISCORD_TOKEN: "test-token",
      DISCORD_APPLICATION_ID: "400000000000000001",
      ...env,
    },
    ctx,
  );
  return { ctx, response };
}

describe("Cloudflare Worker interaction endpoint", () => {
  it("rejects non-POST methods", async () => {
    const { ctx, response } = await dispatch(new Request(workerUrl));
    expect(response.status).toBe(405);
    expect(await response.text()).toBe("method not allowed");
    await waitOnExecutionContext(ctx);
  });

  it("rejects missing and invalid signatures", async () => {
    const missing = await dispatch(
      new Request(workerUrl, { method: "POST", body: interaction(1) }),
    );
    expect(missing.response.status).toBe(401);

    const invalid = await dispatch(
      new Request(workerUrl, {
        method: "POST",
        headers: {
          "x-signature-ed25519": "00".repeat(64),
          "x-signature-timestamp": TIMESTAMP,
        },
        body: interaction(1),
      }),
    );
    expect(invalid.response.status).toBe(401);
  });

  it("maps invalid JSON and structurally invalid interactions to 400", async () => {
    const invalidJson = await dispatch(await signedRequest("{"));
    expect(invalidJson.response.status).toBe(400);
    expect(await invalidJson.response.text()).toBe("invalid interaction JSON");

    const invalidInteraction = await dispatch(
      await signedRequest('{"type":2}'),
    );
    expect(invalidInteraction.response.status).toBe(400);
    expect(await invalidInteraction.response.text()).toBe(
      "invalid interaction JSON",
    );
    await waitOnExecutionContext(invalidInteraction.ctx);
  });

  it("verifies raw bytes before rejecting invalid UTF-8", async () => {
    const invalidUtf8 = new Uint8Array([0xff, 0x7b, 0x7d]);
    const { ctx, response } = await dispatch(
      await signedRequest(invalidUtf8),
    );
    expect(response.status).toBe(400);
    expect(await response.text()).toBe("invalid UTF-8 body");
    await waitOnExecutionContext(ctx);
  });

  it("rebuilds the cached verifier when the public key changes", async () => {
    const body = interaction(1);
    const first = await dispatch(await signedRequest(body));
    expect(first.response.status).toBe(200);
    await waitOnExecutionContext(first.ctx);

    const rotated = await dispatch(
      await signedRequest(body, { signingKey: rotatedPrivateKey }),
      { DISCORD_PUBLIC_KEY: rotatedPublicKeyHex },
    );
    expect(rotated.response.status).toBe(200);
    await waitOnExecutionContext(rotated.ctx);
  });

  it("does not reuse a cached verifier for invalid configuration", async () => {
    const { ctx, response } = await dispatch(
      await signedRequest(interaction(1)),
      { DISCORD_PUBLIC_KEY: "z".repeat(64) },
    );
    expect(response.status).toBe(401);
    await waitOnExecutionContext(ctx);
  });

  it("answers signed PING requests", async () => {
    const { ctx, response } = await dispatch(await signedRequest(interaction(1)));
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("application/json");
    expect(await response.text()).toBe('{"type":1}');
    await waitOnExecutionContext(ctx);
  });

  it("returns an exact echo response", async () => {
    const body = interaction(2, "echo", [
      { name: "text", type: 3, value: "hello from workerd" },
    ]);
    const { ctx, response } = await dispatch(await signedRequest(body));
    expect(response.status).toBe(200);
    expect(await response.text()).toBe(
      '{"type":4,"data":{"content":"hello from workerd"}}',
    );
    await waitOnExecutionContext(ctx);
  });

  it("maps unknown commands to 404", async () => {
    const body = interaction(2, "missing");
    const { ctx, response } = await dispatch(await signedRequest(body));
    expect(response.status).toBe(404);
    expect(await response.text()).toBe("not found");
    await waitOnExecutionContext(ctx);
  });

  it("streams multipart file replies in wire order", async () => {
    const body = interaction(2, "file");
    const { ctx, response } = await dispatch(await signedRequest(body));
    expect(response.status).toBe(200);
    const contentType = response.headers.get("content-type");
    expect(contentType).toMatch(/^multipart\/form-data; boundary=[\w-]+$/);
    const boundary = contentType.slice(contentType.indexOf("boundary=") + 9);
    const wire = new TextDecoder().decode(await response.arrayBuffer());
    const payloadIndex = wire.indexOf('name="payload_json"');
    const fileIndex = wire.indexOf(
      'name="files[0]"; filename="hello.txt"',
    );
    const bytesIndex = wire.indexOf("hello from MoonBit\n");
    expect(payloadIndex).toBeGreaterThanOrEqual(0);
    expect(fileIndex).toBeGreaterThan(payloadIndex);
    expect(bytesIndex).toBeGreaterThan(fileIndex);
    expect(wire).toContain('"filename":"hello.txt"');
    expect(wire).toContain("Content-Type: text/plain\r\n");
    expect(wire.endsWith(`--${boundary}--\r\n`)).toBe(true);
    await waitOnExecutionContext(ctx);
  });

  it("allows a multipart response body to be cancelled without orphan work", async () => {
    const body = interaction(2, "file");
    const { ctx, response } = await dispatch(await signedRequest(body));
    const reader = response.body.getReader();
    expect((await reader.read()).done).toBe(false);
    await reader.cancel();
    await waitOnExecutionContext(ctx);
  });

  it("finishes deferred work after the incoming request is aborted", async () => {
    const calls = [];
    const fetchMock = vi.fn(async (input, init) => {
      const url = typeof input === "string" ? input : input.url;
      const method = init?.method ?? input.method;
      const requestBody = init?.body
        ? await new Response(init.body).text()
        : await input.clone().text();
      calls.push({ method, requestBody, url });
      return new Response(
        JSON.stringify(deferredMessageJson()),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    const controller = new AbortController();
    const request = await signedRequest(interaction(2, "slow"), {
      signal: controller.signal,
    });
    const { ctx, response } = await dispatch(request);
    expect(response.status).toBe(200);
    expect(await response.text()).toBe('{"type":5,"data":{}}');
    controller.abort();
    await waitOnExecutionContext(ctx);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(calls[0].method).toBe("PATCH");
    expect(calls[0].url).toBe(
      "https://discord.com/api/v10/webhooks/400000000000000001/interaction-token/messages/@original",
    );
    expect(JSON.parse(calls[0].requestBody)).toEqual({
      content: "Finished in the background.",
    });
  });

  it("finishes a deferred REST call when a 204 response has a null body", async () => {
    const calls = [];
    const fetchMock = vi.fn(async (input, init) => {
      const url = typeof input === "string" ? input : input.url;
      const method = init?.method ?? input.method;
      calls.push({ method, url });
      return new Response(null, { status: 204 });
    });
    vi.stubGlobal("fetch", fetchMock);

    const { ctx, response } = await dispatch(
      await signedRequest(interaction(2, "vanish")),
    );
    expect(response.status).toBe(200);
    expect(await response.text()).toBe('{"type":5,"data":{}}');
    await waitOnExecutionContext(ctx);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(calls[0]).toEqual({
      method: "DELETE",
      url: "https://discord.com/api/v10/webhooks/400000000000000001/interaction-token/messages/@original",
    });
  });

  it("rejects a pre-aborted response waiter but completes the background", async () => {
    const moonbit = await import(
      "../../../../_build/js/release/build/examples/interactions_js/interactions_js.js"
    );
    const controller = new AbortController();
    controller.abort();
    const signed = await signedRequest(interaction(2, "echo", [
      { name: "text", type: 3, value: "already aborted" },
    ]));
    const dispatchResult = moonbit.start_signed_interaction(
      "test-token",
      "400000000000000001",
      publicKeyHex,
      "POST",
      signed.headers.get("x-signature-ed25519"),
      TIMESTAMP,
      new Uint8Array(await signed.arrayBuffer()),
      "https://discord.com",
      controller.signal,
    );
    await expect(dispatchResult.response).rejects.toMatchObject({
      name: "AbortError",
    });
    await expect(dispatchResult.background).resolves.toBeUndefined();
  });
});
