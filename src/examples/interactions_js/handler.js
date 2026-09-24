// The generated MoonBit ESM module initializes its hasher with randomness.
// Loading it inside a request also works in runtimes that restrict startup I/O.
let modulePromise;
function loadMoonBit() {
  modulePromise ??= import(
    "../../../_build/js/release/build/examples/interactions_js/interactions_js.js"
  );
  return modulePromise;
}

// scheduleBackground must retain the returned promise until it settles.
// The input keeps the exact body bytes; hosts without Web Request can call this
// directly after decoding their own event envelope.
export async function handleRawInteraction(input, config, scheduleBackground) {
  const { start_signed_interaction } = await loadMoonBit();
  const { signature = "", timestamp = "", body: bodyBytes } = input;
  const { response, background } = start_signed_interaction(
    config.token ?? "",
    config.applicationId ?? "",
    config.publicKey ?? "",
    input.method,
    signature,
    timestamp,
    bodyBytes,
    config.apiBaseUrl ?? "https://discord.com",
    input.signal ?? new AbortController().signal,
  );
  scheduleBackground(background);

  let outcome;
  try {
    outcome = await response;
  } catch {
    return new Response("Interaction dispatch failed", { status: 500 });
  }

  return new Response(outcome.body, {
    status: outcome.status,
    headers: outcome.contentType
      ? { "content-type": outcome.contentType }
      : undefined,
  });
}

export async function handleInteraction(request, config, scheduleBackground) {
  return handleRawInteraction(
    {
      method: request.method,
      signature: request.headers.get("X-Signature-Ed25519") ?? "",
      timestamp: request.headers.get("X-Signature-Timestamp") ?? "",
      body: new Uint8Array(await request.arrayBuffer()),
      signal: request.signal,
    },
    config,
    scheduleBackground,
  );
}

// Track background promises on hosts without a platform waitUntil.
export function trackBackground(onError = console.error) {
  const pending = new Set();
  return {
    schedule(promise) {
      const tracked = promise.catch(onError).finally(() => {
        pending.delete(tracked);
      });
      pending.add(tracked);
    },
    async whenIdle() {
      await Promise.all([...pending]);
      // The MoonBit async runtime may still have one scheduler tick queued
      // with setTimeout(0) when the last background promise settles. Yield one
      // macrotask turn so that tick runs first; Deno's test sanitizer otherwise
      // reports it as a leaked timer.
      await new Promise((resolve) => setTimeout(resolve, 0));
    },
  };
}
