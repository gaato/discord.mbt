import { handleRawInteraction } from "../interactions_js/handler.js";

// Match the shared Fetch adapter's input ceiling before allocating decoded
// event bytes; Function URLs buffer outside the Web Request body stream.
const MAX_REQUEST_BYTES = 1024 * 1024;
const MAX_RESPONSE_BYTES = 4 * 1024 * 1024;

async function responseBytes(response) {
  if (!response.body) return Buffer.alloc(0);
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) return Buffer.concat(chunks, size);
      if (value.byteLength > MAX_RESPONSE_BYTES - size) {
        throw new RangeError("Lambda response exceeds 4 MiB");
      }
      size += value.byteLength;
      chunks.push(Buffer.from(value));
    }
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

// AWS Function URLs deliver payload-format 2.0 objects, not Web Requests.
export function createLambdaUrlHandler(config) {
  return async (event) => {
    const method = event.requestContext?.http?.method ?? "GET";
    const encoded = event.body ?? "";
    const padding = encoded.endsWith("==") ? 2 : encoded.endsWith("=") ? 1 : 0;
    const size = event.isBase64Encoded
      ? Math.floor(encoded.length / 4) * 3 - padding
      : Buffer.byteLength(encoded, "utf8");
    if (size > MAX_REQUEST_BYTES) return { statusCode: 413, body: "" };
    if (event.isBase64Encoded && (encoded.length % 4 !== 0 || /[^A-Za-z0-9+/]/.test(encoded.slice(0, encoded.length - padding)))) {
      return { statusCode: 400, body: "" };
    }
    const body = event.isBase64Encoded
      ? Buffer.from(encoded, "base64")
      : Buffer.from(encoded, "utf8");
    const headers = new Headers(event.headers ?? {});
    const pending = [];
    try {
      const response = await handleRawInteraction(
        {
          method,
          signature: headers.get("x-signature-ed25519") ?? "",
          timestamp: headers.get("x-signature-timestamp") ?? "",
          body,
        },
        config,
        (promise) => pending.push(Promise.resolve(promise).then(
          () => ({ ok: true }), error => ({ ok: false, error }),
        )),
      );

      // Function URLs have no waitUntil. Awaiting deferred work delays delivery
      // of the initial ACK, so this is not suitable for long-running handlers.
      return {
        statusCode: response.status,
        headers: Object.fromEntries([...response.headers].filter(([name]) => name !== "set-cookie")),
        cookies: response.headers.getSetCookie(),
        body: (await responseBytes(response)).toString("base64"),
        isBase64Encoded: true,
      };
    } finally {
      const outcomes = await Promise.all(pending);
      const failed = outcomes.find(outcome => !outcome.ok);
      if (failed) throw failed.error;
    }
  };
}
