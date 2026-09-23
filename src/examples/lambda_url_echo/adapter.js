import { handleRawInteraction } from "../interactions_js/handler.js";

// AWS Function URLs deliver payload-format 2.0 objects, not Web Requests.
export function createLambdaUrlHandler(config) {
  return async (event) => {
    const method = event.requestContext?.http?.method ?? "GET";
    const body = event.isBase64Encoded
      ? Buffer.from(event.body ?? "", "base64")
      : Buffer.from(event.body ?? "", "utf8");
    const headers = new Headers(event.headers ?? {});
    const pending = [];
    const response = await handleRawInteraction(
      {
        method,
        signature: headers.get("x-signature-ed25519") ?? "",
        timestamp: headers.get("x-signature-timestamp") ?? "",
        body,
      },
      config,
      (promise) => pending.push(promise),
    );

    // Function URLs have no waitUntil. Awaiting deferred work delays delivery
    // of the initial ACK, so this is not suitable for long-running handlers.
    await Promise.all(pending);
    return {
      statusCode: response.status,
      headers: Object.fromEntries(response.headers),
      body: Buffer.from(await response.arrayBuffer()).toString("base64"),
      isBase64Encoded: true,
    };
  };
}
