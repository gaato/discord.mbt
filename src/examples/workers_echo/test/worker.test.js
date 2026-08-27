import {
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import worker from "../entry.js";

const encoder = new TextEncoder();
const workerUrl = "https://worker.example/interactions";
const timestamp = "1787716800";

let privateKey;
let publicKeyHex;
let rotatedPrivateKey;
let rotatedPublicKeyHex;

function hex(bytes) {
  return Array.from(new Uint8Array(bytes), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

beforeAll(async () => {
  const keys = await crypto.subtle.generateKey(
    { name: "Ed25519" },
    true,
    ["sign", "verify"],
  );
  privateKey = keys.privateKey;
  publicKeyHex = hex(await crypto.subtle.exportKey("raw", keys.publicKey));
  const rotatedKeys = await crypto.subtle.generateKey(
    { name: "Ed25519" },
    true,
    ["sign", "verify"],
  );
  rotatedPrivateKey = rotatedKeys.privateKey;
  rotatedPublicKeyHex = hex(
    await crypto.subtle.exportKey("raw", rotatedKeys.publicKey),
  );
});

afterEach(() => {
  vi.unstubAllGlobals();
});

async function signedRequest(body, { signal, signingKey = privateKey } = {}) {
  const bodyBytes =
    typeof body === "string" ? encoder.encode(body) : new Uint8Array(body);
  const timestampBytes = encoder.encode(timestamp);
  const message = new Uint8Array(timestampBytes.length + bodyBytes.length);
  message.set(timestampBytes);
  message.set(bodyBytes, timestampBytes.length);
  const signature = await crypto.subtle.sign(
    { name: "Ed25519" },
    signingKey,
    message,
  );
  return new Request(workerUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-signature-ed25519": hex(signature),
      "x-signature-timestamp": timestamp,
    },
    body: bodyBytes,
    signal,
  });
}

async function dispatch(request, env = {}) {
  const ctx = createExecutionContext();
  const response = await worker.fetch(
    request,
    {
      DISCORD_PUBLIC_KEY: publicKeyHex,
      DISCORD_TOKEN: "test-token",
      ...env,
    },
    ctx,
  );
  return { ctx, response };
}

function pingBody() {
  return JSON.stringify({
    id: "500000000000000200",
    application_id: "400000000000000001",
    type: 1,
    token: "interaction-token",
    version: 1,
  });
}

function commandBody(name, options) {
  return JSON.stringify({
    id: "500000000000000201",
    application_id: "400000000000000001",
    type: 2,
    token: "interaction-token",
    version: 1,
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
  });
}

describe("Cloudflare Worker interaction endpoint", () => {
  it("rejects non-POST methods", async () => {
    const { ctx, response } = await dispatch(new Request(workerUrl));
    expect(response.status).toBe(405);
    expect(await response.text()).toBe("Method Not Allowed");
    await waitOnExecutionContext(ctx);
  });

  it("rejects missing and invalid signatures", async () => {
    const missing = await dispatch(
      new Request(workerUrl, { method: "POST", body: pingBody() }),
    );
    expect(missing.response.status).toBe(401);

    const invalid = await dispatch(
      new Request(workerUrl, {
        method: "POST",
        headers: {
          "x-signature-ed25519": "00".repeat(64),
          "x-signature-timestamp": timestamp,
        },
        body: pingBody(),
      }),
    );
    expect(invalid.response.status).toBe(401);
  });

  it("maps invalid JSON and structurally invalid interactions to 400", async () => {
    const invalidJson = await dispatch(await signedRequest("{"));
    expect(invalidJson.response.status).toBe(400);
    expect(await invalidJson.response.text()).toBe("Invalid JSON");

    const invalidInteraction = await dispatch(
      await signedRequest('{"type":2}'),
    );
    expect(invalidInteraction.response.status).toBe(400);
    expect(await invalidInteraction.response.text()).toBe(
      "Invalid interaction payload",
    );
    await waitOnExecutionContext(invalidInteraction.ctx);
  });

  it("verifies raw bytes before rejecting invalid UTF-8", async () => {
    const invalidUtf8 = new Uint8Array([0xff, 0x7b, 0x7d]);
    const { ctx, response } = await dispatch(
      await signedRequest(invalidUtf8),
    );
    expect(response.status).toBe(400);
    expect(await response.text()).toBe("Invalid JSON");
    await waitOnExecutionContext(ctx);
  });

  it("rebuilds the cached verifier when the public key changes", async () => {
    const body = pingBody();
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
      await signedRequest(pingBody()),
      { DISCORD_PUBLIC_KEY: "z".repeat(64) },
    );
    expect(response.status).toBe(401);
    await waitOnExecutionContext(ctx);
  });

  it("answers signed PING requests", async () => {
    const { ctx, response } = await dispatch(await signedRequest(pingBody()));
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("application/json");
    expect(await response.text()).toBe('{"type":1}');
    await waitOnExecutionContext(ctx);
  });

  it("returns an exact echo response", async () => {
    const body = commandBody("echo", [
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
    const body = commandBody("missing");
    const { ctx, response } = await dispatch(await signedRequest(body));
    expect(response.status).toBe(404);
    expect(await response.text()).toBe("No interaction route");
    await waitOnExecutionContext(ctx);
  });

  it("streams multipart file replies in wire order", async () => {
    const body = commandBody("file");
    const { ctx, response } = await dispatch(await signedRequest(body));
    expect(response.status).toBe(200);
    const contentType = response.headers.get("content-type");
    expect(contentType).toMatch(
      /^multipart\/form-data; boundary=discordmbt-/,
    );
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
    expect(wire).toContain("content-type: text/plain\r\n");
    expect(wire.endsWith(`--${boundary}--\r\n`)).toBe(true);
    await waitOnExecutionContext(ctx);
  });

  it("allows a multipart response body to be cancelled without orphan work", async () => {
    const body = commandBody("file");
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
        JSON.stringify({
          id: "700000000000000009",
          channel_id: "800000000000000001",
          author: {
            id: "1",
            username: "bot",
            discriminator: "0",
            avatar: null,
          },
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
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    const controller = new AbortController();
    const request = await signedRequest(commandBody("slow"), {
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

  it("rejects a pre-aborted response waiter but completes the background", async () => {
    const moonbit = await import(
      "../../../../_build/js/release/build/examples/workers_echo/workers_echo.js"
    );
    const controller = new AbortController();
    controller.abort();
    const dispatchResult = moonbit.start_interaction(
      "test-token",
      commandBody("echo", [
        { name: "text", type: 3, value: "already aborted" },
      ]),
      controller.signal,
    );
    await expect(dispatchResult.response).rejects.toMatchObject({
      name: "AbortError",
    });
    await expect(dispatchResult.background).resolves.toBeUndefined();
  });
});
