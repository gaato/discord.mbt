// Lazy loading permits runtimes that restrict startup randomness. Register one
// aggregate background promise before loading so Fastly can retain it at entry.
let modulePromise;
function loadMoonBit() {
  modulePromise ??= import(
    "../../_build/js/release/build/local/discord_examples/interactions_js/interactions_js.js"
  );
  return modulePromise;
}

export function handleInteraction(request, config, scheduleBackground) {
  let finishBackground;
  const background = new Promise((resolve) => { finishBackground = resolve; });
  scheduleBackground(background);
  return loadMoonBit().then(({ handle_interaction }) => handle_interaction(
    config.token ?? "",
    config.applicationId ?? "",
    config.publicKey ?? "",
    config.apiBaseUrl ?? "https://discord.com",
    config.path ?? new URL(request.url).pathname,
    request,
    finishBackground,
  )).catch((error) => {
    finishBackground();
    throw error;
  });
}

// Envelope-based hosts still enter through the same bounded Fetch adapter.
export function handleRawInteraction(input, config, scheduleBackground) {
  const headers = new Headers();
  if (input.signature) headers.set("x-signature-ed25519", input.signature);
  if (input.timestamp) headers.set("x-signature-timestamp", input.timestamp);
  return handleInteraction(new Request("https://interaction.invalid/", {
    method: input.method,
    headers,
    body: input.method === "GET" || input.method === "HEAD" ? undefined : input.body,
    signal: input.signal,
  }), config, scheduleBackground);
}

export function trackBackground(onError = console.error) {
  const pending = new Set();
  return {
    schedule(promise) {
      const tracked = promise.catch(onError).finally(() => pending.delete(tracked));
      pending.add(tracked);
    },
    async whenIdle() { await Promise.all([...pending]); },
  };
}
