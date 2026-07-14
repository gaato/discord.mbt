// From this directory, run `moon build --target js .` first. Wrangler bundles
// the generated ESM artifact imported below when it deploys entry.js.
import {
  start_interaction,
  verify_signature,
} from "../../../_build/js/debug/build/examples/workers_echo/workers_echo.js";

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const signature = request.headers.get("X-Signature-Ed25519") ?? "";
    const timestamp = request.headers.get("X-Signature-Timestamp") ?? "";
    const body = await request.text();
    const verified = await verify_signature(
      env.DISCORD_PUBLIC_KEY ?? "",
      signature,
      timestamp,
      body,
    );
    if (!verified) {
      return new Response("Invalid request signature", { status: 401 });
    }

    try {
      JSON.parse(body);
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }

    const { response, background } = start_interaction(
      env.DISCORD_TOKEN ?? "",
      body,
    );
    ctx.waitUntil(background);

    let outcome;
    try {
      outcome = await response;
    } catch {
      return new Response("Interaction dispatch failed", { status: 500 });
    }

    switch (outcome.kind) {
      case "Reply":
        return new Response(outcome.body, {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      case "NoRoute":
        return new Response("No interaction route", { status: 404 });
      case "NoResponse":
        return new Response(null, { status: 202 });
      case "TimedOut":
        return new Response("Initial response timed out", { status: 504 });
      default:
        return new Response("Unknown interaction outcome", { status: 500 });
    }
  },
};
