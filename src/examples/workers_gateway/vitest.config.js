import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      main: "./entry.js",
      miniflare: {
        compatibilityDate: "2026-07-14",
        durableObjects: { GATEWAY: "GatewayShard" },
        bindings: {
          DISCORD_TOKEN: "test-token",
          CONTROL_TOKEN: "test-control-token",
          DISCORD_GATEWAY_URL: "ws://127.0.0.1:9",
        },
      },
    }),
  ],
});
